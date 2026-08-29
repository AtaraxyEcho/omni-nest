package com.omninest.modules.reader.repository;

import com.omninest.modules.file.domain.SpaceType;
import com.omninest.modules.reader.domain.ReaderItem;
import jakarta.persistence.LockModeType;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * 阅读条目仓储。
 */
public interface ReaderItemRepository extends JpaRepository<ReaderItem, UUID> {

    /**
     * 获取阅读条目并加写锁，用于串行化同一条目的来源创建与状态迁移。
     *
     * @param id 阅读条目 ID
     * @return 已加写锁的阅读条目
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT item FROM ReaderItem item WHERE item.id = :id")
    Optional<ReaderItem> findByIdForUpdate(@Param("id") UUID id);

    List<ReaderItem> findByOwnerUserIdOrderByUpdatedAtDesc(UUID ownerUserId);

    List<ReaderItem> findByOwnerUserIdAndItemTypeOrderByUpdatedAtDesc(UUID ownerUserId, String itemType);

    List<ReaderItem> findByOwnerUserIdAndContentKindOrderByUpdatedAtDesc(UUID ownerUserId, String contentKind);

    Optional<ReaderItem> findByIdAndOwnerUserId(UUID id, UUID ownerUserId);

    Optional<ReaderItem> findByOwnerUserIdAndFileNodeId(UUID ownerUserId, UUID fileNodeId);

    long countByOwnerUserId(UUID ownerUserId);

    List<ReaderItem> findByFileNodeIdIn(Collection<UUID> fileNodeIds);

    List<ReaderItem> findByOwnerUserIdAndFileNodeIdIn(UUID ownerUserId, Collection<UUID> fileNodeIds);

    List<ReaderItem> findByOwnerUserIdAndCoverFileIdIn(UUID ownerUserId, Collection<UUID> coverFileIds);

    /**
     * 按封面文件批量查询全部阅读条目。
     *
     * @param coverFileIds 封面文件节点 ID
     * @return 阅读条目
     */
    List<ReaderItem> findByCoverFileIdIn(Collection<UUID> coverFileIds);

    /**
     * 按内容哈希查找已有条目（用于内容级去重）。
     */
    List<ReaderItem> findByContentHash(String contentHash);

    Optional<ReaderItem> findFirstByOwnerUserIdAndContentHashOrderByUpdatedAtDesc(
            UUID ownerUserId, String contentHash);

    @Query("select distinct item.contentHash from ReaderItem item "
            + "where item.ownerUserId = :ownerUserId and item.contentHash is not null")
    List<String> findContentHashesByOwnerUserId(@Param("ownerUserId") UUID ownerUserId);

    /**
     * 对用户与内容摘要加事务级数据库锁，串行化并发重复导入。
     */
    @Query(value = """
            SELECT pg_advisory_xact_lock(
                hashtextextended(CAST(:ownerUserId AS text) || ':' || :contentHash, 0)
            )
            """, nativeQuery = true)
    void lockContentHash(@Param("ownerUserId") UUID ownerUserId, @Param("contentHash") String contentHash);

    /**
     * 查询用户可见的所有阅读条目（个人空间 + 共享空间）。
     */
    @Query("""
            SELECT DISTINCT ri FROM ReaderItem ri
            JOIN FileNode f ON ri.fileNodeId = f.id
            WHERE f.deleted = false
              AND (ri.ownerUserId = :userId OR f.spaceType = :sharedType)
            ORDER BY ri.updatedAt DESC
            """)
    List<ReaderItem> findItemsVisibleToUser(@Param("userId") UUID userId, @Param("sharedType") SpaceType sharedType);
}
