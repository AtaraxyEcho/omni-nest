package com.omninest.modules.file.service;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.common.security.MalwareScanGateway;
import com.omninest.common.security.MalwareScanGateway.ScanResult;
import com.omninest.common.security.MalwareScanGateway.Status;
import com.omninest.common.storage.ObjectStorageClient;
import com.omninest.common.storage.ObjectStorageKey;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.DigestInputStream;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 统一执行文件入口的病毒扫描和服务端摘要计算。
 *
 * @author OmniNest
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class FileIngressSafetyService {
    private final MalwareScanGateway malwareScanGateway;
    private final ObjectStorageClient objectStorageClient;

    /**
     * 检查本地待入库文件。
     *
     * @param file 待检查文件
     * @param sourceType 来源类型
     * @param correlationId 来源任务或会话标识
     * @return 安全检查结果
     */
    public InspectionResult inspect(Path file, String sourceType, UUID correlationId) {
        try {
            long sizeBytes = Files.size(file);
            try (InputStream inputStream = Files.newInputStream(file)) {
                return inspectStream(inputStream, sizeBytes, sourceType, correlationId);
            }
        } catch (IOException exception) {
            log.warn("读取待入库文件失败: sourceType={}, correlationId={}, errorType={}",
                    sourceType, correlationId, exception.getClass().getSimpleName());
            throw new BusinessException(ErrorCode.FILE_UPLOAD_FAILED, "无法读取待入库文件");
        }
    }

    /**
     * 检查隔离桶中的待入库对象。
     *
     * @param key 隔离对象键
     * @param sizeBytes 对象大小
     * @param sourceType 来源类型
     * @param correlationId 来源任务或会话标识
     * @return 安全检查结果
     */
    public InspectionResult inspect(
            ObjectStorageKey key,
            long sizeBytes,
            String sourceType,
            UUID correlationId
    ) {
        try (InputStream inputStream = objectStorageClient.getObject(key)) {
            return inspectStream(inputStream, sizeBytes, sourceType, correlationId);
        } catch (IOException exception) {
            log.warn("读取隔离对象失败: sourceType={}, correlationId={}, bucket={}, errorType={}",
                    sourceType, correlationId, key.bucket(), exception.getClass().getSimpleName());
            throw new BusinessException(ErrorCode.FILE_UPLOAD_FAILED, "无法读取待扫描对象");
        }
    }

    private InspectionResult inspectStream(
            InputStream inputStream,
            long sizeBytes,
            String sourceType,
            UUID correlationId
    ) throws IOException {
        MessageDigest digest = sha256Digest();
        ScanResult result;
        try (DigestInputStream digestInputStream = new DigestInputStream(inputStream, digest)) {
            result = malwareScanGateway.scan(digestInputStream, sizeBytes);
            digestInputStream.transferTo(OutputStream.nullOutputStream());
        }
        requireAccepted(result, sourceType, correlationId);
        return new InspectionResult(
                result.status(),
                result.message(),
                HexFormat.of().formatHex(digest.digest())
        );
    }

    private void requireAccepted(ScanResult result, String sourceType, UUID correlationId) {
        if (result.status() == Status.CLEAN || result.status() == Status.SKIPPED) {
            if (result.status() == Status.SKIPPED) {
                log.info("文件安全扫描未启用: sourceType={}, correlationId={}", sourceType, correlationId);
            }
            return;
        }
        if (result.status() == Status.INFECTED) {
            log.warn("待入库文件检测到威胁: sourceType={}, correlationId={}, detail={}",
                    sourceType, correlationId, result.message());
            throw new BusinessException(ErrorCode.FILE_SECURITY_REJECTED, "文件安全扫描未通过，内容已拒绝入库");
        }
        log.warn("文件安全扫描不可用: sourceType={}, correlationId={}, detail={}",
                sourceType, correlationId, result.message());
        throw new BusinessException(ErrorCode.DEPENDENCY_UNAVAILABLE, "ClamAV 安全扫描不可用，文件保持隔离");
    }

    private MessageDigest sha256Digest() {
        try {
            return MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("运行环境不支持 SHA-256", exception);
        }
    }

    /**
     * 文件入口安全检查结果。
     *
     * @param status 扫描状态
     * @param message 扫描摘要
     * @param sha256 服务端计算的文件摘要
     * @author OmniNest
     */
    public record InspectionResult(Status status, String message, String sha256) {
    }
}
