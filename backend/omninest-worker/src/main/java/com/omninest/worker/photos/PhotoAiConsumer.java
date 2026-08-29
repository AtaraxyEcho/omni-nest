package com.omninest.worker.photos;

import com.omninest.worker.runtime.ConditionalOnWorkerRuntime;

import com.omninest.common.messaging.QueueNames;
import com.omninest.modules.photos.event.PhotoAiEvent;
import com.omninest.modules.photos.service.PhotoAiTaskService;
import com.rabbitmq.client.Channel;
import java.io.IOException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

/**
 * 照片 AI 异步任务消费者，负责调用任务编排服务并确认消息结果。
 *
 * @author OmniNest
 */
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnWorkerRuntime
public class PhotoAiConsumer {

    private final PhotoAiTaskService photoAiTaskService;

    /**
     * 执行照片 AI 任务并确认消息结果。
     *
     * @param event 照片 AI 任务事件
     * @param message AMQP 消息
     * @param channel RabbitMQ 通道
     * @throws IOException ACK 或 NACK 失败时抛出
     */
    @RabbitListener(queues = QueueNames.PHOTO_AI_QUEUE)
    public void handle(PhotoAiEvent event, Message message, Channel channel) throws IOException {
        long deliveryTag = message.getMessageProperties().getDeliveryTag();
        try {
            log.info(
                    "收到照片 AI 任务: taskId={}, photoId={}, ownerUserId={}, mode={}",
                    event.taskId(),
                    event.photoId(),
                    event.ownerUserId(),
                    event.mode()
            );
            photoAiTaskService.execute(event);
            channel.basicAck(deliveryTag, false);
        } catch (Exception e) {
            log.error("照片 AI 任务失败: taskId={}, photoId={}", event.taskId(), event.photoId(), e);
            channel.basicNack(deliveryTag, false, false);
        }
    }
}
