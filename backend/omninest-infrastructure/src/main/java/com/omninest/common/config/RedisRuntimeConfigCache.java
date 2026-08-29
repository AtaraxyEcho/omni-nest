package com.omninest.common.config;

import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.ScanOptions;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * 使用 Redis 保存运行时配置缓存。
 *
 * @author OmniNest
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RedisRuntimeConfigCache implements RuntimeConfigCache {

    private static final String KEY_PREFIX = "omninest:config:";
    private static final Duration TTL = Duration.ofMinutes(5);

    private final StringRedisTemplate redisTemplate;

    /**
     * {@inheritDoc}
     */
    @Override
    public Optional<String> get(String key) {
        try {
            String value = redisTemplate.opsForValue().get(KEY_PREFIX + key);
            return Optional.ofNullable(value);
        } catch (RuntimeException exception) {
            log.warn("读取配置缓存失败: key={}", key, exception);
            return Optional.empty();
        }
    }

    /**
     * {@inheritDoc}
     */
    @Override
    public void put(String key, String value) {
        try {
            redisTemplate.opsForValue().set(KEY_PREFIX + key, value, TTL);
        } catch (RuntimeException exception) {
            log.warn("写入配置缓存失败: key={}", key, exception);
        }
    }

    /**
     * {@inheritDoc}
     */
    @Override
    public void evict(String key) {
        try {
            redisTemplate.delete(KEY_PREFIX + key);
            log.debug("已清除配置缓存: key={}", key);
        } catch (RuntimeException exception) {
            log.warn("清除配置缓存失败: key={}", key, exception);
        }
    }

    /**
     * {@inheritDoc}
     */
    @Override
    public void evictAll() {
        try {
            ScanOptions options = ScanOptions.scanOptions()
                    .match(KEY_PREFIX + "*")
                    .count(100)
                    .build();
            List<String> keysToDelete = new ArrayList<>();
            try (var cursor = redisTemplate.scan(options)) {
                cursor.forEachRemaining(keysToDelete::add);
            }
            if (!keysToDelete.isEmpty()) {
                redisTemplate.delete(keysToDelete);
                log.info("已清除全部配置缓存: count={}", keysToDelete.size());
            }
        } catch (RuntimeException exception) {
            log.warn("清除全部配置缓存失败", exception);
        }
    }
}
