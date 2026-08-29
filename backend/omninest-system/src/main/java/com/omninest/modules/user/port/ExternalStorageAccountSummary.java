package com.omninest.modules.user.port;

import java.time.Instant;
import java.util.UUID;

/**
 * 外部存储账户摘要。
 *
 * @param id 账户标识
 * @param provider 存储提供方
 * @param displayName 显示名称
 * @param status 账户状态
 * @param createdAt 创建时间
 * @param updatedAt 更新时间
 * @author OmniNest
 */
public record ExternalStorageAccountSummary(
        UUID id,
        String provider,
        String displayName,
        String status,
        Instant createdAt,
        Instant updatedAt
) {
}
