package com.omninest.worker.photos;

import com.omninest.modules.photos.event.PhotoAiEvent;
import com.omninest.modules.photos.event.PhotoAiEvent.Mode;
import com.omninest.modules.photos.service.PhotoAiTaskService;
import com.rabbitmq.client.Channel;
import java.io.IOException;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageProperties;

/**
 * 照片 AI 消费者消息确认测试。
 *
 * @author OmniNest
 */
class PhotoAiConsumerTest {

    private final PhotoAiTaskService taskService = Mockito.mock(PhotoAiTaskService.class);
    private final Channel channel = Mockito.mock(Channel.class);
    private final PhotoAiConsumer consumer = new PhotoAiConsumer(taskService);

    @Test
    void handleAcknowledgesCompletedTask() throws IOException {
        PhotoAiEvent event = event();

        consumer.handle(event, message(), channel);

        Mockito.verify(taskService).execute(event);
        Mockito.verify(channel).basicAck(1L, false);
        Mockito.verify(channel, Mockito.never()).basicNack(Mockito.anyLong(), Mockito.anyBoolean(), Mockito.anyBoolean());
    }

    @Test
    void handleRejectsFailedTaskForDeadLetterProcessing() throws IOException {
        PhotoAiEvent event = event();
        Mockito.doThrow(new IllegalStateException("sidecar unavailable"))
                .when(taskService).execute(event);

        consumer.handle(event, message(), channel);

        Mockito.verify(channel).basicNack(1L, false, false);
        Mockito.verify(channel, Mockito.never()).basicAck(Mockito.anyLong(), Mockito.anyBoolean());
    }

    private PhotoAiEvent event() {
        return new PhotoAiEvent(
                UUID.randomUUID(),
                UUID.randomUUID(),
                UUID.randomUUID(),
                Mode.SINGLE_PHOTO
        );
    }

    private Message message() {
        MessageProperties properties = new MessageProperties();
        properties.setDeliveryTag(1L);
        return new Message(new byte[0], properties);
    }
}
