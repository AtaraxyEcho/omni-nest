package com.omninest.common.security;

import java.time.Duration;
import java.util.List;
import java.util.UUID;
import org.assertj.core.api.Assertions;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.data.redis.core.SetOperations;
import org.springframework.data.redis.core.StringRedisTemplate;

/**
 * Redis 会话撤销缓存适配器测试。
 *
 * @author OmniNest
 */
class RedisSessionRevocationCacheTest {

    private StringRedisTemplate redis;
    private SetOperations<String, String> setOperations;
    private RedisSessionRevocationCache cache;

    @SuppressWarnings("unchecked")
    @BeforeEach
    void setUp() {
        redis = Mockito.mock(StringRedisTemplate.class);
        setOperations = Mockito.mock(SetOperations.class);
        Mockito.when(redis.opsForSet()).thenReturn(setOperations);
        cache = new RedisSessionRevocationCache(redis);
    }

    @Test
    void markRevokedWritesOneRedisBatch() {
        UUID userId = UUID.randomUUID();
        UUID firstSessionId = UUID.randomUUID();
        UUID secondSessionId = UUID.randomUUID();

        cache.markRevoked(
                userId,
                List.of(firstSessionId, secondSessionId),
                Duration.ofDays(30)
        );

        Mockito.verify(setOperations).add(
                "session:blacklist:" + userId,
                firstSessionId.toString(),
                secondSessionId.toString()
        );
        Mockito.verify(redis).expire("session:blacklist:" + userId, Duration.ofDays(30));
    }

    @Test
    void containsReturnsCachedResult() {
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();
        Mockito.when(setOperations.isMember(
                "session:blacklist:" + userId,
                sessionId.toString()
        )).thenReturn(Boolean.TRUE);

        boolean result = cache.contains(userId, sessionId);

        Assertions.assertThat(result).isTrue();
    }

    @Test
    void containsTreatsRedisFailureAsCacheMiss() {
        Mockito.when(redis.opsForSet()).thenThrow(new IllegalStateException("Redis unavailable"));

        boolean result = cache.contains(UUID.randomUUID(), UUID.randomUUID());

        Assertions.assertThat(result).isFalse();
    }
}
