package com.omninest.modules.file.service;

import com.omninest.common.storage.ObjectStorageClient;
import com.omninest.common.storage.ObjectStorageKey;
import com.omninest.modules.file.domain.FilePurgeEntry;
import com.omninest.modules.file.event.FilePurgeRequestedEvent;
import jakarta.annotation.PreDestroy;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 文件永久删除 Worker 编排服务。
 *
 * @author OmniNest
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class FilePurgeExecutionService {

    private static final int DELETE_PARALLELISM = 4;

    private final FilePurgeStateService stateService;
    private final ObjectStorageClient objectStorageClient;
    private final ExecutorService deleteExecutor = Executors.newFixedThreadPool(DELETE_PARALLELISM);

    /**
     * 执行一次可幂等重试的永久删除任务。
     *
     * @param event 永久删除任务消息
     */
    public void execute(FilePurgeRequestedEvent event) {
        if (!stateService.markRunning(event)) {
            return;
        }
        stateService.plan(event);
        while (true) {
            List<FilePurgeEntry> entries = stateService.nextEntries(event.taskId());
            if (entries.isEmpty()) {
                break;
            }
            deleteEntriesInParallel(event, entries);
        }
        stateService.markVerifying(event.taskId());
        stateService.verifyCompleted(event.taskId());
        stateService.markFinalizing(event.taskId());
        stateService.finalizePurge(event);
    }

    /**
     * 批内并行删除对象，缩短单条 purge 总时长。
     * 同一批内的状态回写并发执行；标记失败后由重试机制处理。
     */
    private void deleteEntriesInParallel(FilePurgeRequestedEvent event, List<FilePurgeEntry> entries) {
        if (entries.size() == 1) {
            deleteEntry(entries.get(0));
            stateService.updateDeletingProgress(event.taskId());
            return;
        }
        List<Future<?>> futures = new ArrayList<>();
        for (FilePurgeEntry entry : entries) {
            futures.add(deleteExecutor.submit(() -> deleteEntry(entry)));
        }
        RuntimeException firstFailure = null;
        for (Future<?> future : futures) {
            try {
                future.get();
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                if (firstFailure == null) {
                    firstFailure = new IllegalStateException("永久删除任务等待并发结果时被中断", exception);
                }
            } catch (ExecutionException exception) {
                if (firstFailure == null) {
                    firstFailure = executionFailure(exception);
                }
            }
        }
        stateService.updateDeletingProgress(event.taskId());
        if (firstFailure != null) {
            throw firstFailure;
        }
    }

    private RuntimeException executionFailure(ExecutionException exception) {
        Throwable cause = exception.getCause();
        if (cause instanceof RuntimeException runtimeException) {
            return runtimeException;
        }
        return new IllegalStateException("永久删除并发条目执行失败", cause);
    }

    private void deleteEntry(FilePurgeEntry entry) {
        ObjectStorageKey key = new ObjectStorageKey(entry.getBucketName(), entry.getObjectKey());
        try {
            if (entry.getMinioVersionId() != null && !entry.getMinioVersionId().isBlank()) {
                objectStorageClient.removeObjectVersion(key, entry.getMinioVersionId());
                stateService.markEntryCompleted(entry.getId(), "DELETED");
                return;
            }
            if (!objectStorageClient.objectExists(key)) {
                stateService.markEntryCompleted(entry.getId(), "NOT_FOUND");
                return;
            }
            objectStorageClient.removeObject(key);
            stateService.markEntryCompleted(entry.getId(), "DELETED");
        } catch (RuntimeException exception) {
            stateService.markEntryFailed(entry.getId(), exception.getClass().getSimpleName());
            throw exception;
        }
    }

    /**
     * 关闭永久删除线程池，避免应用停止时遗留工作线程。
     */
    @PreDestroy
    public void shutdown() {
        deleteExecutor.shutdownNow();
    }
}
