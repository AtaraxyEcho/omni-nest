package com.omninest.modules.file.repository;

import com.omninest.modules.file.domain.FilePurgeEntry;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * 文件永久删除清单仓储。
 *
 * @author OmniNest
 */
public interface FilePurgeEntryRepository extends JpaRepository<FilePurgeEntry, UUID> {
    List<FilePurgeEntry> findByTaskIdAndStatusInOrderByCreatedAtAsc(
            UUID taskId,
            Collection<String> statuses,
            Pageable pageable
    );

    List<FilePurgeEntry> findByTaskId(UUID taskId);

    List<FilePurgeEntry> findByTaskIdAndFileNodeIdIn(UUID taskId, Collection<UUID> fileNodeIds);

    List<FilePurgeEntry> findByTaskIdAndObjectIdIn(UUID taskId, Collection<UUID> objectIds);

    List<FilePurgeEntry> findByTaskIdAndEntryType(UUID taskId, String entryType);

    long countByTaskIdAndStatusIn(UUID taskId, Collection<String> statuses);

    /**
     * 将上一次执行失败的条目重置为待处理状态。
     *
     * @param taskId 任务 ID
     * @return 重置的条目数量
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update FilePurgeEntry entry set entry.status = 'PENDING' "
            + "where entry.taskId = :taskId and entry.status = 'FAILED'")
    int resetFailedEntries(@Param("taskId") UUID taskId);

    /**
     * 统计任务的删除清单数量。
     *
     * @param taskId 任务 ID
     * @return 清单数量
     */
    long countByTaskId(UUID taskId);

    /**
     * 查询任务清单中关联的文件节点 ID。
     *
     * @param taskId 任务 ID
     * @return 去重后的文件节点 ID
     */
    @Query("select distinct entry.fileNodeId from FilePurgeEntry entry "
            + "where entry.taskId = :taskId and entry.fileNodeId is not null")
    List<UUID> findFileNodeIdsByTaskId(@Param("taskId") UUID taskId);

    boolean existsByTaskId(UUID taskId);
}
