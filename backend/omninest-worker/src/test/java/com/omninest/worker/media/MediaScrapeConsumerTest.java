package com.omninest.worker.media;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.common.messaging.DomainEventPublisher;
import com.omninest.common.messaging.QueueNames;
import com.omninest.modules.task.service.TaskRecordService;
import com.omninest.modules.video.event.MediaScrapeRequestedEvent;
import com.omninest.modules.video.service.MovieScrapeExecutionService;
import com.rabbitmq.client.Channel;
import java.io.IOException;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageProperties;

/**
 * 媒体刮削消费者消息确认与重试编排测试。
 *
 * @author OmniNest
 */
class MediaScrapeConsumerTest {

    private static final UUID TASK_ID = UUID.fromString("40000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");
    private static final UUID FILE_ID = UUID.fromString("30000000-0000-0000-0000-000000000001");

    private final MovieScrapeExecutionService executionService = Mockito.mock(MovieScrapeExecutionService.class);
    private final TaskRecordService taskRecordService = Mockito.mock(TaskRecordService.class);
    private final DomainEventPublisher domainEventPublisher = Mockito.mock(DomainEventPublisher.class);
    private final Channel channel = Mockito.mock(Channel.class);
    private final MediaScrapeConsumer consumer = new MediaScrapeConsumer(
            executionService,
            taskRecordService,
            domainEventPublisher
    );

    @Test
    void handleAcknowledgesSuccessfulExecution() throws IOException {
        MediaScrapeRequestedEvent event = event();

        consumer.handle(event, message(), channel);

        Mockito.verify(executionService).execute(event);
        Mockito.verify(channel).basicAck(1L, false);
        Mockito.verify(channel, Mockito.never()).basicNack(Mockito.anyLong(), Mockito.anyBoolean(), Mockito.anyBoolean());
    }

    @Test
    void handleAcknowledgesWhenTaskWasAlreadyCleaned() throws IOException {
        MediaScrapeRequestedEvent event = event();
        Mockito.doThrow(new BusinessException(ErrorCode.TASK_NOT_FOUND, "任务不存在"))
                .when(executionService).execute(event);

        consumer.handle(event, message(), channel);

        Mockito.verify(channel).basicAck(1L, false);
        Mockito.verifyNoInteractions(taskRecordService, domainEventPublisher);
    }

    @Test
    void handleRequeuesRetryableFailureAndAcknowledgesOriginalMessage() throws IOException {
        MediaScrapeRequestedEvent event = event();
        Mockito.doThrow(new IllegalStateException("metadata provider unavailable"))
                .when(executionService).execute(event);
        Mockito.when(taskRecordService.retryCount(TASK_ID)).thenReturn(0);

        consumer.handle(event, message(), channel);

        Mockito.verify(taskRecordService).incrementRetryCount(TASK_ID);
        Mockito.verify(domainEventPublisher).publishTask(QueueNames.MEDIA_SCRAPE_ROUTING_KEY, event);
        Mockito.verify(channel).basicAck(1L, false);
    }

    private MediaScrapeRequestedEvent event() {
        return new MediaScrapeRequestedEvent(
                TASK_ID,
                OWNER_ID,
                FILE_ID,
                "测试影片",
                2026,
                null,
                null,
                false
        );
    }

    private Message message() {
        MessageProperties properties = new MessageProperties();
        properties.setDeliveryTag(1L);
        return new Message(new byte[0], properties);
    }
}
