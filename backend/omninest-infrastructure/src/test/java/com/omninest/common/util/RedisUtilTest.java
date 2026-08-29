package com.omninest.common.util;

import org.mockito.ArgumentMatchers;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Duration;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.data.redis.core.script.DefaultRedisScript;

/**
 * Redis 通用操作和缓存契约测试。
 *
 * @author OmniNest
 */
@SuppressWarnings("unchecked")
class RedisUtilTest {

    private final StringRedisTemplate redisTemplate = mock(StringRedisTemplate.class);
    private final ValueOperations<String, String> valueOperations = mock(ValueOperations.class);
    private final RedisUtil redisUtil = new RedisUtil(redisTemplate);

    @Test
    void setWithTtlDelegatesToRedisTemplate() {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        Duration ttl = Duration.ofMinutes(5);

        redisUtil.set("config:test", "enabled", ttl);

        verify(valueOperations).set("config:test", "enabled", ttl);
    }

    @Test
    void invalidateDeletesCacheKey() {
        when(redisTemplate.delete("cache:file:1")).thenReturn(Boolean.TRUE);

        boolean invalidated = redisUtil.invalidate("cache:file:1");

        assertThat(invalidated).isTrue();
        verify(redisTemplate).delete("cache:file:1");
    }

    @Test
    void expiringOwnershipRegistryStoresAndReadsOwner() {
        UUID ownerUserId = UUID.fromString("10000000-0000-0000-0000-000000000001");
        Duration ttl = Duration.ofMinutes(5);
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.get("login:session-1")).thenReturn(ownerUserId.toString());

        redisUtil.register("login:session-1", ownerUserId, ttl);
        Optional<UUID> storedOwner = redisUtil.findOwner("login:session-1");

        verify(valueOperations).set("login:session-1", ownerUserId.toString(), ttl);
        assertThat(storedOwner).contains(ownerUserId);
    }

    @Test
    void expiringOwnershipRegistryRemovesOwner() {
        when(redisTemplate.delete("login:session-1")).thenReturn(Boolean.TRUE);

        redisUtil.remove("login:session-1");

        verify(redisTemplate).delete("login:session-1");
    }

    @Test
    void tryLockUsesSetIfAbsentWithTtl() {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.setIfAbsent("lock:file:1", "token-1", Duration.ofSeconds(30))).thenReturn(Boolean.TRUE);

        boolean locked = redisUtil.tryLock("lock:file:1", "token-1", Duration.ofSeconds(30));

        assertThat(locked).isTrue();
    }

    @Test
    void unlockUsesLuaCompareAndDeleteScript() {
        when(redisTemplate.execute(
                ArgumentMatchers.<DefaultRedisScript<Long>>any(),
                eq(List.of("lock:file:1")),
                eq("token-1")
        )).thenReturn(1L);
        ArgumentCaptor<DefaultRedisScript<Long>> scriptCaptor = ArgumentCaptor.forClass(DefaultRedisScript.class);

        boolean unlocked = redisUtil.unlock("lock:file:1", "token-1");

        assertThat(unlocked).isTrue();
        verify(redisTemplate).execute(scriptCaptor.capture(), eq(List.of("lock:file:1")), eq("token-1"));
        assertThat(scriptCaptor.getValue().getScriptAsString())
                .contains("redis.call('get', KEYS[1])")
                .contains("redis.call('del', KEYS[1])");
    }
}
