package com.omninest.modules.photos.repository;

import com.omninest.modules.photos.domain.PhotoBatchTask;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 照片批量任务仓储接口
 */
public interface PhotoBatchTaskRepository extends JpaRepository<PhotoBatchTask, UUID> {

    /**
     * 按ID和用户查询批量任务
     */
    Optional<PhotoBatchTask> findByIdAndOwnerUserId(UUID id, UUID ownerUserId);

    /**
     * 按用户查询批量任务列表，按创建时间倒序
     */
    List<PhotoBatchTask> findByOwnerUserIdOrderByCreatedAtDesc(UUID ownerUserId);
}
