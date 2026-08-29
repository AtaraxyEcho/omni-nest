package com.omninest.common.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

/**
 * 启动时校验 JWT secret 的基本强度，并提示替换兼容默认值。
 *
 * @author OmniNest
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class JwtSecretValidator implements ApplicationRunner {

    private static final String DEFAULT_SECRET = "change-me-omninest-local-jwt-secret-at-least-32-bytes";

    private final SecurityProperties securityProperties;

    @Override
    public void run(ApplicationArguments args) {
        validate();
    }

    void validate() {
        String secret = securityProperties.getJwtSecret();
        if (secret == null || secret.isBlank() || secret.length() < 32) {
            throw new IllegalStateException("JWT secret 不能为空且长度不能少于 32 个字符");
        }
        if (secret.equals(DEFAULT_SECRET)) {
            log.warn("JWT secret 正在使用兼容默认值，公开部署前必须通过环境变量替换");
        }
    }
}
