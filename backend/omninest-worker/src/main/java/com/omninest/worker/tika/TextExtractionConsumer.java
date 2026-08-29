package com.omninest.worker.tika;

import com.omninest.worker.runtime.ConditionalOnWorkerRuntime;

import com.omninest.common.messaging.QueueNames;
import com.omninest.common.storage.ObjectStorageClient;
import com.omninest.common.storage.ObjectStorageKey;
import com.omninest.modules.file.event.FileUploadedEvent;
import com.omninest.modules.file.service.FileLifecycleGuard;
import com.omninest.modules.search.service.FileSearchIndexService;
import com.rabbitmq.client.Channel;
import java.io.IOException;
import java.io.InputStream;
import lombok.RequiredArgsConstructor;
import org.apache.tika.metadata.Metadata;
import org.apache.tika.parser.AutoDetectParser;
import org.apache.tika.parser.ParseContext;
import org.apache.tika.parser.Parser;
import org.apache.tika.sax.BodyContentHandler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

/**
 * 文本提取消费者，使用 Apache Tika 从文件中提取文本内容并写入 Lucene 索引。
 */
@Component
@RequiredArgsConstructor
@ConditionalOnWorkerRuntime
public class TextExtractionConsumer {

    private static final Logger log = LoggerFactory.getLogger(TextExtractionConsumer.class);
    private static final int MAX_CONTENT_LENGTH = 500_000;

    private final ObjectStorageClient objectStorageClient;
    private final FileSearchIndexService fileSearchIndexService;
    private final FileLifecycleGuard fileLifecycleGuard;

    @RabbitListener(queues = QueueNames.TEXT_EXTRACTION_QUEUE)
    public void handle(FileUploadedEvent event, Message message, Channel channel) throws IOException {
        long deliveryTag = message.getMessageProperties().getDeliveryTag();
        try {
            if (!fileLifecycleGuard.isOwnedProcessable(event.ownerUserId(), event.fileNodeId())) {
                log.info("源文件已删除或正在永久删除，跳过文本提取: fileNodeId={}", event.fileNodeId());
                channel.basicAck(deliveryTag, false);
                return;
            }
            log.info("收到文本提取任务: fileNodeId={}, fileName={}", event.fileNodeId(), event.fileName());
            ObjectStorageKey key = new ObjectStorageKey(event.bucket(), event.objectKey());
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
                        channel.basicAck(deliveryTag, false);
                        return;
                    }
                    fileSearchIndexService.indexFile(
                            event.fileNodeId(),
                            event.ownerUserId(),
                            event.fileName(),
                            extractedText
                    );
                    log.info("文本提取完成: fileNodeId={}, 文本长度={}", event.fileNodeId(), extractedText.length());
                } else {
                    log.info("文件无可提取文本: fileNodeId={}", event.fileNodeId());
                }
            }
            channel.basicAck(deliveryTag, false);
        } catch (Exception e) {
            log.error("文本提取失败: fileNodeId={}", event.fileNodeId(), e);
            channel.basicNack(deliveryTag, false, false);
        }
    }
}
