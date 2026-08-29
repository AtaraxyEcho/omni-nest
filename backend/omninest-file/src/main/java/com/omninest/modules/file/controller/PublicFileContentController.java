package com.omninest.modules.file.controller;

import com.omninest.modules.file.dto.FileContentResource;
import com.omninest.modules.file.service.FileContentAccessService;
import io.swagger.v3.oas.annotations.Operation;
import java.nio.charset.StandardCharsets;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.core.io.Resource;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

/**
 * 通过文件级短期令牌提供本地媒体 Range 内容。
 *
 * @author OmniNest
 */
@RestController
@RequiredArgsConstructor
public class PublicFileContentController {

    private final FileContentAccessService fileContentAccessService;

    @Operation(summary = "读取本地媒体内容", description = "校验文件级短期令牌并支持 HTTP Range")
    @GetMapping("/api/v1/public/file-content/{token}")
    ResponseEntity<Resource> content(@PathVariable String token) {
        FileContentResource content = fileContentAccessService.openPublicLocalResource(token);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(resolveMediaType(content.mimeType()));
        headers.setContentLength(content.sizeBytes());
        headers.set(HttpHeaders.ACCEPT_RANGES, "bytes");
        headers.setCacheControl("private, no-store");
        headers.setPragma("no-cache");
        headers.setContentDisposition(ContentDisposition.inline()
                .filename(content.fileName(), StandardCharsets.UTF_8)
                .build());
        return ResponseEntity.ok().headers(headers).body(content.resource());
    }

    private MediaType resolveMediaType(String mimeType) {
        if (mimeType == null || mimeType.isBlank()) {
            return MediaType.APPLICATION_OCTET_STREAM;
        }
        try {
            return MediaType.parseMediaType(mimeType);
        } catch (IllegalArgumentException e) {
            return MediaType.APPLICATION_OCTET_STREAM;
        }
    }
}
