package com.omninest.modules.file.repository;

import com.omninest.modules.file.domain.StorageLocation;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 存储位置元数据仓储。
 *
 * @author OmniNest
 */
public interface StorageLocationRepository extends JpaRepository<StorageLocation, UUID> {

    /**
     * 按名称排序读取全部存储位置。
     *
     * @return 存储位置列表
     */
    List<StorageLocation> findAllByOrderByNameAsc();

    /**
     * 判断相同挂载、根目录和作用域的存储位置是否存在。
     *
     * @param mountKey 挂载键
     * @param relativeRoot 相对根目录
     * @param scopeType 作用域类型
     * @param scopeId 作用域 ID
     * @return 存在时返回 true
     */
    boolean existsByMountKeyAndRelativeRootAndScopeTypeAndScopeId(
            String mountKey,
            String relativeRoot,
            String scopeType,
            UUID scopeId
    );
}
