package com.omninest.common.audit;

import java.util.Map;
import java.util.UUID;

/**
 * 跨业务模块记录管理审计事件的公共端口。
 *
 * @author OmniNest
 */
public interface AdminAuditRecorder {

    /**
     * 在当前业务事务中记录管理审计事件。
     *
     * @param actorUserId 操作用户标识
     * @param action 管理动作
     * @param resourceType 资源类型
     * @param resourceId 资源标识
     * @param metadata 非敏感审计元数据
     */
    void recordWithMetadata(
            UUID actorUserId,
            String action,
            String resourceType,
            UUID resourceId,
            Map<String, Object> metadata
    );
}
