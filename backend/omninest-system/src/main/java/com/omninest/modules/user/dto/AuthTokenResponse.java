package com.omninest.modules.user.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "认证令牌响应")
@JsonInclude(JsonInclude.Include.NON_NULL)
public record AuthTokenResponse(
        @Schema(description = "令牌类型", example = "Bearer") String tokenType,
        @Schema(description = "访问令牌", example = "eyJhbGciOiJIUzI1NiJ9...") String accessToken,
        @Schema(description = "访问令牌过期时间", example = "2026-06-07T12:00:00Z") String expiresAt,
        @Schema(description = "刷新令牌", example = "eyJhbGciOiJIUzI1NiJ9...") String refreshToken,
        @Schema(description = "刷新令牌过期时间", example = "2026-06-14T12:00:00Z") String refreshExpiresAt,
        @Schema(description = "当前用户信息") AuthUserDto user
) {
    /**
     * 创建不包含刷新凭证的浏览器响应。
     *
     * @return 浏览器认证响应
     */
    public AuthTokenResponse withoutRefreshToken() {
        return new AuthTokenResponse(
                tokenType,
                accessToken,
                expiresAt,
                null,
                refreshExpiresAt,
                user
        );
    }
}
