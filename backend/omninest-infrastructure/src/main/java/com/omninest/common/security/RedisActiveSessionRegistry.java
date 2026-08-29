package com.omninest.common.security;

import java.time.Duration;
import java.util.Optional;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * 使用 Redis 注册用户各客户端平台的活动会话。
 *
 * @author OmniNest
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RedisActiveSessionRegistry implements ActiveSessionRegistry {

    private static final String ACTIVE_PREFIX = "session:active:";

    private final StringRedisTemplate redis;

    /**
     * {@inheritDoc}
     */
    @Override
    public void register(UUID userId, String platform, UUID sessionId, Duration ttl) {
        try {
            redis.opsForValue().set(key(userId, platform), sessionId.toString(), ttl);
        } catch (RuntimeException exception) {
            log.warn("Redis 活动会话写入失败: userId={}, platform={}", userId, platform, exception);
        }
    }

    /**
     * {@inheritDoc}
     */
    @Override
    public Optional<UUID> find(UUID userId, String platform) {
        try {
            String sessionId = redis.opsForValue().get(key(userId, platform));
            return sessionId == null ? Optional.empty() : Optional.of(UUID.fromString(sessionId));
        } catch (RuntimeException exception) {
            log.warn("Redis 活动会话查询失败: userId={}, platform={}", userId, platform, exception);
            return Optional.empty();
        }
    }

    private String key(UUID userId, String platform) {
        return ACTIVE_PREFIX + userId + ":" + platform;
    }
}
