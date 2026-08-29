package com.omninest.modules.file.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "file_node_permissions", schema = "omni")
@Data
@AllArgsConstructor
@NoArgsConstructor
public class FileNodePermission {
    @Id
    private UUID id;

    @Column(name = "file_node_id", nullable = false)
    private UUID fileNodeId;

    @Column(name = "grantee_user_id")
    private UUID granteeUserId;

    @Column(name = "allow_view", nullable = false)
    private boolean allowView = true;

    @Column(name = "allow_download", nullable = false)
    private boolean allowDownload = true;

    @Column(name = "allow_share", nullable = false)
    private boolean allowShare;

    @Column(name = "allow_edit", nullable = false)
    private boolean allowEdit;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(nullable = false)
    private long version;

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

    @PreUpdate
    void fillUpdatedAt() {
        updatedAt = Instant.now();
    }
}
