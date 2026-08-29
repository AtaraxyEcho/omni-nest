package com.omninest.modules.music.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.omninest.common.config.ConfigValueProvider;
import com.omninest.common.config.LegacyDeploymentConfigResolver;
import com.omninest.common.config.RuntimeConfigCache;
import com.omninest.modules.music.config.MusicProviderProperties;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.mock.env.MockEnvironment;

/**
 * 音乐运行时配置聚合测试。
 *
 * @author OmniNest
 */
class MusicRuntimeConfigServiceTest {
    private final ConfigValueProvider valueProvider = Mockito.mock(ConfigValueProvider.class);
    private final RuntimeConfigCache cache = Mockito.mock(RuntimeConfigCache.class);
    private final Map<String, String> values = new HashMap<>();
    private final MusicProviderProperties deploymentProperties = new MusicProviderProperties();
    private MockEnvironment environment;
    private MusicRuntimeConfigService configService;

    @BeforeEach
    void setUp() {
        values.clear();
        environment = new MockEnvironment();
        deploymentProperties.setNeteaseBaseUrl("http://localhost:3001");
        Mockito.when(cache.get(Mockito.anyString())).thenReturn(Optional.empty());
        Mockito.when(valueProvider.findByKey(Mockito.anyString()))
                .thenAnswer(invocation -> Optional.ofNullable(values.get(invocation.getArgument(0))));
        configService = createService();
    }

    @Test
    void usesLegacyNeteaseEndpointDuringCompatibilityPeriod() {
        values.put(MusicRuntimeConfigService.NETEASE_ENABLED, "true");
        values.put(MusicRuntimeConfigService.NETEASE_BASE_URL, "http://192.168.1.206:9090/api");

        assertThat(configService.trustedPlatformUrls("netease"))
                .containsExactly("http://192.168.1.206:9090/api");
    }

    @Test
    void canonicalEndpointOverridesDeploymentCompatibilityValue() {
        values.put(MusicRuntimeConfigService.NETEASE_BASE_URL, "http://legacy.internal:3001");
        environment.setProperty("OMNINEST_NETEASE_API_BASE_URL", "http://deployment.internal:3001");
        deploymentProperties.setNeteaseBaseUrl("http://deployment.internal:3001");
        configService = createService();

        assertThat(configService.neteaseBaseUrl()).isEqualTo("http://legacy.internal:3001");
    }

    @Test
    void deploymentEndpointIsUsedWhenCanonicalValueIsStillDefault() {
        environment.setProperty("OMNINEST_NETEASE_API_BASE_URL", "http://deployment.internal:3001");
        deploymentProperties.setNeteaseBaseUrl("http://deployment.internal:3001");
        configService = createService();

        assertThat(configService.neteaseBaseUrl()).isEqualTo("http://deployment.internal:3001");
    }

    @Test
    void includesVersionedQqEndpointsWhenPlatformIsEnabled() {
        values.put(MusicRuntimeConfigService.QQ_MUSIC_ENABLED, "true");

        assertThat(configService.trustedPlatformUrls("qq")).containsExactly(
                "https://u.y.qq.com/cgi-bin/musicu.fcg",
                "https://c.y.qq.com"
        );
    }

    @Test
    void readsEditableProviderSettingsFromRuntimeCatalog() {
        values.put(MusicRuntimeConfigService.MUSICBRAINZ_BASE_URL, "https://musicbrainz.example/ws/2");
        values.put("music.platform.qq.u-url", "https://qq-u.example/api");
        values.put("music.platform.qq.c-url", "https://qq-c.example/api");

        assertThat(configService.musicBrainzBaseUrl()).isEqualTo("https://musicbrainz.example/ws/2");
        assertThat(configService.qqMusicUUrl()).isEqualTo("https://qq-u.example/api");
        assertThat(configService.qqMusicCUrl()).isEqualTo("https://qq-c.example/api");
    }

    @Test
    void readsEditablePlaybackHostsAndKeepsDelaysInBusinessCode() {
        values.put("music.platform.netease.request-delay-ms", "9999");
        values.put("music.netease.hosts", "untrusted.example");
        values.put("music.metadata-provider.musicbrainz.request-delay-ms", "1");
        values.put(MusicRuntimeConfigService.MUSICBRAINZ_COVER_BASE_URL, "https://cover.example");

        assertThat(configService.neteaseRequestDelayMs()).isEqualTo(100L);
        assertThat(configService.trustedPlaybackHostSuffixes("netease"))
                .containsExactly("untrusted.example");
        assertThat(configService.musicBrainzRequestDelayMs()).isEqualTo(1100L);
        assertThat(configService.musicBrainzCoverBaseUrl())
                .isEqualTo("https://cover.example");
    }

    @Test
    void fallsBackToLegacyPlaybackHostKeyDuringMigration() {
        values.put("music.platform.netease.playback-host-suffixes", "music.example");

        assertThat(configService.trustedPlaybackHostSuffixes("netease"))
                .containsExactly("music.example");
    }

    @Test
    void returnsNoTrustedOriginsWhenProviderIsDisabled() {
        values.put(MusicRuntimeConfigService.NETEASE_ENABLED, "false");

        assertThat(configService.trustedPlatformUrls("netease")).isEmpty();
    }

    @Test
    void returnsVersionedPlaybackHostSuffixes() {
        values.put(MusicRuntimeConfigService.NETEASE_ENABLED, "true");

        assertThat(configService.trustedPlaybackHostSuffixes("NETEASE"))
                .containsExactly("music.126.net", "music.163.com");
    }

    @Test
    void doesNotExposeAnotherPlatformsPlaybackHosts() {
        values.put(MusicRuntimeConfigService.QQ_MUSIC_ENABLED, "false");

        assertThat(configService.trustedPlaybackHostSuffixes("qq")).isEmpty();
    }

    @Test
    void fallsBackToLegacyQqEnabledKeyDuringMigration() {
        values.put("music.platform.qq.enabled", "false");

        assertThat(configService.qqMusicEnabled()).isFalse();
    }

    private MusicRuntimeConfigService createService() {
        LegacyDeploymentConfigResolver resolver = new LegacyDeploymentConfigResolver(
                valueProvider,
                cache,
                environment
        );
        return new MusicRuntimeConfigService(valueProvider, cache, deploymentProperties, resolver);
    }
}
