package com.omninest.common.security;

import java.util.UUID;

/**
 * 当前认证用户访问端口。
 *
 * @author OmniNest
 */
public interface CurrentUserContext {

    /**
     * 获取当前已认证用户。
     *
     * @return 当前认证用户信息
     */
    CurrentUser requireCurrentUser();

    /**
     * 获取当前已认证用户标识。
     *
     * @return 当前用户标识
     */
    UUID requireCurrentUserId();
}
