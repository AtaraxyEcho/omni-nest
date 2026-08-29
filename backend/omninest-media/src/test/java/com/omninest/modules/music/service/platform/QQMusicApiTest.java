package com.omninest.modules.music.service.platform;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import com.omninest.common.error.BusinessException;
import com.omninest.modules.music.service.MusicPlatformCredentialService;
import com.omninest.modules.music.service.MusicRuntimeConfigService;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/**
 * QQ 音乐凭据输入校验测试。
 *
 * @author OmniNest
 */
class QQMusicApiTest {
    private static final UUID OWNER_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");

    private final MusicRuntimeConfigService configService = mock(MusicRuntimeConfigService.class);
    private final MusicPlatformCredentialService credentialService = mock(MusicPlatformCredentialService.class);
    private final QQMusicApi api = new QQMusicApi(configService, credentialService);

    @Test
    void applyCookieRejectsMissingPlaybackCredentialWithoutPersistence() {
        assertThatThrownBy(() -> api.applyCookie(OWNER_ID, "uin=o12345"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("播放授权字段");

        verifyNoInteractions(credentialService);
    }

    @Test
    void applyCookieRejectsMissingUserIdentifierWithoutPersistence() {
        assertThatThrownBy(() -> api.applyCookie(OWNER_ID, "qm_keyst=secret"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("uin字段");

        verifyNoInteractions(credentialService);
    }

    @Test
    void parseTrackUsesSongMidRequiredByPlaybackApi() {
        JSONObject trackInfo = JSONObject.parseObject("""
                {
                  "songid": 123,
                  "mid": "song-mid-1",
                  "name": "Night Drive",
                  "interval": 245,
                  "singer": [{"name": "Omni Band"}],
                  "album": {"mid": "album-mid-1", "name": "City Lights"},
                  "file": {"media_mid": "media-mid-1"}
                }
                """);

        var track = api.parseTrackInfo(trackInfo);

        assertThat(track.songId()).isEqualTo("song-mid-1");
        assertThat(track.artistName()).isEqualTo("Omni Band");
        assertThat(track.extra()).containsEntry("mediaMid", "media-mid-1");
        assertThat(track.extra()).containsEntry("numericSongId", "123");
    }

    @Test
    void parsePlaylistsSupportsCreatedAndCollectedResponseFields() {
        JSONObject response = JSONObject.parseObject("""
                {"data": {"disslist": [{
                  "tid": "playlist-1",
                  "diss_name": "Daily Mix",
                  "logo": "https://example.com/cover.jpg",
                  "song_cnt": 12
                }]}}
                """);

        var playlists = api.parsePlaylists(response, false);

        assertThat(playlists).hasSize(1);
        assertThat(playlists.getFirst().playlistId()).isEqualTo("playlist-1");
        assertThat(playlists.getFirst().trackCount()).isEqualTo(12);
    }

    @Test
    void parsePlaylistTracksUnwrapsTrackInfo() {
        JSONArray songs = JSONArray.parseArray("""
                [{"track_info": {
                  "mid": "song-mid-1",
                  "name": "Night Drive",
                  "singer": [{"name": "Omni Band"}],
                  "album": {"mid": "album-mid-1", "name": "City Lights"},
                  "file": {"media_mid": "media-mid-1"}
                }}]
                """);

        var tracks = api.parsePlaylistTracks(songs);

        assertThat(tracks).hasSize(1);
        assertThat(tracks.getFirst().songId()).isEqualTo("song-mid-1");
    }
}
