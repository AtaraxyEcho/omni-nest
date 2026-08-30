package com.omninest.modules.file.repository;

import com.omninest.modules.file.domain.FileUploadSession;
import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface FileUploadSessionRepository extends JpaRepository<FileUploadSession, UUID> {
    Optional<FileUploadSession> findByIdAndOwnerUserId(UUID id, UUID ownerUserId);

    Optional<FileUploadSession> findByUploadIdAndOwnerUserId(String uploadId, UUID ownerUserId);

    /**
     * 查询并锁定上传会话，串行化所有会改变会话状态的操作。
     *
     * @param uploadId 对象存储上传标识
     * @param ownerUserId 所有者用户 ID
     * @return 被锁定的上传会话
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            SELECT session
            FROM FileUploadSession session
            WHERE session.uploadId = :uploadId
              AND session.ownerUserId = :ownerUserId
            """)
    Optional<FileUploadSession> findForUpdateByUploadIdAndOwnerUserId(
            @Param("uploadId") String uploadId,
            @Param("ownerUserId") UUID ownerUserId);

    List<FileUploadSession> findByOwnerUserIdOrderByUpdatedAtDesc(UUID ownerUserId);

    List<FileUploadSession> findByStatusAndUpdatedAtBefore(String status, Instant updatedAt);

    List<FileUploadSession> findByStatusInAndUpdatedAtBefore(List<String> statuses, Instant updatedAt);

    /**
     * 原子领取上传完成操作，确保同一会话只执行一次对象存储提交。
     *
     * @param uploadId 对象存储上传标识
     * @param ownerUserId 所有者用户 ID
     * @param allowedStatuses 可领取状态
     * @param claimedStatus 领取后的状态
     * @param now 当前时间
     * @return 成功领取时为 1，否则为 0
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            UPDATE FileUploadSession session
            SET session.status = :claimedStatus,
                session.updatedAt = :now,
                session.version = session.version + 1
            WHERE session.uploadId = :uploadId
              AND session.ownerUserId = :ownerUserId
              AND session.status IN :allowedStatuses
              AND session.expiresAt > :now
            """)
    int claimForCompletion(
            @Param("uploadId") String uploadId,
            @Param("ownerUserId") UUID ownerUserId,
            @Param("allowedStatuses") List<String> allowedStatuses,
            @Param("claimedStatus") String claimedStatus,
            @Param("now") Instant now
    );
}
