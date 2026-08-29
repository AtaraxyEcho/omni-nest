package com.omninest.modules.video.repository;

import com.omninest.modules.video.domain.MediaScanBatch;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/** 自适应媒体批次仓储。 */
public interface MediaScanBatchRepository extends JpaRepository<MediaScanBatch, UUID> {

    Optional<MediaScanBatch> findFirstByOwnerUserIdAndScanRunIdAndPhaseOrderByBatchNoDesc(
            UUID ownerUserId,
            UUID scanRunId,
            String phase
    );

    void deleteByOwnerUserIdAndScanRunIdAndPhase(UUID ownerUserId, UUID scanRunId, String phase);

    void deleteByScanRunId(UUID scanRunId);
}
