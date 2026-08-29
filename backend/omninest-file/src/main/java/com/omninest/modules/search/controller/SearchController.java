package com.omninest.modules.search.controller;

import com.omninest.common.api.ApiResponse;
import com.omninest.common.security.CurrentUserContext;
import com.omninest.common.security.Permissions;
import com.omninest.modules.search.dto.SearchResultDto;
import com.omninest.modules.search.service.FileSearchIndexService;
import com.omninest.modules.search.service.FileSearchService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
@Tag(name = "搜索", description = "全文搜索接口")
public class SearchController {
    private final FileSearchService fileSearchService;
    private final FileSearchIndexService fileSearchIndexService;
    private final CurrentUserContext currentUserContext;

    @Operation(summary = "全文搜索", description = "根据关键词对当前用户的文件进行全文搜索")
    @GetMapping("/api/v1/search")
    @PreAuthorize("hasAuthority('" + Permissions.FILE_READ + "')")
    ApiResponse<List<SearchResultDto>> search(@RequestParam String q) {
        UUID ownerUserId = currentUserContext.requireCurrentUserId();
        return ApiResponse.success(fileSearchService.search(ownerUserId, q));
    }

    /**
     * 管理员触发全量索引重建：清空所有用户的 Lucene 索引，后续文件上传时自动重建。
     */
    @Operation(summary = "重建搜索索引", description = "管理员触发全量索引重建，清空所有用户的 Lucene 索引，文件将在后续上传或文本提取任务中自动重建")
    @PostMapping("/api/v1/search/rebuild")
    @PreAuthorize("hasAuthority('" + Permissions.SYSTEM_CONFIG_MANAGE + "')")
    ApiResponse<Map<String, Object>> rebuildIndex() {
        int cleared = fileSearchIndexService.clearAllIndexes();
        return ApiResponse.success(Map.of(
                "clearedDocuments", cleared,
                "message", "全部用户索引已清空，文件将在后续上传或文本提取任务中自动重建索引"
        ));
    }
}
