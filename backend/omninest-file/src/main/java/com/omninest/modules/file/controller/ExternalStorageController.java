package com.omninest.modules.file.controller;

import com.omninest.common.api.ApiResponse;
import com.omninest.common.api.PageResponse;
import com.omninest.common.security.CurrentUserContext;
import com.omninest.common.security.Permissions;
import com.omninest.modules.file.dto.CreateImportTaskRequest;
import com.omninest.modules.file.dto.ExternalFileListDto;
import com.omninest.modules.file.dto.ExternalSpaceDto;
import com.omninest.modules.file.dto.ImportTaskDto;
import com.omninest.modules.file.dto.RenameRemoteFileRequest;
import com.omninest.modules.file.dto.RemotePathRequest;
import com.omninest.modules.file.service.ExternalStorageService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 外部存储 API。
 * <p>
 * 提供外部存储浏览、文件操作和导入任务管理功能。
 *
 * @author OmniNest
 */
@RestController
@RequiredArgsConstructor
@PreAuthorize("hasAuthority('" + Permissions.SYSTEM_CONFIG_MANAGE + "')")
@Tag(name = "外部存储", description = "外部存储源的管理与操作")
public class ExternalStorageController {
    private final ExternalStorageService externalStorageService;
    private final CurrentUserContext currentUserContext;

    // ========== 浏览 ==========

    @Operation(summary = "浏览外部存储", description = "浏览指定外部存储账户中的文件和目录")
    @GetMapping("/api/v1/external-storages/{accountId}/browse")
    ApiResponse<ExternalFileListDto> browse(
            @PathVariable UUID accountId,
            @RequestParam(required = false, defaultValue = "/") String path
    ) {
        UUID ownerUserId = currentUserContext.requireCurrentUserId();
        return ApiResponse.success(externalStorageService.browse(ownerUserId, accountId, path));
    }

    @Operation(summary = "获取空间使用情况", description = "查询指定外部存储账户的空间使用量和配额")
    @GetMapping("/api/v1/external-storages/{accountId}/space")
    ApiResponse<ExternalSpaceDto> getSpaceUsage(@PathVariable UUID accountId) {
        UUID ownerUserId = currentUserContext.requireCurrentUserId();
        return ApiResponse.success(externalStorageService.getSpaceUsage(ownerUserId, accountId));
    }

    @Operation(summary = "获取文件系统信息", description = "获取指定外部存储账户的文件系统元信息")
    @GetMapping("/api/v1/external-storages/{accountId}/info")
    ApiResponse<Map<String, Object>> getFsInfo(@PathVariable UUID accountId) {
        UUID ownerUserId = currentUserContext.requireCurrentUserId();
        return ApiResponse.success(externalStorageService.getFsInfo(ownerUserId, accountId));
    }

    // ========== 文件操作 ==========

    @Operation(summary = "创建远程目录", description = "在外部存储中创建新目录")
    @PostMapping("/api/v1/external-storages/{accountId}/mkdir")
    ApiResponse<Void> mkdir(
            @PathVariable UUID accountId,
            @Valid @RequestBody RemotePathRequest body
    ) {
        UUID ownerUserId = currentUserContext.requireCurrentUserId();
        externalStorageService.mkdir(ownerUserId, accountId, body.remotePath());
        return ApiResponse.success();
    }

    @Operation(summary = "删除远程文件", description = "删除外部存储中的指定文件或目录")
    @DeleteMapping("/api/v1/external-storages/{accountId}/files")
    ApiResponse<Void> deleteRemoteFile(
            @PathVariable UUID accountId,
            @Valid @RequestBody RemotePathRequest body
    ) {
        UUID ownerUserId = currentUserContext.requireCurrentUserId();
        externalStorageService.deleteRemoteFile(ownerUserId, accountId, body.remotePath());
        return ApiResponse.success();
    }

    @Operation(summary = "重命名远程文件", description = "重命名外部存储中的指定文件或目录")
    @PostMapping("/api/v1/external-storages/{accountId}/rename")
    ApiResponse<Void> renameRemoteFile(
            @PathVariable UUID accountId,
            @Valid @RequestBody RenameRemoteFileRequest body
    ) {
        UUID ownerUserId = currentUserContext.requireCurrentUserId();
        externalStorageService.renameRemoteFile(ownerUserId, accountId, body.oldPath(), body.newName());
        return ApiResponse.success();
    }

    // ========== 导入任务 ==========

    @Operation(summary = "创建导入任务", description = "从外部存储导入文件到本地存储")
    @PostMapping("/api/v1/external-storages/{accountId}/import")
    ApiResponse<ImportTaskDto> createImportTask(
            @PathVariable UUID accountId,
            @Valid @RequestBody CreateImportTaskRequest body
    ) {
        UUID ownerUserId = currentUserContext.requireCurrentUserId();
        return ApiResponse.success(externalStorageService.createImportTask(ownerUserId, accountId, body));
    }

    @Operation(summary = "列出导入任务", description = "列出当前用户的所有导入任务")
    @GetMapping("/api/v1/external-storages/import-tasks")
    ApiResponse<PageResponse<ImportTaskDto>> listImportTasks() {
        UUID ownerUserId = currentUserContext.requireCurrentUserId();
        List<ImportTaskDto> items = externalStorageService.listImportTasks(ownerUserId);
        return ApiResponse.success(PageResponse.of(items, 0, 50, items.size()));
    }

    @Operation(summary = "取消导入任务", description = "取消指定的导入任务")
    @DeleteMapping("/api/v1/external-storages/import-tasks/{taskId}")
    ApiResponse<Void> cancelImportTask(@PathVariable UUID taskId) {
        UUID ownerUserId = currentUserContext.requireCurrentUserId();
        externalStorageService.cancelImportTask(ownerUserId, taskId);
        return ApiResponse.success();
    }
}
