package com.omninest.modules.file.repository;

import com.omninest.modules.file.domain.FileIngressItem;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 文件安全入库状态仓储。
 *
 * @author OmniNest
 */
public interface FileIngressItemRepository extends JpaRepository<FileIngressItem, UUID> {

    /**
     * 按上传会话查询入库状态。
     *
     * @param uploadSessionId 上传会话标识
     * @return 入库状态
     */
    Optional<FileIngressItem> findByUploadSessionId(UUID uploadSessionId);
}
