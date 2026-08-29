package com.omninest.modules.photos.service;

import com.omninest.modules.photos.domain.PhotoBackupStatus;
import com.omninest.modules.photos.dto.PhotoDtos.PhotoBackupStatusDto;
import com.omninest.modules.photos.repository.PhotoBackupStatusRepository;
import com.omninest.modules.photos.repository.PhotoItemRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 照片备份状态服务。
 * 管理设备备份状态和重复检测。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PhotoBackupService {

    private final PhotoBackupStatusRepository backupStatusRepository;
    private final PhotoItemRepository photoItemRepository;

    /**
     * 获取设备的备份状态。
     */
    @Transactional(readOnly = true)
    public PhotoBackupStatusDto getBackupStatus(UUID ownerUserId, String deviceId) {
        return backupStatusRepository.findByOwnerUserIdAndDeviceId(ownerUserId, deviceId)
                .map(status -> new PhotoBackupStatusDto(
                        status.getDeviceId(),
                        status.getLastBackupAt(),
                        status.getLastPhotoCount()
                ))
                .orElse(new PhotoBackupStatusDto(deviceId, null, 0));
    }

    /**
     * 上报备份进度。
     */
    @Transactional(rollbackFor = Exception.class)
    public void reportBackup(UUID ownerUserId, String deviceId, int photoCount) {
        PhotoBackupStatus status = backupStatusRepository
                .findByOwnerUserIdAndDeviceId(ownerUserId, deviceId)
                .orElseGet(() -> {
                    PhotoBackupStatus newStatus = new PhotoBackupStatus();
                    newStatus.setOwnerUserId(ownerUserId);
                    newStatus.setDeviceId(deviceId);
                    return newStatus;
                });
        status.setLastBackupAt(Instant.now());
        status.setLastPhotoCount(photoCount);
        backupStatusRepository.save(status);
        log.info("备份状态已更新: ownerUserId={}, deviceId={}, photoCount={}", ownerUserId, deviceId, photoCount);
    }

    /**
     * 检查重复的照片哈希。
     * 通过 providerMetadata.contentHash 字段精确匹配，返回已存在的哈希列表。
     */
    @Transactional(readOnly = true)
    public List<String> checkDuplicate(UUID ownerUserId, List<String> contentHashes) {
        if (contentHashes == null || contentHashes.isEmpty()) {
            return List.of();
        }
        return photoItemRepository.findExistingContentHashes(ownerUserId, contentHashes);
    }
}
