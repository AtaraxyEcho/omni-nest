package com.omninest.modules.music.service;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.common.security.ExpiringOwnershipRegistry;
import com.omninest.modules.music.service.platform.MusicPlatform;
import java.time.Duration;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * 管理绑定用户的平台登录会话。
 *
 * @author OmniNest
 */
@Service
@RequiredArgsConstructor
public class MusicPlatformLoginSessionService {
    private static final Duration LOGIN_SESSION_TTL = Duration.ofMinutes(5);
    private static final String KEY_PREFIX = "omninest:integration:music:login:";

    private final ExpiringOwnershipRegistry ownershipRegistry;

    /**
     * 登记用户的平台登录会话。
     *
     * @param ownerUserId 所属用户 ID
     * @param platform 平台
     * @param sessionId 平台登录会话 ID
     */
    public void register(UUID ownerUserId, MusicPlatform platform, String sessionId) {
        ownershipRegistry.register(key(platform, sessionId), ownerUserId, LOGIN_SESSION_TTL);
    }

    /**
     * 校验登录会话归属。
     *
     * @param ownerUserId 当前用户 ID
     * @param platform 平台
     * @param sessionId 平台登录会话 ID
     * @throws BusinessException 会话不存在或不属于当前用户时抛出
     */
    public void requireOwner(UUID ownerUserId, MusicPlatform platform, String sessionId) {
        UUID storedOwner = ownershipRegistry.findOwner(key(platform, sessionId)).orElse(null);
        if (storedOwner == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "平台登录会话不存在或已过期");
        }
        if (!ownerUserId.equals(storedOwner)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "无权访问该平台登录会话");
        }
    }

    /**
     * 结束登录会话。
     *
     * @param platform 平台
     * @param sessionId 平台登录会话 ID
     */
    public void complete(MusicPlatform platform, String sessionId) {
        ownershipRegistry.remove(key(platform, sessionId));
    }

    private String key(MusicPlatform platform, String sessionId) {
        return KEY_PREFIX + platform.apiValue() + ":" + sessionId;
    }
}
