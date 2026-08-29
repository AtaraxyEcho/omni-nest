package com.omninest.modules.file.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.omninest.common.rclone.RcloneGateway;
import com.omninest.modules.file.domain.StorageRemoteMetadataCache;
import com.omninest.modules.file.repository.StorageRemoteMetadataCacheRepository;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import tools.jackson.databind.ObjectMapper;

/**
 * ExternalStorageSyncService 单元测试。
 *
 * @author OmniNest
 */
class ExternalStorageSyncServiceTest {

    private static final UUID ACCOUNT_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");
    private static final String FS = "omni-12345678:";
    private static final String REMOTE_PATH = "/documents";

    private final StorageRemoteMetadataCacheRepository metadataCacheRepository =
            mock(StorageRemoteMetadataCacheRepository.class);
    private final RcloneGateway rcloneGateway = mock(RcloneGateway.class);
    private final ObjectMapper objectMapper = new ObjectMapper();

    private final ExternalStorageSyncService syncService =
            new ExternalStorageSyncService(metadataCacheRepository, rcloneGateway, objectMapper);

    @Test
    void syncDirectory_clearsOldCacheAndSavesNewEntries() {
        // 构造 Rclone 返回数据
        RcloneGateway.DirectoryEntry file1 = entry(
                "report.pdf",
                false,
                1024L,
                Map.of("Name", "report.pdf", "IsDir", false, "Size", 1024L,
                        "MimeType", "application/pdf")
        );
        RcloneGateway.DirectoryEntry file2 = entry(
                "images",
                true,
                0L,
                Map.of("Name", "images", "IsDir", true, "Size", 0L)
        );

        when(rcloneGateway.listDirectory(FS, REMOTE_PATH, false)).thenReturn(List.of(file1, file2));
        when(metadataCacheRepository.save(any(StorageRemoteMetadataCache.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        // 执行同步
        syncService.syncDirectory(ACCOUNT_ID, FS, REMOTE_PATH);

        // 验证旧缓存被清除
        verify(metadataCacheRepository).deleteByExternalAccountIdAndRemotePath(ACCOUNT_ID, REMOTE_PATH);

        // 验证新缓存被保存
        ArgumentCaptor<StorageRemoteMetadataCache> captor =
                ArgumentCaptor.forClass(StorageRemoteMetadataCache.class);
        verify(metadataCacheRepository).save(captor.capture());

        StorageRemoteMetadataCache saved = captor.getValue();
        assertThat(saved.getExternalAccountId()).isEqualTo(ACCOUNT_ID);
        assertThat(saved.getRemotePath()).isEqualTo(REMOTE_PATH);
        assertThat(saved.getMetadataJson()).contains("report.pdf");
        assertThat(saved.getMetadataJson()).contains("images");
        assertThat(saved.getCachedAt()).isNotNull();
        assertThat(saved.getExpiresAt()).isAfter(saved.getCachedAt());
    }

    @Test
    void syncDirectory_handlesEmptyDirectory() {
        when(rcloneGateway.listDirectory(FS, REMOTE_PATH, false)).thenReturn(List.of());
        when(metadataCacheRepository.save(any(StorageRemoteMetadataCache.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        syncService.syncDirectory(ACCOUNT_ID, FS, REMOTE_PATH);

        ArgumentCaptor<StorageRemoteMetadataCache> captor =
                ArgumentCaptor.forClass(StorageRemoteMetadataCache.class);
        verify(metadataCacheRepository).save(captor.capture());

        assertThat(captor.getValue().getMetadataJson()).isEqualTo("[]");
    }

    @Test
    void getCachedMetadata_returnsJsonWhenCacheExists() {
        StorageRemoteMetadataCache cached = new StorageRemoteMetadataCache();
        cached.setMetadataJson("[{\"Name\":\"test.txt\"}]");

        when(metadataCacheRepository.findByExternalAccountIdAndRemotePath(ACCOUNT_ID, REMOTE_PATH))
                .thenReturn(List.of(cached));

        String result = syncService.getCachedMetadata(ACCOUNT_ID, REMOTE_PATH);

        assertThat(result).isEqualTo("[{\"Name\":\"test.txt\"}]");
    }

    @Test
    void getCachedMetadata_returnsNullWhenNoCache() {
        when(metadataCacheRepository.findByExternalAccountIdAndRemotePath(ACCOUNT_ID, REMOTE_PATH))
                .thenReturn(List.of());

        String result = syncService.getCachedMetadata(ACCOUNT_ID, REMOTE_PATH);

        assertThat(result).isNull();
    }

    @Test
    void isCacheStale_returnsTrueWhenCacheExpired() {
        StorageRemoteMetadataCache cached = new StorageRemoteMetadataCache();
        cached.setExpiresAt(Instant.now().minusSeconds(60));

        when(metadataCacheRepository.findByExternalAccountIdAndRemotePath(ACCOUNT_ID, REMOTE_PATH))
                .thenReturn(List.of(cached));

        boolean stale = syncService.isCacheStale(ACCOUNT_ID, REMOTE_PATH);

        assertThat(stale).isTrue();
    }

    @Test
    void isCacheStale_returnsFalseWhenCacheFresh() {
        StorageRemoteMetadataCache cached = new StorageRemoteMetadataCache();
        cached.setExpiresAt(Instant.now().plusSeconds(3600));

        when(metadataCacheRepository.findByExternalAccountIdAndRemotePath(ACCOUNT_ID, REMOTE_PATH))
                .thenReturn(List.of(cached));

        boolean stale = syncService.isCacheStale(ACCOUNT_ID, REMOTE_PATH);

        assertThat(stale).isFalse();
    }

    @Test
    void isCacheStale_returnsTrueWhenNoCache() {
        when(metadataCacheRepository.findByExternalAccountIdAndRemotePath(ACCOUNT_ID, REMOTE_PATH))
                .thenReturn(List.of());

        boolean stale = syncService.isCacheStale(ACCOUNT_ID, REMOTE_PATH);

        assertThat(stale).isTrue();
    }

    @Test
    void clearCache_deletesAllEntriesForAccount() {
        syncService.clearCache(ACCOUNT_ID);

        verify(metadataCacheRepository).deleteByExternalAccountId(ACCOUNT_ID);
    }

    private RcloneGateway.DirectoryEntry entry(
            String name,
            boolean directory,
            long sizeBytes,
            Map<String, Object> metadata
    ) {
        return new RcloneGateway.DirectoryEntry(
                name,
                name,
                directory,
                sizeBytes,
                null,
                null,
                null,
                metadata
        );
    }
}
