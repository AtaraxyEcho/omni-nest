package com.omninest.modules.user.controller;

import com.omninest.common.api.ApiResponse;
import com.omninest.common.api.PageResponse;
import com.omninest.common.security.Permissions;
import com.omninest.modules.user.dto.AdminOperationsDto;
import com.omninest.modules.user.dto.AdminCreateUserRequest;
import com.omninest.modules.user.dto.AdminUpdateUserStatusRequest;
import com.omninest.modules.user.dto.AuthUserDto;
import com.omninest.modules.user.service.AdminUserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "用户管理", description = "管理员对用户的增删改查操作")
@RestController
@RequiredArgsConstructor
public class AdminUserController {
    private final AdminUserService adminUserService;

    @Operation(summary = "分页查询用户列表")
    @GetMapping("/api/v1/admin/users")
    @PreAuthorize("hasAuthority('" + Permissions.SYSTEM_USER_READ + "')")
    ApiResponse<PageResponse<AuthUserDto>> listUsers(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size
    ) {
        var result = adminUserService.listUsers(page, size);
        return ApiResponse.success(PageResponse.of(
                result.getContent(), result.getNumber(), result.getSize(), result.getTotalElements()));
    }

    @Operation(summary = "创建新用户")
    @PostMapping("/api/v1/admin/users")
    @PreAuthorize("hasAuthority('" + Permissions.SYSTEM_USER_MANAGE + "')")
    ApiResponse<AuthUserDto> createUser(@Valid @RequestBody AdminCreateUserRequest request) {
        return ApiResponse.success(adminUserService.createUser(request));
    }

    @Operation(summary = "更新用户状态（启用/禁用）")
    @PatchMapping("/api/v1/admin/users/{userId}/status")
    @PreAuthorize("hasAuthority('" + Permissions.SYSTEM_USER_MANAGE + "')")
    ApiResponse<AuthUserDto> updateUserStatus(
            @PathVariable UUID userId,
            @Valid @RequestBody AdminUpdateUserStatusRequest request
    ) {
        return ApiResponse.success(adminUserService.updateUserStatus(userId, request.status()));
    }

    @Operation(summary = "更新用户角色")
    @PatchMapping("/api/v1/admin/users/{userId}/roles")
    @PreAuthorize("hasAuthority('" + Permissions.SYSTEM_USER_MANAGE + "')")
    ApiResponse<AuthUserDto> updateUserRoles(
            @PathVariable UUID userId,
            @Valid @RequestBody AdminOperationsDto.UpdateUserRolesRequest request
    ) {
        return ApiResponse.success(adminUserService.updateUserRoles(userId, request.roles()));
    }
}
