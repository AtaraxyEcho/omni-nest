package com.omninest.modules.file.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

/**
 * 外部存储目录列表响应。
 */
@Schema(description = "外部存储目录列表响应")
public record ExternalFileListDto(
        @Schema(description = "文件/目录列表") List<ExternalFileItemDto> items,
        @Schema(description = "当前远程路径", example = "/photos") String remotePath
) {
}
