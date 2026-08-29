package com.omninest.modules.video.service;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import com.omninest.common.security.SafeUrlValidator;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 字幕自动下载服务。
 * 通过 OpenSubtitles API 搜索和下载匹配字幕。
 *
 * @author OmniNest
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SubtitleAutoDownloadService {

    private final MediaRuntimeConfigService configService;
    private final ObjectMapper objectMapper;
    private final SafeUrlValidator safeUrlValidator;

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    /**
     * 搜索匹配的字幕。
     *
     * @param imdbId   IMDb ID（如 "tt1375666"）
     * @param language 语言代码（如 "zh", "en"）
     * @return 匹配的字幕候选列表
     */
    public List<SubtitleCandidate> searchSubtitles(String imdbId, String language) {
        String apiKey = configService.opensubtitlesApiKey();
        if (apiKey == null || apiKey.isBlank()) {
            log.debug("OpenSubtitles API Key 未配置，跳过字幕搜索");
            return List.of();
        }

        try {
            String url = "https://api.opensubtitles.com/api/v1/subtitles?" +
                    "imdb_id=" + imdbId + "&languages=" + language;

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .header("Api-Key", apiKey)
                    .header("User-Agent", "OmniNest/1.0")
                    .GET()
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                log.warn("OpenSubtitles 搜索失败: status={}", response.statusCode());
                return List.of();
            }

            return parseSearchResponse(response.body());
        } catch (Exception ex) {
            log.warn("字幕搜索异常: imdbId={}", imdbId, ex);
            return List.of();
        }
    }

    /**
     * 下载字幕文件内容。
     *
     * @param fileId 字幕文件 ID
     * @return 字幕文件内容（SRT/VTT 格式），失败时返回空数组
     */
    public byte[] downloadSubtitle(String fileId) {
        String apiKey = configService.opensubtitlesApiKey();
        if (apiKey == null || apiKey.isBlank()) {
            log.debug("OpenSubtitles API Key 未配置，跳过字幕下载");
            return new byte[0];
        }

        try {
            String url = "https://api.opensubtitles.com/api/v1/download";

            String body = "{\"file_id\": " + fileId + "}";
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .header("Api-Key", apiKey)
                    .header("Content-Type", "application/json")
                    .header("User-Agent", "OmniNest/1.0")
                    .POST(HttpRequest.BodyPublishers.ofString(body))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                log.warn("字幕下载请求失败: status={}", response.statusCode());
                return new byte[0];
            }

            // 解析下载链接并获取内容
            String downloadLink = parseDownloadLink(response.body());
            if (downloadLink == null || downloadLink.isBlank()) {
                log.warn("字幕下载链接解析失败");
                return new byte[0];
            }

            safeUrlValidator.requireSafeHttpUrl(downloadLink);

            HttpRequest downloadRequest = HttpRequest.newBuilder()
                    .uri(URI.create(downloadLink))
                    .GET()
                    .build();

            HttpResponse<byte[]> downloadResponse = httpClient.send(downloadRequest, HttpResponse.BodyHandlers.ofByteArray());
            return downloadResponse.body();
        } catch (Exception ex) {
            log.warn("字幕下载异常: fileId={}", fileId, ex);
            return new byte[0];
        }
    }

    /**
     * 解析 OpenSubtitles 搜索响应，提取字幕候选列表。
     *
     * @param json API 响应 JSON
     * @return 字幕候选列表
     */
    private List<SubtitleCandidate> parseSearchResponse(String json) {
        List<SubtitleCandidate> candidates = new ArrayList<>();
        try {
            JsonNode root = objectMapper.readTree(json);
            JsonNode data = root.path("data");
            if (!data.isArray()) {
                return candidates;
            }
            for (JsonNode item : data) {
                JsonNode attributes = item.path("attributes");
                String language = attributes.path("language").asString("");
                String fileName = attributes.path("files").path(0).path("file_name").asString("");
                String fileId = attributes.path("files").path(0).path("file_id").asString("");
                long downloadCount = attributes.path("download_count").asLong(0);
                float rating = attributes.path("ratings").floatValue();

                if (!fileId.isBlank()) {
                    candidates.add(new SubtitleCandidate(fileId, language, fileName, downloadCount, rating));
                }
            }
        } catch (Exception ex) {
            log.warn("解析字幕搜索响应失败", ex);
        }
        return candidates;
    }

    /**
     * 从下载响应中提取下载链接。
     *
     * @param json API 响应 JSON
     * @return 下载链接，解析失败时返回 null
     */
    private String parseDownloadLink(String json) {
        try {
            JsonNode root = objectMapper.readTree(json);
            return root.path("link").asString(null);
        } catch (Exception ex) {
            log.warn("解析字幕下载链接失败", ex);
            return null;
        }
    }

    /**
     * 字幕候选记录。
     *
     * @param fileId        文件 ID
     * @param language      语言代码
     * @param fileName      文件名
     * @param downloadCount 下载次数
     * @param rating        评分
     */
    public record SubtitleCandidate(
            String fileId,
            String language,
            String fileName,
            long downloadCount,
            float rating
    ) {}
}
