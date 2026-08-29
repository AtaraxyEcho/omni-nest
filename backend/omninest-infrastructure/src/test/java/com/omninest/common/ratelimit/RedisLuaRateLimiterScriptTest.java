package com.omninest.common.ratelimit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;

class RedisLuaRateLimiterScriptTest {

    @Test
    void scriptUsesAtomicRedisIncrementWithExpiry() {
        assertThat(RedisLuaRateLimiter.FIXED_WINDOW_SCRIPT)
                .contains("INCR")
                .contains("PEXPIRE")
                .contains("return 0")
                .contains("return 1");
    }

    @Test
    void nullScriptResultIsRejectedAsDependencyUnavailable() {
        StringRedisTemplate redisTemplate = mock(StringRedisTemplate.class);
        RateLimitProperties properties = new RateLimitProperties(true, 120, null, "omninest:rate-limit");
        RedisLuaRateLimiter limiter = new RedisLuaRateLimiter(redisTemplate, properties);

        assertThatThrownBy(() -> limiter.tryAcquire("login", 10, Duration.ofMinutes(1)))
                .isInstanceOfSatisfying(BusinessException.class, exception ->
                        assertThat(exception.errorCode()).isEqualTo(ErrorCode.DEPENDENCY_UNAVAILABLE));
    }
}
