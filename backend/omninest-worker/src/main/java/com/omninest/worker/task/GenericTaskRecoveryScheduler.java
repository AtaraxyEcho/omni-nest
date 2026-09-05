package com.omninest.worker.task;

import com.alibaba.fastjson2.JSON;
import com.omninest.common.messaging.QueueNames;
import com.omninest.modules.task.domain.TaskDispatch;
import com.omninest.modules.task.repository.TaskDispatchRepository;
import com.omninest.modules.task.service.StaleTaskRecovery;
import com.omninest.modules.task.service.TaskRecordService;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 通用任务心跳超时恢复调度器。
 *
 * <p>覆盖缺少专用恢复调度器的长任务类型：PHOTO_SCAN、PHOTO_THUMBNAILS、
 * EXTERNAL_IMPORT、OFFLINE_DOWNLOAD、MEDIA_SCRAPE、VIDEO_TRANSCODE、
 * FILE_INDEX、THUMBNAIL、TEXT_EXTRACTION。Worker 崩溃导致 RUNNING 任务
 * 心跳超时后，按重试次数裁决：可重试则将任务 Outbox 中保存的原始消息重新
 * 入队（沿用原消息负载，无需按类型重建事件），达到上限则进入死信。</p>
 *
 * <p>已有专用恢复调度器的任务类型（PHOTO_AI、PHOTO_GEO_*、MUSIC_*、COMIC_PARSE、
 * READER_PARSE、FILE_PURGE、MEDIA_AUTO_IMPORT）不在本调度器范围内，避免双重恢复。</p>
 *
 * @author OmniNest
 */
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnExpression("'${omninest.runtime.role:api}' == 'scheduler' || "
        + "('${omninest.runtime.role:api}' == 'api' && ${omninest.runtime.embedded-worker-enabled:false})")
public class GenericTaskRecoveryScheduler {

    /** 需要通用心跳恢复的任务类型。 */
    private static final List<String> RECOVERED_TASK_TYPES = List.of(
            "PHOTO_SCAN",
            "PHOTO_THUMBNAILS",
            "EXTERNAL_IMPORT",
            "OFFLINE_DOWNLOAD",
            "MEDIA_SCRAPE",
            "VIDEO_TRANSCODE",
            "FILE_INDEX",
            "THUMBNAIL",
            "TEXT_EXTRACTION"
    );

    private static final int RECOVERY_BATCH_SIZE = 100;

    private final TaskRecordService taskRecordService;
    private final TaskDispatchRepository taskDispatchRepository;
    private final RabbitTemplate rabbitTemplate;

    @Value("${omninest.task.stale-heartbeat-seconds:600}")
    private long staleHeartbeatSeconds;

    /**
     * 扫描并恢复心跳超时的通用任务类型。
     */
    @Scheduled(fixedDelayString = "${omninest.task.recovery-interval-millis:60000}")
    public void recoverStaleTasks() {
        Instant cutoff = Instant.now().minus(
                Math.max(60L, staleHeartbeatSeconds),
                ChronoUnit.SECONDS
        );
        for (String taskType : RECOVERED_TASK_TYPES) {
            taskRecordService.listStaleRunningTaskIds(taskType, cutoff, RECOVERY_BATCH_SIZE)
                    .forEach(taskId -> recoverOne(taskId, taskType, cutoff));
        }
    }

    private void recoverOne(UUID taskId, String taskType, Instant cutoff) {
        try {
            StaleTaskRecovery recovery = taskRecordService.recoverStaleTask(
                    taskId,
                    taskType,
                    cutoff,
                    Instant.now(),
                    "WORKER_HEARTBEAT_TIMEOUT"
            );
            if (!recovery.recovered() || recovery.deadLetter()) {
                return;
            }
            republishOriginalMessage(taskId, taskType, recovery.nextRetryAt());
        } catch (RuntimeException exception) {
            log.error("通用任务心跳超时恢复失败: taskType={}, taskId={}", taskType, taskId, exception);
        }
    }

    /**
     * 将任务 Outbox 最近一次投递的原始消息按 nextRetryAt 重新入队。
     *
     * <p>发布在状态已置为 RETRY_WAIT 之后进行；发布失败时任务保持 RETRY_WAIT，
     * 等待下一轮调度重新裁决（recoverStaleTask 只处理 RUNNING，故需要直接补偿发布）。</p>
     */
    private void republishOriginalMessage(UUID taskId, String taskType, Instant nextRetryAt) {
        TaskDispatch dispatch = taskDispatchRepository.findFirstByTaskIdOrderByCreatedAtDesc(taskId)
                .orElse(null);
        if (dispatch == null) {
            taskRecordService.markDeadLetter(taskId, "WORKER_HEARTBEAT_TIMEOUT:OUTBOX_MISSING");
            log.warn("通用任务无 Outbox 记录可重投，转入死信: taskType={}, taskId={}", taskType, taskId);
            return;
        }
        Object payload = JSON.parse(dispatch.getPayload());
        taskRecordService.markRetryWait(taskId, "WORKER_HEARTBEAT_TIMEOUT", nextRetryAt);
        try {
            rabbitTemplate.convertAndSend(QueueNames.TASK_EXCHANGE, dispatch.getRoutingKey(), payload);
            log.warn("通用任务心跳超时已恢复重投: taskType={}, taskId={}, routingKey={}, nextRetryAt={}",
                    taskType, taskId, dispatch.getRoutingKey(), nextRetryAt);
        } catch (RuntimeException exception) {
            // 保持 RETRY_WAIT：下轮调度对 RETRY_WAIT 无裁决能力，管理员可通过任务页手动重试兜底。
            log.error("通用任务恢复重投失败，任务保持 RETRY_WAIT: taskType={}, taskId={}", taskType, taskId, exception);
        }
    }
}
