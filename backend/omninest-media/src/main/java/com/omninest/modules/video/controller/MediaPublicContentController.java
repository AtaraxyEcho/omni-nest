package com.omninest.modules.video.controller;

import com.omninest.modules.file.dto.FileContentResource;
import com.omninest.modules.file.dto.FileContentStream;
import com.omninest.modules.video.domain.MediaVideoItem;
import com.omninest.modules.video.service.MediaContentAccessService;
import com.omninest.modules.video.service.MoviePlaybackService;
import com.omninest.modules.video.service.VideoStreamService;
import io.swagger.v3.oas.annotations.Operation;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

/**
 * 使用用途受限媒体令牌提供原片 Range 读取和实时转码流。
 *
 * @author OmniNest
 */
@RestController
@RequiredArgsConstructor
public class MediaPublicContentController {

    private final MediaContentAccessService mediaContentAccessService;
    private final MoviePlaybackService moviePlaybackService;
    private final VideoStreamService videoStreamService;

    @Operation(summary = "读取媒体原片", description = "校验媒体级短期令牌并支持 HTTP Range")
    @GetMapping("/api/v1/public/video/items/{videoItemId}/content")
    ResponseEntity<Resource> content(
            @PathVariable UUID videoItemId,
            @RequestParam String token
    ) {
        FileContentResource content = mediaContentAccessService.openPlaybackContent(token, videoItemId);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(resolveMediaType(content.mimeType()));
        headers.setContentLength(content.sizeBytes());
        headers.set(HttpHeaders.ACCEPT_RANGES, "bytes");
        headers.setCacheControl(CacheControl.noStore());
        headers.setContentDisposition(ContentDisposition.inline()
                .filename(content.fileName(), StandardCharsets.UTF_8)
                .build());
        return ResponseEntity.ok().headers(headers).body(content.resource());
    }

    @Operation(summary = "读取媒体转码流", description = "校验媒体级短期令牌并输出浏览器兼容的 MP4 流")
    @GetMapping("/api/v1/public/video/items/{videoItemId}/stream")
    void stream(
            @PathVariable UUID videoItemId,
            @RequestParam String token,
            @RequestParam(defaultValue = "0") long start,
            @RequestParam(defaultValue = "cached") String audioMode,
            HttpServletResponse response
    ) throws IOException {
        MediaVideoItem item = mediaContentAccessService.requireTokenVideo(token, videoItemId);
        response.setContentType("video/mp4");
        response.setHeader(HttpHeaders.CACHE_CONTROL, "no-store");
        response.setHeader("Transfer-Encoding", "chunked");
        videoStreamService.streamByAudioMode(
                item.getOwnerUserId(),
                item.getId(),
                Math.max(0, start),
                audioMode,
                response.getOutputStream()
        );
    }

    @Operation(summary = "读取媒体字幕", description = "校验媒体级短期令牌并返回 UTF-8 字幕")
    @GetMapping("/api/v1/public/video/items/{videoItemId}/subtitles/{subtitleId}")
    void subtitle(
            @PathVariable UUID videoItemId,
            @PathVariable UUID subtitleId,
            @RequestParam String token,
            HttpServletResponse response
    ) throws IOException {
        String content = moviePlaybackService.getSubtitleContentByToken(token, videoItemId, subtitleId);
        response.setContentType("text/plain; charset=utf-8");
        response.setHeader(HttpHeaders.CACHE_CONTROL, "no-store");
        response.getWriter().write(content);
    }

    @Operation(summary = "读取影片派生资源", description = "校验影片令牌和资源归属后转发海报或背景图")
    @GetMapping("/api/v1/public/video/items/{videoItemId}/assets/{fileNodeId}")
    ResponseEntity<StreamingResponseBody> videoAsset(
            @PathVariable UUID videoItemId,
            @PathVariable UUID fileNodeId,
            @RequestParam String token
    ) {
        return streamAsset(mediaContentAccessService.openVideoAsset(token, videoItemId, fileNodeId));
    }

    @Operation(summary = "读取系列派生资源", description = "校验系列令牌和资源归属后转发海报或背景图")
    @GetMapping("/api/v1/public/video/series/{seriesId}/assets/{fileNodeId}")
    ResponseEntity<StreamingResponseBody> seriesAsset(
            @PathVariable UUID seriesId,
            @PathVariable UUID fileNodeId,
            @RequestParam String token
    ) {
        return streamAsset(mediaContentAccessService.openSeriesAsset(token, seriesId, fileNodeId));
    }

    private ResponseEntity<StreamingResponseBody> streamAsset(FileContentStream content) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(resolveMediaType(content.mimeType()));
        headers.setContentLength(content.sizeBytes());
        headers.setCacheControl(CacheControl.noStore());
        headers.setContentDisposition(ContentDisposition.inline()
                .filename(content.fileName(), StandardCharsets.UTF_8)
                .build());
        StreamingResponseBody body = outputStream -> {
            try (content) {
                content.inputStream().transferTo(outputStream);
            }
        };
        return ResponseEntity.ok().headers(headers).body(body);
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
