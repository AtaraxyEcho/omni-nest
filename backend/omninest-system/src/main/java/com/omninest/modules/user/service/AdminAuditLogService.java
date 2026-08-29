package com.omninest.modules.user.service;

import com.omninest.common.audit.AdminAuditRecorder;
import com.omninest.modules.user.repository.AdminAuditLogRepository;
import java.util.Map;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 管理审计日志及对应实时失效事件写入服务。
 *
 * @author OmniNest
 */
@Service
@RequiredArgsConstructor
public class AdminAuditLogService implements AdminAuditRecorder {
    private final AdminAuditLogRepository adminAuditLogRepository;
    private final AdminSyncEventService adminSyncEventService;

    /**
     * 记录管理审计日志。
     *
     * @param actorUserId 操作用户标识
     * @param action 管理动作
     * @param resourceType 资源类型
     * @param resourceId 资源标识
     */
    @Transactional(rollbackFor = Exception.class)
    public void record(UUID actorUserId, String action, String resourceType, UUID resourceId) {
        adminAuditLogRepository.insert(actorUserId, action, resourceType, resourceId, Map.of());
        adminSyncEventService.record(action, resourceType, resourceId);
    }

    /**
     * 记录审计日志并附带元数据。
     *
     * @param actorUserId 操作用户标识
     * @param action 管理动作
     * @param resourceType 资源类型
     * @param resourceId 资源标识
     * @param metadata 非敏感审计元数据
     */
    @Override
    @Transactional(rollbackFor = Exception.class)
    public void recordWithMetadata(
            UUID actorUserId,
            String action,
            String resourceType,
            UUID resourceId,
            Map<String, Object> metadata
    ) {
        adminAuditLogRepository.insert(actorUserId, action, resourceType, resourceId, metadata);
        adminSyncEventService.record(action, resourceType, resourceId);
    }
}
