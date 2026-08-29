package com.omninest.modules.file.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import com.omninest.modules.file.domain.EncryptionStatus;
import com.omninest.modules.file.domain.StorageClass;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "file_objects", schema = "omni")
@Data
@AllArgsConstructor
@NoArgsConstructor
public class FileObject {
    @Id
    private UUID id;

    @Column(name = "bucket_name", nullable = false, length = 80)
    private String bucketName;

    @Column(name = "object_key", nullable = false)
    private String objectKey;

    @Column(length = 64)
    private String sha256;

    @Column(name = "size_bytes", nullable = false)
    private long sizeBytes;

    @Column(name = "mime_type", length = 160)
    private String mimeType;

    @Column(name = "storage_class", nullable = false, length = 32)
    private String storageClass = StorageClass.STANDARD.getValue();

    @Column(name = "encryption_status", nullable = false, length = 32)
    private String encryptionStatus = EncryptionStatus.SERVER_SIDE.getValue();

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @PrePersist
    void fillDefaults() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}
