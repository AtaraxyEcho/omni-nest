package com.omninest.modules.reader.repository;

import com.omninest.modules.reader.domain.ReaderItemSource;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * 漫画来源仓储。
 */
public interface ReaderItemSourceRepository extends JpaRepository<ReaderItemSource, UUID> {

    /** 按阅读条目 ID 查询所有来源文件。 */
    List<ReaderItemSource> findByReaderItemId(UUID readerItemId);

    /** 按阅读条目 ID 统计来源数量。 */
    long countByReaderItemId(UUID readerItemId);

    /**
     * 按阅读条目和文件节点查询唯一来源。
     *
     * @param readerItemId 阅读条目 ID
     * @param fileNodeId 文件节点 ID
     * @return 已存在的来源
     */
    Optional<ReaderItemSource> findByReaderItemIdAndFileNodeId(UUID readerItemId, UUID fileNodeId);

    /** 批量按阅读条目 ID 查询来源文件。 */
    List<ReaderItemSource> findByReaderItemIdIn(Collection<UUID> readerItemIds);

    /** 按文件节点批量查询来源文件。 */
    List<ReaderItemSource> findByFileNodeIdIn(Collection<UUID> fileNodeIds);

    /** 批量查询当前用户已作为漫画来源使用的文件节点。 */
    @Query("""
            select distinct source.fileNodeId from ReaderItemSource source, ReaderItem item
            where source.readerItemId = item.id
              and item.ownerUserId = :ownerUserId
              and source.fileNodeId in :fileNodeIds
            """)
    List<UUID> findImportedFileNodeIds(
            @Param("ownerUserId") UUID ownerUserId,
            @Param("fileNodeIds") Collection<UUID> fileNodeIds
    );

    /** 按阅读条目 ID 删除所有来源文件。 */
    void deleteByReaderItemId(UUID readerItemId);

    /** 批量按阅读条目 ID 删除所有来源文件。 */
    void deleteByReaderItemIdIn(Collection<UUID> readerItemIds);
}
