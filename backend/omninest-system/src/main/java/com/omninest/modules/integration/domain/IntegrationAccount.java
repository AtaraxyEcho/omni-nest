package com.omninest.modules.integration.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 用户绑定的外部集成账号及其加密凭据。
 *
 * @author OmniNest
 */
@Entity
@Table(name = "integration_accounts", schema = "omni")
@Data
@AllArgsConstructor
@NoArgsConstructor
public class IntegrationAccount {
    @Id
    private UUID id;

    @Column(name = "owner_user_id", nullable = false)
    private UUID ownerUserId;

    @Column(name = "integration_type", nullable = false, length = 64)
    private String integrationType;

    @Column(nullable = false, length = 64)
    private String provider;

    @Column(name = "external_user_id", length = 255)
    private String externalUserId;

    @Column(name = "display_name", length = 160)
    private String displayName;

    @Column(name = "avatar_url", length = 1024)
    private String avatarUrl;

    @Column(name = "encrypted_credentials", nullable = false)
    private String encryptedCredentials;

    @Column(name = "credential_key_version", nullable = false)
    private int credentialKeyVersion;

    @Column(nullable = false, length = 32)
    private String status = "ACTIVE";

    @Column(name = "last_verified_at")
    private Instant lastVerifiedAt;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Version
    @Column(nullable = false)
    private long version;

    /**
     * 初始化主键和审计时间。
     */
    @PrePersist
    void fillCreatedFields() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        Instant now = Instant.now();
        if (createdAt == null) {
            createdAt = now;
        }
        if (updatedAt == null) {
            updatedAt = now;
        }
    }

    /**
     * 更新修改时间。
     */
    @PreUpdate
    void fillUpdatedAt() {
        updatedAt = Instant.now();
    }
}
