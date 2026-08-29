package com.omninest.modules.music.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.omninest.common.cache.ReadThroughCache;
import com.omninest.common.error.BusinessException;
import com.omninest.modules.music.dto.OnlineMusicDtos.DailyRecommendedTracksDto;
import com.omninest.modules.music.dto.OnlineMusicDtos.OnlinePlaylistDto;
import com.omninest.modules.music.dto.OnlineMusicDtos.OnlineTrackDto;
import com.omninest.modules.music.service.platform.MusicPlatform;
import com.omninest.modules.music.service.platform.MusicPlatformCapabilities;
import com.omninest.modules.music.service.platform.MusicPlatformProvider;
import com.omninest.modules.music.service.platform.NeteaseMusicProxy;
import java.util.List;
import java.util.UUID;
import java.util.function.Supplier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentMatchers;

/**
 * 在线音乐平台聚合服务测试。
 *
 * @author OmniNest
 */
class MusicPlatformServiceTest {
    private static final UUID OWNER_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");

    private final NeteaseMusicProxy neteaseProvider = mock(NeteaseMusicProxy.class);
    private final MusicRuntimeConfigService configService = mock(MusicRuntimeConfigService.class);
    private final ReadThroughCache readThroughCache = mock(ReadThroughCache.class);
    private final MusicPlatformService service = new MusicPlatformService(
            List.of(neteaseProvider),
            configService,
            readThroughCache
    );

    @BeforeEach
    void setUp() {
        when(neteaseProvider.platform()).thenReturn(MusicPlatform.NETEASE);
        when(neteaseProvider.capabilities()).thenReturn(new MusicPlatformCapabilities(
                true,
                true,
                true,
                true,
                true,
                List.of("lossless")
        ));
        when(configService.onlineEnabled()).thenReturn(true);
        when(configService.neteaseEnabled()).thenReturn(true);
        when(readThroughCache.getOrLoad(
                ArgumentMatchers.anyString(),
                ArgumentMatchers.any(),
                ArgumentMatchers.any(),
                ArgumentMatchers.eq(DailyRecommendedTracksDto.class)
        )).thenAnswer(invocation -> {
            Supplier<?> loader = invocation.getArgument(2);
            return loader.get();
        });
    }

    @Test
    void searchPropagatesCurrentUserToProvider() {
        OnlineTrackDto track = new OnlineTrackDto(
                "netease",
                "song-1",
                "Song",
                "Artist",
                "Album",
                null,
                180,
                null,
                null
        );
        when(neteaseProvider.search(OWNER_ID, "song", 20)).thenReturn(List.of(track));

        List<OnlineTrackDto> result = service.search(OWNER_ID, "song", 20);

        assertThat(result).containsExactly(track);
        verify(neteaseProvider).search(OWNER_ID, "song", 20);
    }

    @Test
    void playlistsPropagateCurrentUserAndPlatformIdentifier() {
        OnlinePlaylistDto playlist = new OnlinePlaylistDto(
                "netease",
                "playlist-1",
                "Favorites",
                null,
                null,
                20,
                "Music User",
                false,
                null
        );
        when(neteaseProvider.isLoggedIn(OWNER_ID)).thenReturn(true);
        when(neteaseProvider.playlists(OWNER_ID)).thenReturn(List.of(playlist));

        assertThat(service.playlists(OWNER_ID, "netease")).containsExactly(playlist);

        verify(neteaseProvider).playlists(OWNER_ID);
    }

    @Test
    void unsupportedPlatformIsRejectedByWhitelist() {
        assertThatThrownBy(() -> service.search(OWNER_ID, "song", 20, "unknown"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("不支持的音乐平台");
    }

    @Test
    void lyricsDoNotReusePlatformSpecificSongIdAcrossProviders() {
        MusicPlatformProvider.LyricsResult lyrics = new MusicPlatformProvider.LyricsResult(null, null);
        when(neteaseProvider.getLyrics(OWNER_ID, "song-1")).thenReturn(lyrics);

        assertThat(service.getLyrics(OWNER_ID, "netease", "song-1")).isEqualTo(lyrics);

        verify(neteaseProvider).getLyrics(OWNER_ID, "song-1");
    }

    @Test
    void dailyRecommendationRequiresConnectionAndUsesCurrentUser() {
        OnlineTrackDto track = new OnlineTrackDto(
                "netease",
                "daily-1",
                "Daily Song",
                "Daily Artist",
                "Daily Album",
                null,
                200,
                null,
                null
        );
        when(neteaseProvider.isLoggedIn(OWNER_ID)).thenReturn(true);
        when(neteaseProvider.dailyRecommendedTracks(OWNER_ID)).thenReturn(List.of(track));

        DailyRecommendedTracksDto result = service.dailyRecommendedTracks(OWNER_ID, "netease");

        assertThat(result.platform()).isEqualTo("netease");
        assertThat(result.tracks()).containsExactly(track);
        verify(neteaseProvider).dailyRecommendedTracks(OWNER_ID);
    }
}
