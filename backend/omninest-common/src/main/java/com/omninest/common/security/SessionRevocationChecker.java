package com.omninest.common.security;

import java.util.UUID;

/**
 * 提供会话撤销状态的统一判定能力。
 *
 * @author OmniNest
 */
public interface SessionRevocationChecker {

    /**
     * 判断指定会话是否已被撤销。
     *
     * @param userId 用户标识
     * @param sessionId 会话标识
     * @return 已撤销时返回 {@code true}
     */
    boolean isRevoked(UUID userId, UUID sessionId);
}
