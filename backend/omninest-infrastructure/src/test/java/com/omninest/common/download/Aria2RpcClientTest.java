package com.omninest.common.download;

import static org.assertj.core.api.Assertions.assertThat;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import com.omninest.common.download.OfflineDownloadGateway.TaskSnapshot;
import org.junit.jupiter.api.Test;

/**
 * Aria2RpcClient 返回模型转换测试。
 *
 * @author OmniNest
 */
class Aria2RpcClientTest {

    @Test
    void toTaskSnapshotReturnsTypedStatusAndTorrentName() {
        JSONObject firstFile = new JSONObject();
        firstFile.put("path", "D:/downloads/movie/video.mkv");
        firstFile.put("selected", "true");
        JSONObject secondFile = new JSONObject();
        secondFile.put("path", "D:/downloads/movie/sample.mkv");
        secondFile.put("selected", "false");
        JSONArray files = new JSONArray();
        files.add(firstFile);
        files.add(secondFile);

        JSONObject info = new JSONObject();
        info.put("name", "Example Movie");
        JSONObject bittorrent = new JSONObject();
        bittorrent.put("info", info);

        JSONObject result = new JSONObject();
        result.put("status", "active");
        result.put("totalLength", "4096");
        result.put("completedLength", "1024");
        result.put("downloadSpeed", "512");
        result.put("files", files);
        result.put("bittorrent", bittorrent);

        TaskSnapshot snapshot = Aria2RpcClient.toTaskSnapshot(result);

        assertThat(snapshot.state()).isEqualTo("active");
        assertThat(snapshot.totalBytes()).isEqualTo(4096L);
        assertThat(snapshot.completedBytes()).isEqualTo(1024L);
        assertThat(snapshot.speedBytes()).isEqualTo(512L);
        assertThat(snapshot.displayName()).isEqualTo("Example Movie");
        assertThat(snapshot.files()).hasSize(2);
        assertThat(snapshot.files().get(0).selected()).isTrue();
        assertThat(snapshot.files().get(1).selected()).isFalse();
    }

    @Test
    void toTaskSnapshotFallsBackToFirstFileName() {
        JSONObject file = new JSONObject();
        file.put("path", "D:/downloads/archive.zip");
        JSONArray files = new JSONArray();
        files.add(file);
        JSONObject result = new JSONObject();
        result.put("files", files);

        TaskSnapshot snapshot = Aria2RpcClient.toTaskSnapshot(result);

        assertThat(snapshot.displayName()).isEqualTo("archive.zip");
    }
}
