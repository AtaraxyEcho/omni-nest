package com.omninest.modules.reader.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "reader_bookmarks", schema = "omni")
@Data
@AllArgsConstructor
@NoArgsConstructor
public class ReaderBookmark {
    @Id
    private UUID id;

    @Column(name = "owner_user_id", nullable = false)
    private UUID ownerUserId;

    @Column(name = "reader_item_id", nullable = false)
    private UUID readerItemId;

    @Column(name = "client_operation_id", length = 120)
    private String clientOperationId;

    @Column(name = "char_offset", nullable = false)
    private long charOffset = 0;

    @Column(name = "progress_percent", nullable = false)
    private BigDecimal progressPercent = BigDecimal.ZERO;

    @Column(columnDefinition = "text")
    private String note;

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
