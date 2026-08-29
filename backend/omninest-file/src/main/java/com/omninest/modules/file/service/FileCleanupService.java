package com.omninest.modules.file.service;

import com.omninest.modules.file.domain.UploadStatus;
import com.omninest.modules.file.domain.FileNode;
import com.omninest.modules.file.domain.FileUploadSession;
import com.omninest.modules.file.repository.FileNodeRepository;
import com.omninest.modules.file.repository.FileUploadSessionRepository;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/**
 * 在 Scheduler 角色中清理过期文件和上传会话。
 *
 * @author OmniNest
 */
@Slf4j
@Service
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "omninest.runtime", name = "role", havingValue = "scheduler")
public class FileCleanupService {
    private final FileNodeRepository fileNodeRepository;
    private final FileUploadSessionRepository uploadSessionRepository;
    private final FileDeletionService fileDeletionService;
    private final FileUploadSessionService fileUploadSessionService;

    // 每个节点独立事务，避免大批量清理时长事务锁定
    @Scheduled(cron = "0 0 4 * * *")
    public void purgeExpiredRecycleBin() {
        Instant cutoff = Instant.now().minus(30, ChronoUnit.DAYS);
        List<FileNode> expired = fileNodeRepository.findExpiredDeletedNodes(cutoff);
        if (expired.isEmpty()) {
            return;
        }
        Map<UUID, List<FileNode>> byOwner = expired.stream()
                .collect(Collectors.groupingBy(FileNode::getOwnerUserId));
        int purged = 0;
        for (var entry : byOwner.entrySet()) {
            UUID ownerUserId = entry.getKey();
            for (FileNode node : entry.getValue()) {
                try {
                    fileDeletionService.deletePermanently(ownerUserId, node.getId());
                    purged++;
                } catch (Exception e) {
                    log.warn("回收站自动清理失败: nodeId={}", node.getId(), e);
                }
            }
        }
        log.info("回收站自动清理: purged={}", purged);
    }

    @Scheduled(cron = "0 30 4 * * *")
    public void cleanupExpiredUploadSessions() {
        Instant cutoff = Instant.now().minus(7, ChronoUnit.DAYS);
        List<FileUploadSession> expired = uploadSessionRepository.findByStatusInAndUpdatedAtBefore(
                List.of(
                        UploadStatus.CREATED.getValue(),
                        UploadStatus.UPLOADING.getValue(),
                        UploadStatus.FINALIZING.getValue(),
                        UploadStatus.SCANNING.getValue(),
                        UploadStatus.REJECTED.getValue(),
                        UploadStatus.EXPIRED.getValue()
                ), cutoff);
        if (expired.isEmpty()) {
            return;
        }
        for (FileUploadSession session : expired) {
            try {
                fileUploadSessionService.cancelSession(session.getOwnerUserId(), session.getUploadId());
            } catch (Exception e) {
                log.warn("过期上传会话清理失败: uploadId={}", session.getUploadId(), e);
            }
        }
        log.info("过期上传会话清理: cleaned={}", expired.size());
    }
}
