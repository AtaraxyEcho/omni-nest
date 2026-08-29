package com.omninest.common.security;

import java.util.List;

/**
 * 提供浏览器 Cookie 和跨域访问安全策略。
 *
 * @author OmniNest
 */
public interface BrowserSecurityPolicy {

    /**
     * 返回刷新令牌 Cookie 是否仅通过安全连接传输。
     *
     * @return 启用安全传输时返回 true
     */
    boolean refreshCookieSecure();

    /**
     * 返回允许建立浏览器连接的来源列表。
     *
     * @return 允许的来源列表
     */
    List<String> allowedOrigins();
}
