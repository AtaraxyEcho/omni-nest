package com.omninest.common.security;

import java.time.Duration;
import java.util.Collection;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * 使用 Redis 保存会话撤销正命中缓存。
 *
 * @author OmniNest
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RedisSessionRevocationCache implements SessionRevocationCache {

    private static final String BLACKLIST_PREFIX = "session:blacklist:";

    private final StringRedisTemplate redis;

    /**
     * {@inheritDoc}
     */
    @Override
    public void markRevoked(UUID userId, Collection<UUID> sessionIds, Duration ttl) {
        if (sessionIds == null || sessionIds.isEmpty()) {
            return;
        }
        try {
            String key = BLACKLIST_PREFIX + userId;
            String[] values = sessionIds.stream().map(UUID::toString).toArray(String[]::new);
            redis.opsForSet().add(key, values);
            redis.expire(key, ttl);
        } catch (RuntimeException exception) {
            log.warn("Redis 会话撤销缓存写入失败: userId={}, count={}", userId, sessionIds.size(), exception);
        }
    }

    /**
     * {@inheritDoc}
     */
    @Override
    public boolean contains(UUID userId, UUID sessionId) {
        try {
            return Boolean.TRUE.equals(redis.opsForSet().isMember(
                    BLACKLIST_PREFIX + userId,
                    sessionId.toString()
            ));
        } catch (RuntimeException exception) {
            log.warn("Redis 会话撤销缓存查询失败: userId={}", userId, exception);
            return false;
        }
    }
}
