package com.omninest.modules.file.dto;

import io.swagger.v3.oas.annotations.media.Schema;

/** 分享密码校验请求，密码只允许出现在 POST 请求体。 */
@Schema(description = "分享密码校验请求")
public record ShareAuthorizationRequest(
        @Schema(description = "分享密码；无密码分享可为空") String password
) {
}
