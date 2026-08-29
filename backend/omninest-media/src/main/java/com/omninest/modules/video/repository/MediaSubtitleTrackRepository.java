package com.omninest.modules.video.repository;

import com.omninest.modules.video.domain.MediaSubtitleTrack;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MediaSubtitleTrackRepository extends JpaRepository<MediaSubtitleTrack, UUID> {
    List<MediaSubtitleTrack> findByOwnerUserIdAndVideoItemIdOrderBySortOrderAsc(UUID ownerUserId, UUID videoItemId);

    void deleteByOwnerUserIdAndVideoItemIdIn(UUID ownerUserId, Collection<UUID> videoItemIds);

    void deleteByOwnerUserIdAndFileNodeIdIn(UUID ownerUserId, Collection<UUID> fileNodeIds);

    /**
     * 按字幕文件节点批量查询全部字幕轨道。
     *
     * @param fileNodeIds 文件节点 ID
     * @return 字幕轨道
     */
    List<MediaSubtitleTrack> findByFileNodeIdIn(Collection<UUID> fileNodeIds);

    /**
     * 按字幕文件节点批量删除全部字幕轨道。
     *
     * @param fileNodeIds 文件节点 ID
     */
    void deleteByFileNodeIdIn(Collection<UUID> fileNodeIds);
}
