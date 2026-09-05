package com.omninest.worker.tika;

import com.omninest.worker.runtime.ConditionalOnWorkerRuntime;

import com.omninest.common.messaging.QueueNames;
import com.omninest.common.storage.ObjectStorageClient;
import com.omninest.common.storage.ObjectStorageKey;
import com.omninest.modules.file.event.FileUploadedEvent;
import com.omninest.modules.file.service.FileLifecycleGuard;
import com.omninest.modules.search.service.FileSearchIndexService;
import com.omninest.worker.file.FilePostProcessingTaskTracker;
import com.rabbitmq.client.Channel;
import java.io.IOException;
import java.io.InputStream;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.tika.metadata.Metadata;
import org.apache.tika.parser.AutoDetectParser;
import org.apache.tika.parser.ParseContext;
import org.apache.tika.parser.Parser;
import org.apache.tika.sax.BodyContentHandler;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

/**
 * 文本提取消费者，使用 Apache Tika 从文件中提取文本内容并写入 Lucene 索引。
 * 同步维护 sys_tasks 生命周期：领取 → 执行 → 完成 / 失败重试。
 */
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnWorkerRuntime
public class TextExtractionConsumer {

    private static final int MAX_CONTENT_LENGTH = 500_000;
    private static final String TASK_TYPE = "TEXT_EXTRACTION";

    private final ObjectStorageClient objectStorageClient;
    private final FileSearchIndexService fileSearchIndexService;
    private final FileLifecycleGuard fileLifecycleGuard;
    private final FilePostProcessingTaskTracker taskTracker;

    @RabbitListener(queues = QueueNames.TEXT_EXTRACTION_QUEUE)
    public void handle(FileUploadedEvent event, Message message, Channel channel) throws IOException {
        long deliveryTag = message.getMessageProperties().getDeliveryTag();
        FilePostProcessingTaskTracker.TrackedTask tracked =
                taskTracker.begin(event.ownerUserId(), TASK_TYPE, event.fileNodeId(), "EXTRACTING");
        if (tracked.shouldSkip()) {
            log.info("文本提取任务已被其他消费者领取，跳过重复处理: fileNodeId={}", event.fileNodeId());
            channel.basicAck(deliveryTag, false);
            return;
        }
        try {
            if (!fileLifecycleGuard.isOwnedProcessable(event.ownerUserId(), event.fileNodeId())) {
                log.info("源文件已删除或正在永久删除，跳过文本提取: fileNodeId={}", event.fileNodeId());
                taskTracker.complete(tracked.taskId(), Map.of("skipped", true, "reason", "SOURCE_DELETED"));
                channel.basicAck(deliveryTag, false);
                return;
            }
            log.info("收到文本提取任务: fileNodeId={}, fileName={}", event.fileNodeId(), event.fileName());
            ObjectStorageKey key = new ObjectStorageKey(event.bucket(), event.objectKey());
            int textLength = 0;
            try (InputStream inputStream = objectStorageClient.getObject(key)) {
                AutoDetectParser parser = new AutoDetectParser();
                BodyContentHandler handler = new BodyContentHandler(MAX_CONTENT_LENGTH);
                Metadata metadata = new Metadata();
                ParseContext context = new ParseContext();
                context.set(Parser.class, parser);
                parser.parse(inputStream, handler, metadata, context);
                String extractedText = handler.toString();
                if (extractedText != null && !extractedText.isBlank()) {
                    if (!fileLifecycleGuard.isOwnedProcessable(event.ownerUserId(), event.fileNodeId())) {
                        log.info("源文件在文本提取期间进入永久删除流程，放弃索引写入: fileNodeId={}",
                                event.fileNodeId());
                        taskTracker.complete(tracked.taskId(), Map.of("skipped", true, "reason", "SOURCE_DELETED"));
                        channel.basicAck(deliveryTag, false);
                        return;
                    }
                    fileSearchIndexService.indexFile(
                            event.fileNodeId(),
                            event.ownerUserId(),
                            event.fileName(),
                            extractedText
                    );
                    textLength = extractedText.length();
                    log.info("文本提取完成: fileNodeId={}, 文本长度={}", event.fileNodeId(), textLength);
                } else {
                    log.info("文件无可提取文本: fileNodeId={}", event.fileNodeId());
                }
            }
            taskTracker.complete(tracked.taskId(), Map.of("textLength", textLength));
            channel.basicAck(deliveryTag, false);
        } catch (Exception e) {
            log.error("文本提取失败: fileNodeId={}", event.fileNodeId(), e);
            taskTracker.handleFailure(TASK_TYPE, QueueNames.TEXT_EXTRACTION_ROUTING_KEY, tracked.taskId(), event, e);
            channel.basicAck(deliveryTag, false);
        }
    }
}
