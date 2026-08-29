package com.omninest.modules.file.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Schema(description = "创建分享链接请求")
public record CreateShareLinkRequest(
        @Schema(description = "资源 ID", example = "550e8400-e29b-41d4-a716-446655440000") @NotNull UUID resourceId,
        @Schema(description = "资源类型", example = "FILE", allowableValues = {"FILE", "FOLDER"}) String resourceType,
        @Schema(description = "自定义访问密码") String password,
        @Schema(description = "是否自动生成密码", example = "false") boolean generatePassword,
        @Schema(description = "过期时间") Instant expiresAt,
        @Schema(description = "最大访问次数", example = "100") Integer maxAccessCount,
        @Schema(description = "指定接收用户 ID 列表") List<UUID> recipientUserIds
) {
}
