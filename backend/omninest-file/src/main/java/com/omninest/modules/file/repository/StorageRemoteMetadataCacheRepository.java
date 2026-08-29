package com.omninest.modules.file.repository;

import com.omninest.modules.file.domain.StorageRemoteMetadataCache;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 外部存储元数据缓存仓储。
 */
public interface StorageRemoteMetadataCacheRepository extends JpaRepository<StorageRemoteMetadataCache, UUID> {

    /**
     * 查询指定账户和路径的缓存记录。
     */
    List<StorageRemoteMetadataCache> findByExternalAccountIdAndRemotePath(UUID externalAccountId, String remotePath);

    /**
     * 删除指定账户和路径的所有缓存记录。
     */
    void deleteByExternalAccountIdAndRemotePath(UUID externalAccountId, String remotePath);

    /**
     * 删除指定账户的所有缓存记录。
     */
    void deleteByExternalAccountId(UUID externalAccountId);
}
