package com.omninest.modules.video.repository;

import com.omninest.modules.video.domain.MediaScanRun;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/** 媒体发现运行仓储。 */
public interface MediaScanRunRepository extends JpaRepository<MediaScanRun, UUID> {

    Optional<MediaScanRun> findByIdAndOwnerUserId(UUID id, UUID ownerUserId);

    Optional<MediaScanRun> findFirstByOwnerUserIdAndLibrarySourceIdOrderByCreatedAtDesc(
            UUID ownerUserId,
            UUID librarySourceId
    );

    Optional<MediaScanRun> findFirstByLibrarySourceIdOrderByCreatedAtDesc(UUID librarySourceId);

    boolean existsByLibrarySourceIdAndStatusIn(UUID librarySourceId, Collection<String> statuses);

    boolean existsByOwnerUserIdAndLibrarySourceIdAndStatusIn(
            UUID ownerUserId,
            UUID librarySourceId,
            Collection<String> statuses
    );

    List<MediaScanRun> findAllByLibrarySourceId(UUID librarySourceId);

    void deleteByLibrarySourceId(UUID librarySourceId);
}
