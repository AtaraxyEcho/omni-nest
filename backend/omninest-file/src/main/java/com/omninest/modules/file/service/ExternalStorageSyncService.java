package com.omninest.modules.file.service;

import com.omninest.common.rclone.RcloneGateway;
import com.omninest.modules.file.domain.StorageRemoteMetadataCache;
import com.omninest.modules.file.repository.StorageRemoteMetadataCacheRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;

/**
 * 外部存储元数据同步服务。
 * <p>
 * 将远程目录结构缓存到 PostgreSQL，减少实时 Rclone 调用。
 * 缓存有效期默认 1 小时，过期后由调用方决定是否重新同步。
 *
 * @author OmniNest
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ExternalStorageSyncService {

    private static final long CACHE_TTL_SECONDS = 3600;

    private final StorageRemoteMetadataCacheRepository metadataCacheRepository;
    private final RcloneGateway rcloneGateway;
    private final ObjectMapper objectMapper;

    /**
     * 同步指定路径的目录元数据到数据库。
     *
     * @param externalAccountId 外部存储账户 ID
     * @param fs                Rclone 文件系统标识（如 {@code omni-12345678:}）
     * @param remotePath        远程目录路径
     */
    @Transactional(rollbackFor = Exception.class)
    public void syncDirectory(UUID externalAccountId, String fs, String remotePath) {
        // 清除该路径的旧缓存
        metadataCacheRepository.deleteByExternalAccountIdAndRemotePath(externalAccountId, remotePath);

        // 从 Rclone 获取远程文件列表并保存普通 Java 元数据
        List<RcloneGateway.DirectoryEntry> entries = rcloneGateway.listDirectory(fs, remotePath, false);
        String metadataJson = objectMapper.writeValueAsString(
                entries.stream().map(RcloneGateway.DirectoryEntry::metadata).toList()
        );

        // 写入新缓存
        StorageRemoteMetadataCache entity = new StorageRemoteMetadataCache();
        entity.setId(UUID.randomUUID());
        entity.setExternalAccountId(externalAccountId);
        entity.setRemotePath(remotePath);
        entity.setMetadataJson(metadataJson);
        entity.setCachedAt(Instant.now());
        entity.setExpiresAt(Instant.now().plusSeconds(CACHE_TTL_SECONDS));
        metadataCacheRepository.save(entity);

        log.info("外部存储元数据同步完成: accountId={}, files={}",
                externalAccountId, entries.size());
    }

    /**
     * 从缓存读取目录内容。
     *
     * @param externalAccountId 外部存储账户 ID
     * @param remotePath        远程目录路径
     * @return 缓存的元数据 JSON 字符串，无缓存时返回 null
     */
    @Transactional(readOnly = true)
    public String getCachedMetadata(UUID externalAccountId, String remotePath) {
        return metadataCacheRepository.findByExternalAccountIdAndRemotePath(externalAccountId, remotePath)
                .stream()
                .findFirst()
                .map(StorageRemoteMetadataCache::getMetadataJson)
                .orElse(null);
    }

    /**
     * 检查缓存是否过期。
     *
     * @param externalAccountId 外部存储账户 ID
     * @param remotePath        远程目录路径
     * @return 缓存过期或不存在时返回 true
     */
    @Transactional(readOnly = true)
    public boolean isCacheStale(UUID externalAccountId, String remotePath) {
        return metadataCacheRepository.findByExternalAccountIdAndRemotePath(externalAccountId, remotePath)
                .stream()
                .findFirst()
                .map(cached -> Instant.now().isAfter(cached.getExpiresAt()))
                .orElse(true);
    }

    /**
     * 清除指定账户的所有缓存。
     */
    @Transactional(rollbackFor = Exception.class)
    public void clearCache(UUID externalAccountId) {
        metadataCacheRepository.deleteByExternalAccountId(externalAccountId);
        log.info("外部存储缓存已清除: accountId={}", externalAccountId);
    }
}
