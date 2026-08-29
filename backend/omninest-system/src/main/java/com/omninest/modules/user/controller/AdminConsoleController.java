package com.omninest.modules.user.controller;

import com.omninest.common.api.ApiResponse;
import com.omninest.common.security.Permissions;
import com.omninest.modules.user.dto.AdminAnalyticsDto;
import com.omninest.modules.user.dto.AdminConsoleSummaryDto;
import com.omninest.modules.user.service.AdminConsoleService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "管理控制台", description = "管理控制台概览数据")
@RestController
@RequiredArgsConstructor
public class AdminConsoleController {
    private final AdminConsoleService adminConsoleService;

    @Operation(summary = "获取管理控制台概览数据")
    @GetMapping("/api/v1/admin/summary")
    @PreAuthorize("hasAnyAuthority('" + Permissions.SYSTEM_USER_READ + "','" + Permissions.SYSTEM_CONFIG_READ + "')")
    ApiResponse<AdminConsoleSummaryDto> summary() {
        return ApiResponse.success(adminConsoleService.summary());
    }

    @Operation(summary = "获取系统分析统计")
    @GetMapping("/api/v1/admin/analytics")
    @PreAuthorize("hasAnyAuthority('" + Permissions.SYSTEM_USER_READ + "','" + Permissions.SYSTEM_CONFIG_READ + "')")
    ApiResponse<AdminAnalyticsDto> analytics(@RequestParam(defaultValue = "7") int days) {
        return ApiResponse.success(adminConsoleService.analytics(Math.min(Math.max(days, 1), 90)));
    }

    @Operation(summary = "获取角色统计概览")
    @GetMapping("/api/v1/admin/roles")
    @PreAuthorize("hasAuthority('" + Permissions.SYSTEM_USER_READ + "')")
    ApiResponse<List<AdminConsoleSummaryDto.RoleSummary>> roles() {
        return ApiResponse.success(adminConsoleService.roles());
    }

    @Operation(summary = "重新计算用户存储用量")
    @PostMapping("/api/v1/admin/storage/recalculate")
    @PreAuthorize("hasAuthority('" + Permissions.SYSTEM_CONFIG_MANAGE + "')")
    ApiResponse<Integer> recalculateStorage() {
        int updated = adminConsoleService.recalculateStorageUsage();
        return ApiResponse.success(updated);
    }
}
