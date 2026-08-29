package com.omninest.modules.file.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.UUID;

/**
 * 分享链接预览信息。
 */
@Schema(description = "分享链接预览信息")
public record FileSharePreviewDto(
        @Schema(description = "分享链接 ID") UUID shareId,
        @Schema(description = "文件名", example = "文档.pdf") String fileName,
        @Schema(description = "MIME 类型", example = "application/pdf") String mimeType,
        @Schema(description = "文件大小（字节）", example = "1048576") long sizeBytes,
        @Schema(description = "资源类型", example = "FILE") String resourceType,
        @Schema(description = "是否需要密码", example = "false") boolean hasPassword
) {
}
