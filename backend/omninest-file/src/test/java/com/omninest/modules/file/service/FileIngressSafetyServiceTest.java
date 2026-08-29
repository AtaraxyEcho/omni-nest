package com.omninest.modules.file.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.common.security.MalwareScanGateway;
import com.omninest.common.storage.ObjectStorageClient;
import com.omninest.common.storage.ObjectStorageKey;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/**
 * 文件入口安全检查服务测试。
 *
 * @author OmniNest
 */
class FileIngressSafetyServiceTest {
    private static final UUID CORRELATION_ID =
            UUID.fromString("10000000-0000-0000-0000-000000000001");

    private final MalwareScanGateway malwareScanGateway = mock(MalwareScanGateway.class);
    private final ObjectStorageClient objectStorageClient = mock(ObjectStorageClient.class);
    private final FileIngressSafetyService service =
            new FileIngressSafetyService(malwareScanGateway, objectStorageClient);

    @Test
    void inspectObjectComputesServerDigestAfterCleanScan() {
        byte[] content = "hello".getBytes();
        ObjectStorageKey key = new ObjectStorageKey("file-quarantine", "uploads/file.txt");
        when(objectStorageClient.getObject(key)).thenReturn(new ByteArrayInputStream(content));
        when(malwareScanGateway.scan(any(InputStream.class), eq((long) content.length)))
                .thenReturn(MalwareScanGateway.ScanResult.clean());

        FileIngressSafetyService.InspectionResult result =
                service.inspect(key, content.length, "UPLOAD", CORRELATION_ID);

        assertThat(result.sha256())
                .isEqualTo("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824");
        verify(malwareScanGateway).scan(any(InputStream.class), eq((long) content.length));
    }

    @Test
    void inspectObjectRejectsInfectedContent() {
        byte[] content = "infected".getBytes();
        ObjectStorageKey key = new ObjectStorageKey("file-quarantine", "uploads/file.bin");
        when(objectStorageClient.getObject(key)).thenReturn(new ByteArrayInputStream(content));
        when(malwareScanGateway.scan(any(InputStream.class), eq((long) content.length)))
                .thenReturn(MalwareScanGateway.ScanResult.infected("Eicar-Signature FOUND"));

        assertThatThrownBy(() -> service.inspect(key, content.length, "UPLOAD", CORRELATION_ID))
                .isInstanceOfSatisfying(BusinessException.class, exception ->
                        assertThat(exception.errorCode()).isEqualTo(ErrorCode.FILE_SECURITY_REJECTED));
    }
}
