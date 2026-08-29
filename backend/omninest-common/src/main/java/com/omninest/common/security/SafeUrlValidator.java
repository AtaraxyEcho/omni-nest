package com.omninest.common.security;

import java.net.URI;

/**
 * 校验外部 URL 是否满足服务端请求安全约束。
 *
 * @author OmniNest
 */
public interface SafeUrlValidator {

    /**
     * 校验 URI 的主机名及其解析地址是否允许访问。
     *
     * @param uri 待校验的 URI
     */
    void requireSafeHost(URI uri);

    /**
     * 校验 HTTP 或 HTTPS URL 是否允许访问。
     *
     * @param url 待校验的 URL
     */
    void requireSafeHttpUrl(String url);
}
