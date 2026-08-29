package com.omninest.modules.video.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import tools.jackson.databind.ObjectMapper;
import com.omninest.common.security.SafeUrlValidator;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

/**
 * 字幕自动下载服务测试。
 *
 * @author OmniNest
 */
class SubtitleAutoDownloadServiceTest {

    private final MediaRuntimeConfigService configService = Mockito.mock(MediaRuntimeConfigService.class);
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final SafeUrlValidator safeUrlValidator = Mockito.mock(SafeUrlValidator.class);
    private final SubtitleAutoDownloadService service = new SubtitleAutoDownloadService(
            configService,
            objectMapper,
            safeUrlValidator
    );

    @Test
    @DisplayName("API Key 未配置时搜索返回空列表")
    void searchSubtitles_returnsEmptyWhenApiKeyNotConfigured() {
        when(configService.opensubtitlesApiKey()).thenReturn("");
        List<SubtitleAutoDownloadService.SubtitleCandidate> result = service.searchSubtitles("tt1375666", "zh");
        assertThat(result).isEmpty();
    }

    @Test
    @DisplayName("API Key 为 null 时搜索返回空列表")
    void searchSubtitles_returnsEmptyWhenApiKeyIsNull() {
        when(configService.opensubtitlesApiKey()).thenReturn(null);
        List<SubtitleAutoDownloadService.SubtitleCandidate> result = service.searchSubtitles("tt1375666", "zh");
        assertThat(result).isEmpty();
    }

    @Test
    @DisplayName("API Key 未配置时下载返回空数组")
    void downloadSubtitle_returnsEmptyWhenApiKeyNotConfigured() {
        when(configService.opensubtitlesApiKey()).thenReturn(null);
        byte[] result = service.downloadSubtitle("12345");
        assertThat(result).isEmpty();
    }

    @Test
    @DisplayName("API Key 为空字符串时下载返回空数组")
    void downloadSubtitle_returnsEmptyWhenApiKeyIsBlank() {
        when(configService.opensubtitlesApiKey()).thenReturn("   ");
        byte[] result = service.downloadSubtitle("12345");
        assertThat(result).isEmpty();
    }
}
