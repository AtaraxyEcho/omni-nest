package com.omninest.modules.file.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.Instant;
import java.util.UUID;

@Schema(description = "离线下载任务信息")
public record OfflineDownloadTaskDto(
        @Schema(description = "任务 ID") UUID id,
        @Schema(description = "下载源 URI") String sourceUri,
        @Schema(description = "目标文件夹 ID") UUID targetParentId,
        @Schema(description = "关联任务记录 ID") UUID taskId,
        @Schema(description = "任务状态", example = "COMPLETED") String status,
        @Schema(description = "Aria2 GID") String aria2Gid,
        @Schema(description = "文件名", example = "file.zip") String fileName,
        @Schema(description = "文件总大小（字节）", example = "104857600") long totalBytes,
        @Schema(description = "已下载大小（字节）", example = "104857600") long completedBytes,
        @Schema(description = "下载速度（字节/秒）", example = "1048576") long downloadSpeedBytes,
        @Schema(description = "错误摘要") String errorSummary,
        @Schema(description = "完成后生成的文件 ID") UUID completedFileId,
        @Schema(description = "完成时间") Instant completedAt,
        @Schema(description = "创建时间") Instant createdAt,
        @Schema(description = "更新时间") Instant updatedAt
) {
}
