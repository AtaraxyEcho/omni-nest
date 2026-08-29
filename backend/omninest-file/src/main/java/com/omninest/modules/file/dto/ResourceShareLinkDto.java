package com.omninest.modules.file.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * 跨模块使用的资源分享链接描述符。
 *
 * @param id 分享链接 ID
 * @param token 仅创建时返回的原始令牌
 * @param resourceType 资源类型
 * @param resourceId 资源 ID
 * @param expiresAt 过期时间
 * @param maxAccessCount 最大访问次数
 * @param accessCount 已访问次数
 * @param createdAt 创建时间
 * @author OmniNest
 */
public record ResourceShareLinkDto(
        UUID id,
        String token,
        String resourceType,
        UUID resourceId,
        Instant expiresAt,
        Integer maxAccessCount,
        int accessCount,
        Instant createdAt
) {
}
