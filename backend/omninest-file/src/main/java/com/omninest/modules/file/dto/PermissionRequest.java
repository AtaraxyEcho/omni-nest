package com.omninest.modules.file.dto;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "文件权限设置请求")
public record PermissionRequest(
        @Schema(description = "允许下载", example = "true") boolean allowDownload,
        @Schema(description = "允许分享", example = "false") boolean allowShare,
        @Schema(description = "允许编辑", example = "false") boolean allowEdit
) {
}
