package com.omninest.common.ratelimit;

import java.time.Duration;

/**
 * 提供固定时间窗口的请求限流能力。
 *
 * @author OmniNest
 */
public interface RateLimitService {

    /**
     * 尝试获取指定窗口内的请求许可。
     *
     * @param key 限流键
     * @param limit 窗口内允许的请求数量
     * @param window 时间窗口
     * @return 允许请求时返回 true
     */
    boolean tryAcquire(String key, int limit, Duration window);
}
