package com.omninest.common.rclone;

import static org.assertj.core.api.Assertions.assertThat;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/**
 * RcloneRcClient 返回模型转换测试。
 *
 * @author OmniNest
 */
class RcloneRcClientTest {

    @Test
    void parseDirectoryEntriesReturnsTypedValuesAndPlainMetadata() {
        JSONObject checksum = new JSONObject();
        checksum.put("sha1", "abc123");
        JSONArray tags = new JSONArray();
        tags.add("document");

        JSONObject item = new JSONObject();
        item.put("Name", "report.pdf");
        item.put("Path", "documents/report.pdf");
        item.put("IsDir", false);
        item.put("Size", 2048L);
        item.put("ModTime", "2026-07-22T08:30:00Z");
        item.put("MimeType", "application/pdf");
        item.put("Hash", "abc123");
        item.put("Checksums", checksum);
        item.put("Tags", tags);

        JSONArray entriesArray = new JSONArray();
        entriesArray.add(item);
        JSONObject result = new JSONObject();
        result.put("list", entriesArray);

        List<RcloneGateway.DirectoryEntry> entries = RcloneRcClient.parseDirectoryEntries(result);

        assertThat(entries).singleElement().satisfies(entry -> {
            assertThat(entry.name()).isEqualTo("report.pdf");
            assertThat(entry.path()).isEqualTo("documents/report.pdf");
            assertThat(entry.directory()).isFalse();
            assertThat(entry.sizeBytes()).isEqualTo(2048L);
            assertThat(entry.modifiedAt()).isEqualTo(Instant.parse("2026-07-22T08:30:00Z"));
            assertThat(entry.mimeType()).isEqualTo("application/pdf");
            assertThat(entry.hash()).isEqualTo("abc123");
            assertThat(entry.metadata().get("Checksums")).isInstanceOf(Map.class);
            assertThat(entry.metadata().get("Tags")).isInstanceOf(List.class);
            assertThat(entry.metadata().values())
                    .noneMatch(value -> value instanceof JSONObject || value instanceof JSONArray);
        });
    }

    @Test
    void parseDirectoryEntriesIgnoresInvalidModificationTime() {
        JSONObject item = new JSONObject();
        item.put("Name", "legacy.txt");
        item.put("ModTime", "not-an-instant");

        JSONArray entriesArray = new JSONArray();
        entriesArray.add(item);
        JSONObject result = new JSONObject();
        result.put("list", entriesArray);

        List<RcloneGateway.DirectoryEntry> entries = RcloneRcClient.parseDirectoryEntries(result);

        assertThat(entries).singleElement().extracting(RcloneGateway.DirectoryEntry::modifiedAt).isNull();
    }
}
