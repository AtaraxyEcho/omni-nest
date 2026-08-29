package com.omninest.modules.music.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.omninest.common.cache.ReadThroughCache;
import com.omninest.modules.integration.service.IntegrationAccountData;
import com.omninest.modules.integration.service.IntegrationAccountService;
import com.omninest.modules.music.dto.OnlineMusicDtos.PlatformUserInfo;
import com.omninest.modules.music.service.platform.MusicPlatform;
import com.omninest.modules.music.service.platform.MusicPlatformCredential;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Supplier;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

/**
 * 音乐平台用户凭据服务测试。
 *
 * @author OmniNest
 */
class MusicPlatformCredentialServiceTest {
    private static final UUID OWNER_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");

    @Test
    void saveUsesUserScopedIntegrationAccountAndPreservesVipState() {
        IntegrationAccountService integrationAccountService = Mockito.mock(IntegrationAccountService.class);
        ReadThroughCache readThroughCache = passthroughCache();
        MusicPlatformCredentialService service = new MusicPlatformCredentialService(
                integrationAccountService,
                readThroughCache
        );
        PlatformUserInfo userInfo = new PlatformUserInfo(
                "netease",
                "external-user",
                "Music User",
                "https://example.com/avatar.png",
                true
        );
        Map<String, String> credentials = Map.of("cookie", "MUSIC_U=secret", "vip", "true");
        IntegrationAccountData savedAccount = new IntegrationAccountData(
                UUID.fromString("20000000-0000-0000-0000-000000000001"),
                OWNER_ID,
                "MUSIC",
                "NETEASE",
                "external-user",
                "Music User",
                "https://example.com/avatar.png",
                credentials,
                "ACTIVE",
                Instant.parse("2026-07-10T05:00:00Z")
        );
        Mockito.when(integrationAccountService.save(
                OWNER_ID,
                "MUSIC",
                "netease",
                "external-user",
                "Music User",
                "https://example.com/avatar.png",
                credentials
        )).thenReturn(savedAccount);

        service.save(OWNER_ID, MusicPlatform.NETEASE, "MUSIC_U=secret", userInfo);

        Mockito.verify(integrationAccountService).save(
                Mockito.eq(OWNER_ID),
                Mockito.eq("MUSIC"),
                Mockito.eq("netease"),
                Mockito.eq("external-user"),
                Mockito.eq("Music User"),
                Mockito.eq("https://example.com/avatar.png"),
                Mockito.eq(credentials)
        );
        String cacheKey = "omninest:integration:music:" + OWNER_ID + ":netease:account";
        Mockito.verify(readThroughCache).invalidate(cacheKey);
        Mockito.verify(readThroughCache).getOrLoad(
                Mockito.eq(cacheKey),
                Mockito.any(),
                Mockito.any(),
                Mockito.eq(MusicPlatformCredential.class)
        );
    }

    @Test
    void findRestoresCredentialFromEncryptedDatabaseSourceAfterCacheMiss() {
        IntegrationAccountService integrationAccountService = Mockito.mock(IntegrationAccountService.class);
        ReadThroughCache readThroughCache = passthroughCache();
        MusicPlatformCredentialService service = new MusicPlatformCredentialService(
                integrationAccountService,
                readThroughCache
        );
        IntegrationAccountData account = new IntegrationAccountData(
                UUID.fromString("20000000-0000-0000-0000-000000000001"),
                OWNER_ID,
                "MUSIC",
                "NETEASE",
                "external-user",
                "Music User",
                "https://example.com/avatar.png",
                Map.of("cookie", "MUSIC_U=secret", "vip", "true"),
                "ACTIVE",
                Instant.parse("2026-07-10T05:00:00Z")
        );
        Mockito.when(integrationAccountService.find(OWNER_ID, "MUSIC", "netease"))
                .thenReturn(Optional.of(account));

        var credential = service.find(OWNER_ID, MusicPlatform.NETEASE).orElseThrow();

        assertThat(credential.cookie()).isEqualTo("MUSIC_U=secret");
        assertThat(credential.userInfo().vip()).isTrue();
    }

    @Test
    void clearDeletesIntegrationAccountAndInvalidatesCache() {
        IntegrationAccountService integrationAccountService = Mockito.mock(IntegrationAccountService.class);
        ReadThroughCache readThroughCache = passthroughCache();
        MusicPlatformCredentialService service = new MusicPlatformCredentialService(
                integrationAccountService,
                readThroughCache
        );

        service.clear(OWNER_ID, MusicPlatform.NETEASE);

        Mockito.verify(integrationAccountService).delete(OWNER_ID, "MUSIC", "netease");
        Mockito.verify(readThroughCache).invalidate(
                "omninest:integration:music:" + OWNER_ID + ":netease:account"
        );
    }

    private ReadThroughCache passthroughCache() {
        return Mockito.mock(ReadThroughCache.class, invocation -> {
            if ("getOrLoad".equals(invocation.getMethod().getName())) {
                Supplier<?> loader = invocation.getArgument(2);
                return loader.get();
            }
            return false;
        });
    }
}
