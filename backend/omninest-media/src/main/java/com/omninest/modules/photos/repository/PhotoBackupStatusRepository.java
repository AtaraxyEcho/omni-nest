package com.omninest.modules.photos.repository;

import com.omninest.modules.photos.domain.PhotoBackupStatus;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/**
 * 照片备份状态数据访问层。
 */
@Repository
public interface PhotoBackupStatusRepository extends JpaRepository<PhotoBackupStatus, UUID> {

    Optional<PhotoBackupStatus> findByOwnerUserIdAndDeviceId(UUID ownerUserId, String deviceId);
}
