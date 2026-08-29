package com.omninest.modules.quota.repository;

import com.omninest.modules.quota.domain.StorageQuotaReservation;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 存储配额预留仓储。
 *
 * @author OmniNest
 */
public interface StorageQuotaReservationRepository extends JpaRepository<StorageQuotaReservation, UUID> {
    Optional<StorageQuotaReservation> findBySourceTypeAndSourceId(String sourceType, UUID sourceId);

    List<StorageQuotaReservation> findByStatusAndExpiresAtBeforeOrderByExpiresAtAsc(
            String status,
            Instant expiresAt,
            Pageable pageable
    );
}
