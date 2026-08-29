package com.omninest.modules.video.repository;

import com.omninest.modules.video.domain.VideoLibrarySource;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 影视库来源仓储。
 *
 * @author OmniNest
 */
public interface VideoLibrarySourceRepository extends JpaRepository<VideoLibrarySource, UUID> {

    /**
     * 查询用户的全部影视库来源。
     *
     * @param ownerUserId 所有者用户 ID
     * @return 来源列表
     */
    List<VideoLibrarySource> findByOwnerUserIdOrderByNameAsc(UUID ownerUserId);

    List<VideoLibrarySource> findAllByOrderByNameAsc();

    List<VideoLibrarySource> findByEnabledTrueOrderByNameAsc();

    List<VideoLibrarySource> findByStorageLocationId(UUID storageLocationId);

    /**
     * 查询用户拥有的影视库来源。
     *
     * @param id 来源 ID
     * @param ownerUserId 所有者用户 ID
     * @return 来源
     */
    Optional<VideoLibrarySource> findByIdAndOwnerUserId(UUID id, UUID ownerUserId);

    /**
     * 判断同一存储位置子目录是否已登记。
     *
     * @param ownerUserId 所有者用户 ID
     * @param storageLocationId 存储位置 ID
     * @param relativeRoot 相对根目录
     * @return 已登记时返回 true
     */
    boolean existsByOwnerUserIdAndStorageLocationIdAndRelativeRoot(
            UUID ownerUserId,
            UUID storageLocationId,
            String relativeRoot
    );

    boolean existsByStorageLocationIdAndRelativeRoot(UUID storageLocationId, String relativeRoot);

    /**
     * 统计存储位置关联的影视库来源数量。
     *
     * @param storageLocationId 存储位置 ID
     * @return 来源数量
     */
    long countByStorageLocationId(UUID storageLocationId);
}
