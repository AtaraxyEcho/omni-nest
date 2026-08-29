package com.omninest.worker.index;

import com.omninest.worker.runtime.ConditionalOnWorkerRuntime;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.common.messaging.QueueNames;
import com.omninest.modules.file.event.FileUploadedEvent;
import com.rabbitmq.client.Channel;
import java.io.IOException;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

/**
 * 文件索引队列消费者。
 *
 * @author OmniNest
 */
@Component
@RequiredArgsConstructor
@ConditionalOnWorkerRuntime
public class FileIndexConsumer {
    private static final Logger log = LoggerFactory.getLogger(FileIndexConsumer.class);
    private final FileIndexTaskService taskService;

    /**
     * 处理文件索引消息并确认消费结果。
     *
     * @param event 文件上传事件
     * @param message AMQP 消息
     * @param channel RabbitMQ 通道
     * @throws IOException ACK 或 NACK 失败时抛出
     */
    @RabbitListener(queues = QueueNames.FILE_INDEX_QUEUE)
    public void handle(FileUploadedEvent event, Message message, Channel channel) throws IOException {
        long deliveryTag = message.getMessageProperties().getDeliveryTag();
        try {
            log.info("收到文件索引任务: fileNodeId={}, fileName={}", event.fileNodeId(), event.fileName());
            taskService.process(event);
            channel.basicAck(deliveryTag, false);
        } catch (BusinessException exception) {
            if (ErrorCode.FILE_NOT_FOUND.equals(exception.errorCode())
                    || ErrorCode.FILE_LIFECYCLE_CONFLICT.equals(exception.errorCode())) {
                log.info("源文件已删除或正在永久删除，跳过文件索引任务: fileNodeId={}", event.fileNodeId());
                channel.basicAck(deliveryTag, false);
                return;
            }
            log.error("文件索引业务处理失败: fileNodeId={}", event.fileNodeId(), exception);
            channel.basicNack(deliveryTag, false, false);
        } catch (Exception e) {
            log.error("文件索引处理失败: fileNodeId={}", event.fileNodeId(), e);
            channel.basicNack(deliveryTag, false, false);
        }
    }
}
