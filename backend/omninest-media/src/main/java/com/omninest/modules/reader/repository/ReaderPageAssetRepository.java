package com.omninest.modules.reader.repository;

import com.omninest.modules.reader.domain.ReaderPageAsset;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * 漫画页面派生资源仓储。
 *
 * @author OmniNest
 */
public interface ReaderPageAssetRepository extends JpaRepository<ReaderPageAsset, UUID> {

    /**
     * 查询指定页面在指定清单版本下的派生资源。
     *
     * @param pageId 页面 ID
     * @param manifestVersion 清单版本
     * @return 派生资源
     */
    Optional<ReaderPageAsset> findByPageIdAndManifestVersion(UUID pageId, int manifestVersion);

    /**
     * 查询指定页面最新的派生资源。
     *
     * @param pageId 页面 ID
     * @return 最新派生资源
     */
    Optional<ReaderPageAsset> findFirstByPageIdOrderByManifestVersionDesc(UUID pageId);

    /**
     * 批量查询阅读条目下的派生资源。
     *
     * @param readerItemIds 阅读条目 ID 集合
     * @return 派生资源列表
     */
    List<ReaderPageAsset> findByReaderItemIdIn(Collection<UUID> readerItemIds);

    /**
     * 查询来源下的所有派生资源。
     *
     * @param sourceId 来源 ID
     * @return 派生资源列表
     */
    List<ReaderPageAsset> findBySourceId(UUID sourceId);

    /**
     * 删除来源下的所有派生资源。
     *
     * @param sourceId 来源 ID
     */
    void deleteBySourceId(UUID sourceId);

    /**
     * 批量删除阅读条目下的派生资源记录。
     *
     * @param readerItemIds 阅读条目 ID 集合
     */
    void deleteByReaderItemIdIn(Collection<UUID> readerItemIds);

    /**
     * 查询候选对象键中已有漫画页面元数据引用的键。
     *
     * @param bucketName 存储桶名称
     * @param objectKeys 候选对象键
     * @return 已引用对象键
     */
    @Query("""
            select asset.objectKey
            from ReaderPageAsset asset
            where asset.bucketName = :bucketName
              and asset.objectKey in :objectKeys
            """)
    List<String> findReferencedObjectKeys(
            @Param("bucketName") String bucketName,
            @Param("objectKeys") Collection<String> objectKeys
    );
}
