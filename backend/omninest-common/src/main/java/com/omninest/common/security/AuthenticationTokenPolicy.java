package com.omninest.common.security;

import java.time.Duration;

/**
 * 提供认证访问令牌和刷新令牌的有效期策略。
 *
 * @author OmniNest
 */
public interface AuthenticationTokenPolicy {

    /**
     * 返回访问令牌有效期。
     *
     * @return 访问令牌有效期
     */
    Duration accessTokenTtl();

    /**
     * 返回刷新令牌有效期。
     *
     * @return 刷新令牌有效期
     */
    Duration refreshTokenTtl();
}
