package com.omninest.modules.photos.service;

import com.omninest.common.cache.ReadThroughCache;
import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.common.sync.SyncAction;
import com.omninest.common.sync.SyncScope;
import com.omninest.modules.file.dto.FileDownloadUrlDto;
import com.omninest.modules.file.service.FileDeletionService;
import com.omninest.modules.file.service.FilePurgeOrigin;
import com.omninest.modules.file.service.FileQueryService;
import com.omninest.modules.media.service.MediaSyncEventService;
import com.omninest.modules.photos.domain.PhotoAlbum;
import com.omninest.modules.photos.domain.PhotoAlbumItem;
import com.omninest.modules.photos.domain.PhotoFavorite;
import com.omninest.modules.photos.domain.PhotoItem;
import com.omninest.modules.photos.domain.PhotoTag;
import com.omninest.modules.photos.dto.GroupBy;
import com.omninest.modules.photos.dto.PhotoDtos.PhotoDashboardDto;
import com.omninest.modules.photos.dto.PhotoDtos.PhotoGroupDto;
import com.omninest.modules.photos.dto.PhotoDtos.PhotoItemDto;
import com.omninest.modules.photos.dto.PhotoDtos.PhotoListItemDto;
import com.omninest.modules.photos.dto.PhotoDtos.PhotoMonthGroup;
import com.omninest.modules.photos.dto.PhotoDtos.PhotoTimelineDto;
import com.omninest.modules.photos.dto.PhotoDtos.PhotoTimelineMonthDto;
import com.omninest.modules.photos.dto.PhotoDtos.PhotoYearGroup;
import com.omninest.modules.photos.repository.PhotoAlbumItemRepository;
import com.omninest.modules.photos.repository.PhotoAlbumRepository;
import com.omninest.modules.photos.repository.PhotoFavoriteRepository;
import com.omninest.modules.photos.repository.PhotoGroupPreviewProjection;
import com.omninest.modules.photos.repository.PhotoItemRepository;
import com.omninest.modules.photos.repository.PhotoListItemProjection;
import com.omninest.modules.photos.repository.PhotoTagRepository;
import com.omninest.modules.photos.repository.PhotoTimelinePreviewProjection;
import com.omninest.modules.photos.search.PhotoSearchIndexService;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 照片库服务，提供浏览、搜索、收藏和删除功能。
 *
 * @author OmniNest
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PhotoLibraryService {

    private static final int DEFAULT_PAGE_SIZE = 50;
    private static final int MAX_PAGE_SIZE = 100;
    private static final Map<String, String> SORT_FIELDS = Map.of(
            "createdAt", "createdAt",
            "dateTaken", "dateTaken",
            "title", "title",
            "fileSize", "fileSize"
    );

    private final PhotoItemRepository photoItemRepository;
    private final PhotoFavoriteRepository favoriteRepository;
    private final PhotoAlbumRepository albumRepository;
    private final PhotoAlbumItemRepository albumItemRepository;
    private final PhotoTagRepository photoTagRepository;
    private final PhotoSearchIndexService photoSearchIndexService;
    private final FileDeletionService fileDeletionService;
    private final FileQueryService fileQueryService;
    private final ReadThroughCache readThroughCache;
    private final MediaSyncEventService syncEventService;
    private final PhotoContentAnalysisService contentAnalysisService;

    /**
     * 照片仪表盘，返回统计数据和近期/收藏照片（缓存 3 分钟）。
     */
    @Transactional(readOnly = true)
    public PhotoDashboardDto dashboard(UUID ownerUserId) {
        String cacheKey = "omninest:dashboard:photo:" + ownerUserId;
        return readThroughCache.getOrLoad(cacheKey, Duration.ofMinutes(3),
                () -> loadDashboard(ownerUserId),
                PhotoDashboardDto.class);
    }

    /**
     * 从数据库加载照片仪表盘数据。
     */
    private PhotoDashboardDto loadDashboard(UUID ownerUserId) {
        long totalPhotos = photoItemRepository.countByOwnerUserId(ownerUserId);
        long totalAlbums = albumRepository.countByOwnerUserId(ownerUserId);

        // 一次查询获取所有收藏数据，避免三次重复查询
        List<PhotoFavorite> allFavorites = favoriteRepository.findByOwnerUserIdOrderByCreatedAtDesc(ownerUserId);
        Set<UUID> favoriteIds = allFavorites.stream().map(PhotoFavorite::getPhotoId).collect(Collectors.toSet());
        List<UUID> favoritePhotoIds = allFavorites.stream().map(PhotoFavorite::getPhotoId).toList();

        List<PhotoItem> recent = photoItemRepository.findTopNByOwnerUserIdOrderByCreatedAtDesc(ownerUserId, 12);

        // 加载收藏照片（最多12张）
        List<PhotoItem> favorites = List.of();
        if (!favoritePhotoIds.isEmpty()) {
            List<UUID> limitedIds = favoritePhotoIds.subList(0, Math.min(12, favoritePhotoIds.size()));
            Map<UUID, PhotoItem> items = photoItemRepository
                    .findActiveByOwnerUserIdAndIdIn(ownerUserId, limitedIds).stream()
                    .collect(Collectors.toMap(PhotoItem::getId, p -> p));
            favorites = limitedIds.stream().map(items::get).filter(Objects::nonNull).toList();
        }

        return new PhotoDashboardDto(
                totalPhotos,
                totalAlbums,
                favoriteIds.size(),
                recent.stream().map(p -> toDto(p, favoriteIds.contains(p.getId()))).toList(),
                favorites.stream().map(p -> toDto(p, true)).toList()
        );
    }

    /**
     * 查询用户所有照片列表
     */
    @Transactional(readOnly = true)
    public List<PhotoItemDto> listPhotos(UUID ownerUserId) {
        Set<UUID> favoriteIds = favoriteIds(ownerUserId);
        return photoItemRepository.findByOwnerUserIdOrderByCreatedAtDesc(ownerUserId)
                .stream()
                .map(p -> toDto(p, favoriteIds.contains(p.getId())))
                .toList();
    }

    /**
     * 分页查询用户照片列表。
     *
     * @param ownerUserId 用户标识
     * @param page 页码，从零开始
     * @param size 每页条数
     * @param sort 排序表达式，格式为字段和方向
     * @param query 标题或描述筛选词
     * @return 照片轻量列表分页
     */
    @Transactional(readOnly = true)
    public Page<PhotoListItemDto> listPhotosPage(
            UUID ownerUserId,
            int page,
            int size,
            String sort,
            String query
    ) {
        Pageable pageable = photoPageable(page, size, sort);
        String normalizedQuery = normalizeQuery(query);
        Page<PhotoListItemProjection> result = normalizedQuery == null
                ? photoItemRepository.findListPage(ownerUserId, pageable)
                : photoItemRepository.searchListPage(ownerUserId, normalizedQuery, pageable);
        return mapListPage(ownerUserId, result, false);
    }

    /**
     * 分页查询用户收藏照片列表。
     *
     * @param ownerUserId 用户标识
     * @param page 页码，从零开始
     * @param size 每页条数
     * @param sort 排序表达式，格式为字段和方向
     * @param query 标题或描述筛选词
     * @return 收藏照片轻量列表分页
     */
    @Transactional(readOnly = true)
    public Page<PhotoListItemDto> listFavoritesPage(
            UUID ownerUserId,
            int page,
            int size,
            String sort,
            String query
    ) {
        Pageable pageable = photoPageable(page, size, sort);
        String normalizedQuery = normalizeQuery(query);
        Page<PhotoListItemProjection> result = normalizedQuery == null
                ? photoItemRepository.findFavoriteListPage(ownerUserId, pageable)
                : photoItemRepository.searchFavoriteListPage(ownerUserId, normalizedQuery, pageable);
        return mapListPage(ownerUserId, result, true);
    }

    /**
     * 按关键词搜索用户照片，优先使用 Lucene 全文索引，无结果时回退到 SQL LIKE。
     */
    @Transactional(readOnly = true)
    public List<PhotoItemDto> searchPhotos(UUID ownerUserId, String query) {
        Set<UUID> favoriteIds = favoriteIds(ownerUserId);
        List<UUID> luceneIds = photoSearchIndexService.search(ownerUserId, query, 200);
        if (!luceneIds.isEmpty()) {
            Map<UUID, PhotoItem> itemMap = photoItemRepository
                    .findActiveByOwnerUserIdAndIdIn(ownerUserId, luceneIds).stream()
                    .collect(Collectors.toMap(PhotoItem::getId, p -> p));
            return luceneIds.stream()
                    .map(itemMap::get)
                    .filter(Objects::nonNull)
                    .map(p -> toDto(p, favoriteIds.contains(p.getId())))
                    .toList();
        }
        return photoItemRepository.searchByOwnerUserIdAndKeyword(ownerUserId, query)
                .stream()
                .map(p -> toDto(p, favoriteIds.contains(p.getId())))
                .toList();
    }

    /**
     * 查询单张照片详情
     */
    @Transactional(readOnly = true)
    public PhotoItemDto photo(UUID ownerUserId, UUID photoId) {
        PhotoItem item = photoItemRepository.findByOwnerUserIdAndId(ownerUserId, photoId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "图片不存在"));
        boolean favorite = favoriteRepository.existsByOwnerUserIdAndPhotoId(ownerUserId, photoId);
        return toDto(item, favorite, true);
    }

    /**
     * 永久删除指定照片及其源文件。
     *
     * @param ownerUserId 当前用户 ID
     * @param photoId 照片 ID
     */
    @Transactional(rollbackFor = Exception.class)
    public UUID deletePhoto(UUID ownerUserId, UUID photoId) {
        return deletePhoto(ownerUserId, photoId, false);
    }

    /** 按指定顺序批量查询用户拥有的活动照片，供公开相册分页使用。 */
    @Transactional(readOnly = true)
    public List<PhotoItemDto> listPhotosByIds(UUID ownerUserId, List<UUID> photoIds) {
        if (photoIds == null || photoIds.isEmpty()) {
            return List.of();
        }
        Set<UUID> favoriteIds = Set.copyOf(
                favoriteRepository.findPhotoIdsByOwnerUserIdAndPhotoIdIn(ownerUserId, photoIds));
        Map<UUID, List<String>> tagsByPhoto = photoTagRepository
                .findByOwnerUserIdAndPhotoIdIn(ownerUserId, photoIds)
                .stream()
                .collect(Collectors.groupingBy(
                        PhotoTag::getPhotoId,
                        Collectors.mapping(PhotoTag::getTag, Collectors.toList())
                ));
        Map<UUID, PhotoItem> itemsById = photoItemRepository
                .findActiveByOwnerUserIdAndIdIn(ownerUserId, photoIds)
                .stream()
                .collect(Collectors.toMap(PhotoItem::getId, item -> item));
        return photoIds.stream()
                .map(itemsById::get)
                .filter(Objects::nonNull)
                .map(item -> PhotoItemDto.fromEntity(
                        item,
                        resolveCoverUrl(ownerUserId, item.getId(), item.getCoverFileId()),
                        favoriteIds.contains(item.getId()),
                        tagsByPhoto.getOrDefault(item.getId(), List.of())
                ))
                .toList();
    }

    /**
     * 创建照片永久删除任务。
     *
     * @param ownerUserId 当前用户 ID
     * @param photoId 照片 ID
     * @param cascade 是否允许级联清理其他业务引用
     * @return 任务 ID
     */
    @Transactional(rollbackFor = Exception.class)
    public UUID deletePhoto(UUID ownerUserId, UUID photoId, boolean cascade) {
        PhotoItem item = photoItemRepository.findByOwnerUserIdAndId(ownerUserId, photoId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "图片不存在"));
        UUID taskId = fileDeletionService.deletePermanently(
                ownerUserId,
                item.getFileNodeId(),
                cascade,
                new FilePurgeOrigin("PHOTOS", photoId),
                null
        );
        log.info("照片永久删除任务已创建: taskId={}, photoId={}, userId={}", taskId, photoId, ownerUserId);
        return taskId;
    }

    /**
     * 为多张照片创建一个永久删除任务。
     *
     * @param ownerUserId 当前用户 ID
     * @param photoIds 照片 ID 列表
     * @param cascade 是否允许级联清理其他业务引用
     * @return 任务 ID
     */
    @Transactional(rollbackFor = Exception.class)
    public UUID deletePhotos(UUID ownerUserId, List<UUID> photoIds, boolean cascade) {
        List<UUID> distinctPhotoIds = photoIds.stream().distinct().sorted().toList();
        List<PhotoItem> items = photoItemRepository.findActiveByOwnerUserIdAndIdIn(
                ownerUserId,
                distinctPhotoIds
        );
        if (items.size() != distinctPhotoIds.size()) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "批量删除包含不存在的图片");
        }
        UUID taskId = fileDeletionService.deletePermanentlyBatch(
                ownerUserId,
                items.stream().map(PhotoItem::getFileNodeId).toList(),
                cascade,
                items.stream().map(item -> new FilePurgeOrigin("PHOTOS", item.getId())).toList()
        );
        log.info("照片批量永久删除任务已创建: taskId={}, photoCount={}, userId={}",
                taskId, items.size(), ownerUserId);
        return taskId;
    }

    /**
     * 添加照片收藏
     */
    @Transactional(rollbackFor = Exception.class)
    public void addFavorite(UUID ownerUserId, UUID photoId) {
        photoItemRepository.findByOwnerUserIdAndId(ownerUserId, photoId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "图片不存在"));
        if (favoriteRepository.existsByOwnerUserIdAndPhotoId(ownerUserId, photoId)) {
            return;
        }
        PhotoFavorite fav = new PhotoFavorite();
        fav.setOwnerUserId(ownerUserId);
        fav.setPhotoId(photoId);
        favoriteRepository.save(fav);
        invalidateDashboardCache(ownerUserId);
        recordPhotoEvent(ownerUserId, photoId, SyncAction.UPDATED, null, Map.of("favorite", true));
    }

    /**
     * 移除照片收藏
     */
    @Transactional(rollbackFor = Exception.class)
    public void removeFavorite(UUID ownerUserId, UUID photoId) {
        favoriteRepository.deleteByOwnerUserIdAndPhotoId(ownerUserId, photoId);
        invalidateDashboardCache(ownerUserId);
        recordPhotoEvent(ownerUserId, photoId, SyncAction.UPDATED, null, Map.of("favorite", false));
    }

    /**
     * 查询用户收藏照片列表
     */
    @Transactional(readOnly = true)
    public List<PhotoItemDto> listFavorites(UUID ownerUserId) {
        List<PhotoItem> photos = findFavoritePhotos(ownerUserId, 0);
        return photos.stream().map(p -> toDto(p, true)).toList();
    }

    /**
     * 批量加载收藏照片，避免N+1查询
     */
    private List<PhotoItem> findFavoritePhotos(UUID ownerUserId, int limit) {
        List<UUID> photoIds = favoriteRepository.findByOwnerUserIdOrderByCreatedAtDesc(ownerUserId)
                .stream()
                .map(PhotoFavorite::getPhotoId)
                .toList();
        if (photoIds.isEmpty()) {
            return List.of();
        }
        List<UUID> limited = limit > 0 ? photoIds.subList(0, Math.min(limit, photoIds.size())) : photoIds;
        Map<UUID, PhotoItem> items = photoItemRepository
                .findActiveByOwnerUserIdAndIdIn(ownerUserId, limited).stream()
                .collect(Collectors.toMap(PhotoItem::getId, p -> p));
        return limited.stream().map(items::get).filter(Objects::nonNull).toList();
    }

    /**
     * 获取用户收藏的照片ID集合
     */
    private Set<UUID> favoriteIds(UUID ownerUserId) {
        return favoriteRepository.findByOwnerUserIdOrderByCreatedAtDesc(ownerUserId)
                .stream().map(PhotoFavorite::getPhotoId).collect(Collectors.toSet());
    }

    /**
     * 根据ID查询照片实体，不存在返回null
     */
    PhotoItem findPhotoById(UUID photoId) {
        return photoItemRepository.findById(photoId).orElse(null);
    }

    /**
     * 解析封面文件的预签名下载URL
     */
    String resolveCoverUrl(UUID ownerUserId, UUID coverFileId) {
        FileDownloadUrlDto url = fileQueryService.createDownloadUrl(ownerUserId, coverFileId);
        return url.downloadUrl();
    }

    /**
     * 时间线视图，按年→月分组，每月返回照片数和前4张预览。
     * 旧版接口最多返回最近一百个月。
     *
     * @param ownerUserId 用户标识
     * @return 有界时间线
     */
    @Transactional(readOnly = true)
    public PhotoTimelineDto timeline(UUID ownerUserId) {
        return timeline(ownerUserId, MAX_PAGE_SIZE);
    }

    /**
     * 返回受月份数量上限约束的兼容版照片时间线。
     *
     * @param ownerUserId 用户标识
     * @param maxMonths 最多返回的月份数量
     * @return 有界时间线
     */
    @Transactional(readOnly = true)
    public PhotoTimelineDto timeline(UUID ownerUserId, int maxMonths) {
        Page<PhotoTimelineMonthDto> page = timelinePage(ownerUserId, 0, maxMonths);
        Map<Integer, List<PhotoMonthGroup>> monthsByYear = new LinkedHashMap<>();
        for (PhotoTimelineMonthDto month : page.getContent()) {
            List<PhotoMonthGroup> months = monthsByYear.computeIfAbsent(month.year(), ignored -> new ArrayList<>());
            months.add(new PhotoMonthGroup(
                    month.month(),
                    month.photoCount(),
                    month.previewPhotos().stream().map(this::toLegacyPhotoItem).toList()
            ));
        }
        List<PhotoYearGroup> years = monthsByYear.entrySet().stream()
                .map(entry -> new PhotoYearGroup(entry.getKey(), List.copyOf(entry.getValue())))
                .toList();
        return new PhotoTimelineDto(years);
    }

    /**
     * 按月份分页查询照片时间线，每个月只返回最多四张轻量预览。
     *
     * @param ownerUserId 用户标识
     * @param page 页码，从零开始
     * @param size 每页月份数量
     * @return 时间线月份分页
     */
    @Transactional(readOnly = true)
    public Page<PhotoTimelineMonthDto> timelinePage(UUID ownerUserId, int page, int size) {
        int safePage = Math.max(0, page);
        int safeSize = boundedPageSize(size);
        String zoneId = ZoneId.systemDefault().getId();
        List<PhotoTimelinePreviewProjection> rows = photoItemRepository.findTimelinePreviewPage(
                ownerUserId,
                zoneId,
                Math.multiplyFull(safePage, safeSize),
                safeSize
        );
        long totalMonths = photoItemRepository.countTimelineMonths(ownerUserId, zoneId);
        List<PhotoTimelineMonthDto> months = mapTimelineMonths(ownerUserId, rows);
        return new PageImpl<>(months, PageRequest.of(safePage, safeSize), totalMonths);
    }

    /**
     * 添加照片标签。
     */
    @Transactional(rollbackFor = Exception.class)
    public void addTag(UUID ownerUserId, UUID photoId, String tag) {
        photoItemRepository.findByOwnerUserIdAndId(ownerUserId, photoId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "图片不存在"));
        if (photoTagRepository.existsByOwnerUserIdAndPhotoIdAndTag(ownerUserId, photoId, tag)) {
            return;
        }
        PhotoTag photoTag = new PhotoTag();
        photoTag.setOwnerUserId(ownerUserId);
        photoTag.setPhotoId(photoId);
        photoTag.setTag(tag);
        photoTagRepository.save(photoTag);
        recordPhotoEvent(ownerUserId, photoId, SyncAction.UPDATED, null, Map.of("tagsChanged", true));
    }

    /**
     * 移除照片标签。
     */
    @Transactional(rollbackFor = Exception.class)
    public void removeTag(UUID ownerUserId, UUID photoId, String tag) {
        photoTagRepository.deleteByOwnerUserIdAndPhotoIdAndTag(ownerUserId, photoId, tag);
        recordPhotoEvent(ownerUserId, photoId, SyncAction.UPDATED, null, Map.of("tagsChanged", true));
    }

    /**
     * 按标签查询照片列表。
     */
    @Transactional(readOnly = true)
    public List<PhotoItemDto> listByTag(UUID ownerUserId, String tag) {
        Set<UUID> favoriteIds = favoriteIds(ownerUserId);
        List<UUID> photoIds = photoTagRepository.findByOwnerUserIdAndTagOrderByCreatedAtDesc(ownerUserId, tag)
                .stream()
                .map(PhotoTag::getPhotoId)
                .toList();
        if (photoIds.isEmpty()) {
            return List.of();
        }
        Map<UUID, PhotoItem> itemMap = photoItemRepository
                .findActiveByOwnerUserIdAndIdIn(ownerUserId, photoIds).stream()
                .collect(Collectors.toMap(PhotoItem::getId, p -> p));
        return photoIds.stream()
                .map(itemMap::get)
                .filter(Objects::nonNull)
                .map(p -> toDto(p, favoriteIds.contains(p.getId())))
                .toList();
    }

    /**
     * 查询用户所有标签。
     */
    @Transactional(readOnly = true)
    public List<String> listTags(UUID ownerUserId) {
        return photoTagRepository.findDistinctTagsByOwnerUserId(ownerUserId);
    }

    /**
     * 按指定维度对照片进行分组。
     */
    @Transactional(readOnly = true)
    public List<PhotoGroupDto> groupBy(UUID ownerUserId, GroupBy groupBy) {
        return groupBy(ownerUserId, groupBy, MAX_PAGE_SIZE);
    }

    /**
     * 返回受分组数量上限约束的兼容版照片分组。
     *
     * @param ownerUserId 用户标识
     * @param groupBy 分组维度
     * @param maxGroups 最多返回的分组数量
     * @return 有界照片分组
     */
    @Transactional(readOnly = true)
    public List<PhotoGroupDto> groupBy(UUID ownerUserId, GroupBy groupBy, int maxGroups) {
        return groupByPage(ownerUserId, groupBy, 0, maxGroups).getContent();
    }

    /**
     * 按指定维度分页聚合照片，每组只返回最多四张轻量预览。
     *
     * @param ownerUserId 用户标识
     * @param groupBy 分组维度
     * @param page 页码，从零开始
     * @param size 每页分组数量
     * @return 照片分组分页
     */
    @Transactional(readOnly = true)
    public Page<PhotoGroupDto> groupByPage(UUID ownerUserId, GroupBy groupBy, int page, int size) {
        int safePage = Math.max(0, page);
        int safeSize = boundedPageSize(size);
        String zoneId = ZoneId.systemDefault().getId();
        List<PhotoGroupPreviewProjection> rows = photoItemRepository.findGroupPreviewPage(
                ownerUserId,
                groupBy.name(),
                zoneId,
                Math.multiplyFull(safePage, safeSize),
                safeSize
        );
        long totalGroups = photoItemRepository.countPhotoGroups(ownerUserId, groupBy.name(), zoneId);
        List<PhotoGroupDto> groups = mapPhotoGroups(ownerUserId, rows);
        return new PageImpl<>(groups, PageRequest.of(safePage, safeSize), totalGroups);
    }

    /**
     * 将照片实体转换为DTO，包含预签名缩略图URL和标签
     */
    PhotoItemDto toDto(PhotoItem photo, boolean favorite) {
        return toDto(photo, favorite, false);
    }

    private PhotoItemDto toDto(PhotoItem photo, boolean favorite, boolean includeContentAnalysis) {
        String coverUrl = resolveCoverUrl(photo.getOwnerUserId(), photo.getId(), photo.getCoverFileId());
        List<String> tags = photoTagRepository.findByOwnerUserIdAndPhotoId(photo.getOwnerUserId(), photo.getId())
                .stream()
                .map(PhotoTag::getTag)
                .toList();
        return PhotoItemDto.fromEntity(
                photo,
                coverUrl,
                favorite,
                tags,
                includeContentAnalysis
                        ? resolveSourceUrl(photo.getOwnerUserId(), photo.getFileNodeId())
                        : null,
                includeContentAnalysis
                        ? contentAnalysisService.current(photo.getOwnerUserId(), photo.getId())
                        : null
        );
    }

    private Page<PhotoListItemDto> mapListPage(
            UUID ownerUserId,
            Page<PhotoListItemProjection> page,
            boolean favoritePage
    ) {
        List<PhotoListItemDto> items = mapListItems(ownerUserId, page.getContent(), favoritePage);
        return new PageImpl<>(items, page.getPageable(), page.getTotalElements());
    }

    private List<PhotoListItemDto> mapListItems(
            UUID ownerUserId,
            List<? extends PhotoListItemProjection> projections,
            boolean favoritePage
    ) {
        List<UUID> photoIds = projections.stream()
                .map(PhotoListItemProjection::getId)
                .toList();
        Set<UUID> favoriteIds = favoritePage || photoIds.isEmpty()
                ? Set.copyOf(photoIds)
                : Set.copyOf(favoriteRepository.findPhotoIdsByOwnerUserIdAndPhotoIdIn(ownerUserId, photoIds));
        Map<UUID, List<String>> tagsByPhoto = photoIds.isEmpty()
                ? Map.of()
                : photoTagRepository.findByOwnerUserIdAndPhotoIdIn(ownerUserId, photoIds).stream()
                        .collect(Collectors.groupingBy(
                                PhotoTag::getPhotoId,
                                Collectors.mapping(PhotoTag::getTag, Collectors.toList())
                        ));
        return projections.stream().map(item -> new PhotoListItemDto(
                item.getId(),
                item.getFileNodeId(),
                item.getTitle(),
                item.getDescription(),
                item.getWidth(),
                item.getHeight(),
                item.getOrientation(),
                item.getDateTaken(),
                item.getGpsLatitude() == null ? null : item.getGpsLatitude().doubleValue(),
                item.getGpsLongitude() == null ? null : item.getGpsLongitude().doubleValue(),
                item.getFormat(),
                item.getFileSize(),
                resolveCoverUrl(ownerUserId, item.getId(), item.getCoverFileId()),
                item.getMetadataStatus(),
                favoriteIds.contains(item.getId()),
                item.getCreatedAt(),
                tagsByPhoto.getOrDefault(item.getId(), List.of())
        )).toList();
    }

    private List<PhotoTimelineMonthDto> mapTimelineMonths(
            UUID ownerUserId,
            List<PhotoTimelinePreviewProjection> rows
    ) {
        List<PhotoListItemDto> previews = mapListItems(ownerUserId, rows, false);
        Map<UUID, PhotoListItemDto> previewById = previews.stream()
                .collect(Collectors.toMap(PhotoListItemDto::id, item -> item));
        Map<String, List<PhotoTimelinePreviewProjection>> groupedRows = new LinkedHashMap<>();
        for (PhotoTimelinePreviewProjection row : rows) {
            String groupKey = row.getYear() + "-" + row.getMonth();
            groupedRows.computeIfAbsent(groupKey, ignored -> new ArrayList<>()).add(row);
        }
        return groupedRows.values().stream()
                .map(groupRows -> {
                    PhotoTimelinePreviewProjection first = groupRows.getFirst();
                    List<PhotoListItemDto> groupPreviews = groupRows.stream()
                            .map(row -> previewById.get(row.getId()))
                            .filter(Objects::nonNull)
                            .toList();
                    int photoCount = (int) Math.min(Integer.MAX_VALUE, first.getPhotoCount());
                    return new PhotoTimelineMonthDto(
                            first.getYear(),
                            first.getMonth(),
                            photoCount,
                            groupPreviews
                    );
                })
                .toList();
    }

    private List<PhotoGroupDto> mapPhotoGroups(
            UUID ownerUserId,
            List<PhotoGroupPreviewProjection> rows
    ) {
        List<PhotoListItemDto> previews = mapListItems(ownerUserId, rows, false);
        Map<UUID, PhotoListItemDto> previewById = previews.stream()
                .collect(Collectors.toMap(
                        PhotoListItemDto::id,
                        item -> item,
                        (first, ignored) -> first,
                        LinkedHashMap::new
                ));
        Map<String, List<PhotoGroupPreviewProjection>> groupedRows = new LinkedHashMap<>();
        for (PhotoGroupPreviewProjection row : rows) {
            groupedRows.computeIfAbsent(row.getGroupKey(), ignored -> new ArrayList<>()).add(row);
        }
        return groupedRows.values().stream()
                .map(groupRows -> {
                    PhotoGroupPreviewProjection first = groupRows.getFirst();
                    List<PhotoItemDto> groupPreviews = groupRows.stream()
                            .map(row -> previewById.get(row.getId()))
                            .filter(Objects::nonNull)
                            .map(this::toLegacyPhotoItem)
                            .toList();
                    int photoCount = (int) Math.min(Integer.MAX_VALUE, first.getPhotoCount());
                    return new PhotoGroupDto(first.getGroupKey(), photoCount, groupPreviews);
                })
                .toList();
    }

    private Pageable photoPageable(int page, int size, String sortExpression) {
        int safePage = Math.max(0, page);
        int safeSize = boundedPageSize(size);
        String[] sortParts = sortExpression == null ? new String[0] : sortExpression.split(",", 2);
        String requestedField = sortParts.length == 0 || sortParts[0].isBlank()
                ? "createdAt"
                : sortParts[0].trim();
        String sortField = SORT_FIELDS.get(requestedField);
        if (sortField == null) {
            throw new BusinessException(ErrorCode.PARAM_ERROR, "照片排序字段不合法");
        }
        Sort.Direction direction = sortParts.length > 1
                ? parseSortDirection(sortParts[1])
                : Sort.Direction.DESC;
        Sort sort = Sort.by(direction, sortField).and(Sort.by(Sort.Direction.ASC, "id"));
        return PageRequest.of(safePage, safeSize, sort);
    }

    private int boundedPageSize(int size) {
        return Math.min(MAX_PAGE_SIZE, Math.max(1, size == 0 ? DEFAULT_PAGE_SIZE : size));
    }

    private Sort.Direction parseSortDirection(String direction) {
        if ("asc".equalsIgnoreCase(direction.trim())) {
            return Sort.Direction.ASC;
        }
        if ("desc".equalsIgnoreCase(direction.trim())) {
            return Sort.Direction.DESC;
        }
        throw new BusinessException(ErrorCode.PARAM_ERROR, "照片排序方向不合法");
    }

    private String normalizeQuery(String query) {
        if (query == null || query.isBlank()) {
            return null;
        }
        return query.trim();
    }

    private String resolveCoverUrl(UUID ownerUserId, UUID photoId, UUID coverFileId) {
        if (coverFileId == null) {
            return null;
        }
        try {
            FileDownloadUrlDto url = fileQueryService.createDownloadUrl(ownerUserId, coverFileId);
            return url.downloadUrl();
        } catch (Exception ex) {
            log.warn("解析封面 URL 失败: photoId={}, coverFileId={}", photoId, coverFileId, ex);
            return null;
        }
    }

    private void invalidateDashboardCache(UUID ownerUserId) {
        readThroughCache.invalidate("omninest:dashboard:photo:" + ownerUserId);
    }

    private String resolveSourceUrl(UUID ownerUserId, UUID fileNodeId) {
        try {
            return fileQueryService.createDownloadUrl(ownerUserId, fileNodeId).downloadUrl();
        } catch (Exception ex) {
            log.warn("解析照片原图 URL 失败: fileNodeId={}", fileNodeId, ex);
            return null;
        }
    }

    private PhotoItemDto toLegacyPhotoItem(PhotoListItemDto item) {
        return new PhotoItemDto(
                item.id(),
                item.fileNodeId(),
                item.title(),
                item.description(),
                item.width(),
                item.height(),
                item.orientation(),
                item.dateTaken(),
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                item.gpsLatitude(),
                item.gpsLongitude(),
                item.format(),
                item.fileSize(),
                item.coverUrl(),
                null,
                item.metadataStatus(),
                item.favorite(),
                item.createdAt(),
                Map.of(),
                item.tags(),
                Map.of(),
                null
        );
    }

    private void recordPhotoEvent(
            UUID ownerUserId,
            UUID photoId,
            SyncAction action,
            Long version,
            Map<String, Object> hints
    ) {
        syncEventService.record(
                ownerUserId,
                SyncScope.PHOTOS,
                "PHOTO_ITEM",
                photoId.toString(),
                action,
                version,
                hints
        );
    }
}
