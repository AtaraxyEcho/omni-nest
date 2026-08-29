package com.omninest.modules.file.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 外部存储远程目录元数据缓存。
 * <p>
 * 缓存 Rclone 目录列表结果到 PostgreSQL，减少实时远程调用。
 */
@Entity
@Table(name = "storage_remote_metadata_cache", schema = "omni")
@Data
@AllArgsConstructor
@NoArgsConstructor
public class StorageRemoteMetadataCache {

    @Id
    private UUID id;

    @Column(name = "external_account_id", nullable = false)
    private UUID externalAccountId;

    @Column(name = "remote_path", nullable = false, length = 1024)
    private String remotePath;

    @Column(name = "metadata_json", nullable = false, columnDefinition = "jsonb")
    private String metadataJson;

    @Column(name = "cached_at", nullable = false)
    private Instant cachedAt;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @PrePersist
    void fillCreatedFields() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        Instant now = Instant.now();
        if (cachedAt == null) {
            cachedAt = now;
        }
    }
}
