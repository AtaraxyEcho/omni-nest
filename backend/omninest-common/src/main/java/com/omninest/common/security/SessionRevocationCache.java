package com.omninest.common.security;

import java.time.Duration;
import java.util.Collection;
import java.util.UUID;

/**
 * 定义会话撤销正命中缓存能力。
 *
 * @author OmniNest
 */
public interface SessionRevocationCache {

    /**
     * 缓存已撤销的会话标识。
     *
     * @param userId 用户标识
     * @param sessionIds 会话标识集合
     * @param ttl 缓存保留时间
     */
    void markRevoked(UUID userId, Collection<UUID> sessionIds, Duration ttl);

    /**
     * 判断缓存中是否存在撤销标记。
     *
     * @param userId 用户标识
     * @param sessionId 会话标识
     * @return 存在撤销标记时返回 {@code true}
     */
    boolean contains(UUID userId, UUID sessionId);
}
