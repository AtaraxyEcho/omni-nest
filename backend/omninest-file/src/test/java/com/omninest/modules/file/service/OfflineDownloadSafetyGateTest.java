package com.omninest.modules.file.service;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.omninest.common.error.BusinessException;
import com.omninest.common.security.MalwareScanGateway;
import com.omninest.common.security.MalwareScanGateway.ScanResult;
import java.nio.file.Path;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/**
 * 验证离线下载文件在入库前的安全扫描门禁。
 *
 * @author OmniNest
 */
class OfflineDownloadSafetyGateTest {
    private static final UUID TASK_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");
    private final MalwareScanGateway malwareScanGateway = mock(MalwareScanGateway.class);
    private final OfflineDownloadSafetyGate safetyGate = new OfflineDownloadSafetyGate(malwareScanGateway);

    @Test
    void acceptsFilesWhenAllScansAreClean() {
        Path first = Path.of("first.mkv");
        Path second = Path.of("second.srt");
        when(malwareScanGateway.scan(first)).thenReturn(ScanResult.clean());
        when(malwareScanGateway.scan(second)).thenReturn(ScanResult.clean());

        safetyGate.requireSafe(TASK_ID, List.of(first, second));

        verify(malwareScanGateway).scan(first);
        verify(malwareScanGateway).scan(second);
    }

    @Test
    void rejectsInfectedFileBeforeImport() {
        Path file = Path.of("movie.mkv");
        when(malwareScanGateway.scan(file)).thenReturn(ScanResult.infected("Eicar-Signature FOUND"));

        assertThatThrownBy(() -> safetyGate.requireSafe(TASK_ID, List.of(file)))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("安全扫描未通过");
    }

    @Test
    void failsClosedWhenScannerIsUnavailable() {
        Path file = Path.of("movie.mkv");
        when(malwareScanGateway.scan(file)).thenReturn(ScanResult.error("扫描服务不可用"));

        assertThatThrownBy(() -> safetyGate.requireSafe(TASK_ID, List.of(file)))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("ClamAV 安全扫描不可用");
    }

    @Test
    void allowsExplicitlyDisabledScanner() {
        Path file = Path.of("movie.mkv");
        when(malwareScanGateway.scan(file)).thenReturn(ScanResult.skipped());

        safetyGate.requireSafe(TASK_ID, List.of(file));

        verify(malwareScanGateway).scan(file);
    }
}
