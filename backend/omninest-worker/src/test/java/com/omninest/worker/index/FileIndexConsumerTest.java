package com.omninest.worker.index;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.modules.file.event.FileUploadedEvent;
import com.omninest.worker.file.FilePostProcessingTaskTracker;
import com.rabbitmq.client.Channel;
import java.io.IOException;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageProperties;

/**
 * 文件索引消费者消息编排测试。
 *
 * @author OmniNest
 */
class FileIndexConsumerTest {
    private final FileIndexTaskService taskService = Mockito.mock(FileIndexTaskService.class);
    private final FilePostProcessingTaskTracker taskTracker = Mockito.mock(FilePostProcessingTaskTracker.class);
    private final Channel channel = Mockito.mock(Channel.class);
    private FileIndexConsumer consumer;

    @BeforeEach
    void setUp() {
        consumer = new FileIndexConsumer(taskService, taskTracker);
        when(taskTracker.begin(any(), anyString(), any(), anyString()))
                .thenReturn(new FilePostProcessingTaskTracker.TrackedTask(null, false));
    }

    @Test
    void handleDelegatesTaskAndAcknowledgesMessage() throws IOException {
        FileUploadedEvent event = event();

        consumer.handle(event, message(), channel);

        Mockito.verify(taskService).process(event);
        Mockito.verify(channel).basicAck(1L, false);
    }

    @Test
    void handleRetriesViaTrackerWhenTaskFails() throws IOException {
        FileUploadedEvent event = event();
        Mockito.doThrow(new IllegalStateException("index unavailable"))
                .when(taskService)
                .process(event);

        consumer.handle(event, message(), channel);

        Mockito.verify(taskTracker).handleFailure(
                eq("FILE_INDEX"), anyString(), isNull(), eq(event), any(Exception.class));
        Mockito.verify(channel).basicAck(1L, false);
        Mockito.verify(channel, Mockito.never()).basicNack(Mockito.anyLong(), Mockito.anyBoolean(), Mockito.anyBoolean());
    }

    @Test
    void handleAcknowledgesWhenSourceFileIsPurging() throws IOException {
        FileUploadedEvent event = event();
        Mockito.doThrow(new BusinessException(ErrorCode.FILE_LIFECYCLE_CONFLICT, "文件正在永久删除"))
                .when(taskService)
                .process(event);

        consumer.handle(event, message(), channel);

        Mockito.verify(channel).basicAck(1L, false);
        Mockito.verify(channel, Mockito.never()).basicNack(Mockito.anyLong(), Mockito.anyBoolean(), Mockito.anyBoolean());
    }

    @Test
    void handleSkipsDuplicateMessageWhenClaimFails() throws IOException {
        FileUploadedEvent event = event();
        when(taskTracker.begin(any(), anyString(), any(), anyString()))
                .thenReturn(new FilePostProcessingTaskTracker.TrackedTask(UUID.randomUUID(), false));

        consumer.handle(event, message(), channel);

        Mockito.verify(taskService, Mockito.never()).process(any());
        Mockito.verify(channel).basicAck(1L, false);
    }

    private FileUploadedEvent event() {
        return new FileUploadedEvent(
                UUID.randomUUID(),
                UUID.randomUUID(),
                UUID.randomUUID(),
                "test-bucket",
                "test-object-key",
                "test-file.pdf",
                "application/pdf",
                1024L,
                Instant.now()
        );
    }

    private Message message() {
        MessageProperties properties = new MessageProperties();
        properties.setDeliveryTag(1L);
        return new Message(new byte[0], properties);
    }
}
