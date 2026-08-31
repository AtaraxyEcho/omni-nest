package com.omninest.modules.video.service;

import com.omninest.modules.file.service.FileQueryService;
import com.omninest.modules.video.dto.MovieDtos.CastMemberDto;
import com.omninest.modules.video.dto.MovieDtos.CrewMemberDto;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 影视目录条目映射工具：演职员、下载地址与类型名的单点实现。
 *
 * <p>供 {@link MovieLibraryService} 与 {@link VideoItemDtoConverter} 共用，
 * 保证头像解析（MinIO 优先、TMDB 降级）等逻辑只维护一份。</p>
 *
 * @author OmniNest
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class VideoCatalogMappers {
    private final FileQueryService fileQueryService;

    /**
     * 解析文件下载地址，失败时返回 null（调用方降级到外部 URL）。
     */
    public String resolveFileUrl(UUID ownerUserId, UUID fileId) {
        try {
            return fileQueryService.createDownloadUrl(ownerUserId, fileId).downloadUrl();
        } catch (RuntimeException ex) {
            log.debug("MinIO 资源 URL 解析失败，降级到外部 URL: fileId={}, message={}", fileId, ex.getMessage());
            return null;
        }
    }

    /**
     * 解析演员头像 URL：优先使用 MinIO（profileFileId），降级到 TMDB（profilePath）。
     */
    public String resolveProfileUrl(UUID ownerUserId, Map<String, Object> memberMap) {
        Object fileIdObj = memberMap.get("profileFileId");
        if (fileIdObj instanceof String fileIdStr && !fileIdStr.isBlank()) {
            try {
                UUID fileId = UUID.fromString(fileIdStr);
                String url = resolveFileUrl(ownerUserId, fileId);
                if (url != null) return url;
            } catch (IllegalArgumentException ignored) {
                // profileFileId 格式异常，降级到 profilePath
            }
        }
        return (String) memberMap.get("profilePath");
    }

    @SuppressWarnings("unchecked")
    public List<CastMemberDto> toCastDtos(UUID ownerUserId, List<Map<String, Object>> castMembers) {
        if (castMembers == null || castMembers.isEmpty()) {
            return List.of();
        }
        return castMembers.stream()
                .map(m -> new CastMemberDto(
                        (String) m.get("name"),
                        (String) m.get("character"),
                        resolveProfileUrl(ownerUserId, m),
                        m.get("order") instanceof Number n ? n.intValue() : null
                ))
                .toList();
    }

    @SuppressWarnings("unchecked")
    public List<CrewMemberDto> toCrewDtos(UUID ownerUserId, List<Map<String, Object>> crewMembers) {
        if (crewMembers == null || crewMembers.isEmpty()) {
            return List.of();
        }
        return crewMembers.stream()
                .map(m -> new CrewMemberDto(
                        (String) m.get("name"),
                        (String) m.get("job"),
                        (String) m.get("department"),
                        resolveProfileUrl(ownerUserId, m)
                ))
                .toList();
    }

    /**
     * 从元数据中提取类型名列表。
     */
    @SuppressWarnings("unchecked")
    public List<String> extractGenreNames(List<Map<String, Object>> genres) {
        if (genres == null || genres.isEmpty()) {
            return List.of();
        }
        return genres.stream()
                .map(g -> (String) g.get("name"))
                .filter(name -> name != null && !name.isBlank())
                .toList();
    }
}
