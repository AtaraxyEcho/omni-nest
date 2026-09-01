package com.omninest.modules.photos.service;

import com.omninest.modules.photos.domain.PhotoItem;
import com.omninest.modules.photos.domain.PhotoTag;
import com.omninest.modules.photos.repository.PhotoItemRepository;
import com.omninest.modules.photos.repository.PhotoTagRepository;
import com.omninest.modules.photos.search.PhotoSearchIndexService;
import com.omninest.modules.file.service.FileLifecycleGuard;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * 照片搜索索引任务服务。
 *
 * @author OmniNest
 */
@Service
@RequiredArgsConstructor
public class PhotoIndexTaskService {
    private final PhotoItemRepository photoItemRepository;
    private final PhotoTagRepository photoTagRepository;
    private final PhotoSearchIndexService photoSearchIndexService;
    private final FileLifecycleGuard fileLifecycleGuard;

    /**
     * 为当前用户的指定照片写入搜索索引。
     *
     * @param ownerUserId 所有者用户 ID
     * @param photoId 照片 ID
     * @return 照片存在并完成索引时返回 true
     */
    public boolean index(UUID ownerUserId, UUID photoId) {
        PhotoItem photo = photoItemRepository.findByOwnerUserIdAndId(ownerUserId, photoId).orElse(null);
        if (photo == null) {
            return false;
        }
        if (!fileLifecycleGuard.isOwnedProcessable(ownerUserId, photo.getFileNodeId())) {
            return false;
        }
        List<String> tags = photoTagRepository.findByOwnerUserIdAndPhotoId(ownerUserId, photoId)
                .stream()
                .map(PhotoTag::getTag)
                .toList();
        photoSearchIndexService.indexPhoto(
                photo.getId(),
                photo.getOwnerUserId(),
                photo.getTitle(),
                photo.getDescription(),
                tags
        );
        return true;
    }
}
