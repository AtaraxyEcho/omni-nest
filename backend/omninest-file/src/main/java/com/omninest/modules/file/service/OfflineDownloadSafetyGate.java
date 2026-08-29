package com.omninest.modules.file.service;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.common.security.MalwareScanGateway;
import com.omninest.common.security.MalwareScanGateway.ScanResult;
import com.omninest.common.security.MalwareScanGateway.Status;
import java.nio.file.Path;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 在离线下载文件进入对象存储前执行安全扫描门禁。
 *
 * @author OmniNest
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class OfflineDownloadSafetyGate {
    private final MalwareScanGateway malwareScanGateway;

    /**
     * 要求全部下载文件通过安全扫描。
     *
     * @param taskId 离线下载任务标识
     * @param files 下载完成文件
     */
    public void requireSafe(UUID taskId, List<Path> files) {
        for (Path file : files) {
            ScanResult result = malwareScanGateway.scan(file);
            if (result.status() == Status.CLEAN) {
                continue;
            }
            if (result.status() == Status.SKIPPED) {
                log.info("离线下载安全扫描未启用: taskId={}", taskId);
                return;
            }
            if (result.status() == Status.INFECTED) {
                log.warn("离线下载文件检测到威胁: taskId={}, fileName={}, detail={}",
                        taskId, file.getFileName(), result.message());
                throw new BusinessException(ErrorCode.FILE_UPLOAD_FAILED, "离线下载文件安全扫描未通过，文件未导入");
            }
            log.warn("离线下载安全扫描不可用: taskId={}, fileName={}, detail={}",
                    taskId, file.getFileName(), result.message());
            throw new BusinessException(ErrorCode.DEPENDENCY_UNAVAILABLE, "ClamAV 安全扫描不可用，文件未导入");
        }
    }
}
