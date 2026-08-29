package com.omninest.modules.file.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONObject;
import java.util.Map;
import org.junit.jupiter.api.Test;

/**
 * 外部存储凭据安全编解码测试。
 *
 * @author OmniNest
 */
class ExternalStorageCredentialCodecTest {

    @Test
    void editableMetadataExcludesSecretsAndTokens() {
        String credentials = """
                {
                  "provider":"Minio",
                  "access_key_id":"access-id",
                  "secret_access_key":"secret-value",
                  "endpoint":"https://storage.example.com",
                  "region":"cn-east-1"
                }
                """;

        Map<String, String> metadata = ExternalStorageCredentialCodec.extractEditableMetadata("S3", credentials);

        assertThat(metadata).containsEntry("provider", "Minio")
                .containsEntry("access_key_id", "access-id")
                .containsEntry("endpoint", "https://storage.example.com")
                .containsEntry("region", "cn-east-1")
                .doesNotContainKeys("secret_access_key", "token", "client_secret");
    }

    @Test
    void updatePreservesOmittedSecretsAndAppliesMetadataChanges() {
        String existing = """
                {
                  "vendor":"nextcloud",
                  "url":"https://old.example.com/dav",
                  "user":"alice",
                  "pass":"stored-password"
                }
                """;
        String submitted = """
                {
                  "vendor":"nextcloud",
                  "url":"https://new.example.com/dav",
                  "user":"alice",
                  "pass":""
                }
                """;

        JSONObject merged = JSON.parseObject(
                ExternalStorageCredentialCodec.mergeForUpdate(existing, submitted)
        );

        assertThat(merged.getString("url")).isEqualTo("https://new.example.com/dav");
        assertThat(merged.getString("pass")).isEqualTo("stored-password");
    }

    @Test
    void updatePreservesBlankSensitiveFieldsRegardlessOfCase() {
        String existing = """
                {
                  "PASSWORD":"stored-password"
                }
                """;
        String submitted = """
                {
                  "PASSWORD":""
                }
                """;

        JSONObject merged = JSON.parseObject(
                ExternalStorageCredentialCodec.mergeForUpdate(existing, submitted)
        );

        assertThat(merged.getString("PASSWORD")).isEqualTo("stored-password");
    }
}
