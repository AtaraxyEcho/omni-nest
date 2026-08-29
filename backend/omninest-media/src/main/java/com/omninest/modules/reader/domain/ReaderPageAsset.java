package com.omninest.modules.reader.domain;
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
 * 漫画页面派生资源实体，记录阅读态可直接读取的页面图片对象。
 *
 * @author OmniNest
 */
@Entity
@Table(name = "reader_page_assets", schema = "omni")
@Data
@AllArgsConstructor
@NoArgsConstructor
public class ReaderPageAsset {

    @Id
    private UUID id;

    /** 所属页面 ID */
    @Column(name = "page_id", nullable = false)
    private UUID pageId;

    /** 所属阅读条目 ID */
    @Column(name = "reader_item_id", nullable = false)
    private UUID readerItemId;

    /** 所属来源 ID */
    @Column(name = "source_id", nullable = false)
    private UUID sourceId;

    /** 资源对应的清单版本 */
    @Column(name = "manifest_version", nullable = false)
    private int manifestVersion;

    /** 对象存储 bucket */
    @Column(name = "bucket_name", nullable = false, length = 100)
    private String bucketName;

    /** 对象存储 key */
    @Column(name = "object_key", nullable = false, length = 1000)
    private String objectKey;

    /** 图片 MIME 类型 */
    @Column(name = "mime_type", nullable = false, length = 50)
    private String mimeType;

    /** 图片字节数 */
    @Column(name = "byte_size", nullable = false)
    private long byteSize;

    /** 图片校验指纹 */
    @Column(length = 64)
    private String checksum;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @PrePersist
    void fillCreatedFields() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}
