package com.omninest.modules.photos.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 照片人脸检测实体。
 * 存储 AI 检测到的人脸位置、嵌入向量和聚类归属。
 */
@Data
@AllArgsConstructor
@NoArgsConstructor
@Entity
@Table(name = "photo_faces", schema = "omni")
public class PhotoFace {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "photo_id", nullable = false)
    private UUID photoId;

    @Column(name = "owner_user_id", nullable = false)
    private UUID ownerUserId;

    @Column(name = "bbox_x", nullable = false)
    private int bboxX;

    @Column(name = "bbox_y", nullable = false)
    private int bboxY;

    @Column(name = "bbox_w", nullable = false)
    private int bboxW;

    @Column(name = "bbox_h", nullable = false)
    private int bboxH;

    @Column(name = "embedding", columnDefinition = "bytea")
    private byte[] embedding;

    @Column(name = "cluster_id")
    private UUID clusterId;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    void prePersist() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}
