package com.omninest.common.security;

import java.util.Set;
import java.util.UUID;

/**
 * 当前认证用户信息。
 *
 * @param userId 用户标识
 * @param subject JWT 主题
 * @param username 用户名
 * @param permissions 权限编码集合
 * @param roles 角色编码集合
 * @author OmniNest
 */
public record CurrentUser(
        UUID userId,
        String subject,
        String username,
        Set<String> permissions,
        Set<String> roles
) {
    /**
     * 判断当前用户是否具有管理员角色。
     *
     * @return 具有管理员角色时返回 true
     */
    public boolean isAdmin() {
        return roles != null && roles.contains("ADMIN");
    }
}
