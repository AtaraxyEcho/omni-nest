package com.omninest.modules.file.service;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import org.springframework.stereotype.Service;

/**
 * 保存已完成分享密码校验的短期、用途受限会话。
 *
 * <p>会话不落库，也不包含密码；重启服务或自然过期都会使其失效。
 *
 * @author OmniNest
 */
@Service
public class ShareAccessSessionService {
    private static final Duration MAX_TTL = Duration.ofMinutes(10);
    private static final int TOKEN_BYTES = 32;

    private final SecureRandom secureRandom = new SecureRandom();
    private final Cache<String, ShareSession> sessions = Caffeine.newBuilder()
            .maximumSize(20_000)
            .expireAfterWrite(MAX_TTL)
            .build();

    /** 签发绑定分享令牌和资源类型的短期会话。 */
    public IssuedSession issue(String tokenHash, String resourceType, Instant linkExpiresAt) {
        Instant now = Instant.now();
        if (linkExpiresAt != null && !linkExpiresAt.isAfter(now)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "分享链接已过期");
        }
        Instant expiresAt = now.plus(MAX_TTL);
        if (linkExpiresAt != null && linkExpiresAt.isBefore(expiresAt)) {
            expiresAt = linkExpiresAt;
        }
        byte[] random = new byte[TOKEN_BYTES];
        secureRandom.nextBytes(random);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(random);
        sessions.put(token, new ShareSession(tokenHash, resourceType, expiresAt));
        return new IssuedSession(token, expiresAt);
    }

    /** 校验会话与原始分享令牌、资源类型完全绑定。 */
    public void require(String sessionToken, String tokenHash, String resourceType) {
        ShareSession session = sessionToken == null ? null : sessions.getIfPresent(sessionToken);
        if (session == null
                || session.expiresAt().isBefore(Instant.now())
                || !session.tokenHash().equals(tokenHash)
                || !session.resourceType().equals(resourceType)) {
            if (sessionToken != null) {
                sessions.invalidate(sessionToken);
            }
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "分享会话无效或已过期");
        }
    }

    public record IssuedSession(String token, Instant expiresAt) {
    }

    private record ShareSession(String tokenHash, String resourceType, Instant expiresAt) {
    }
}
