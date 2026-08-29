package com.omninest.worker.video;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.modules.video.event.TranscodeRequestedEvent;
import com.omninest.modules.video.service.TranscodeExecutionService;
import com.rabbitmq.client.Channel;
import java.io.IOException;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageProperties;

/**
 * 转码消费者消息确认与执行分支测试。
 *
 * @author OmniNest
 */
class TranscodeConsumerTest {

    private static final UUID TASK_ID = UUID.fromString("40000000-0000-0000-0000-000000000001");
    private static final UUID VIDEO_ID = UUID.fromString("50000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");

    private final TranscodeExecutionService executionService = Mockito.mock(TranscodeExecutionService.class);
    private final Channel channel = Mockito.mock(Channel.class);
    private final TranscodeConsumer consumer = new TranscodeConsumer(executionService);

    @Test
    void handleExecutesDefaultTranscodeAndAcknowledges() throws IOException {
        TranscodeRequestedEvent event = event(false, false);

        consumer.handle(event, message(), channel);

        Mockito.verify(executionService).execute(TASK_ID, VIDEO_ID, OWNER_ID);
        Mockito.verify(channel).basicAck(1L, false);
    }

    @Test
    void handleExecutesAudioTranscodeAndAcknowledges() throws IOException {
        TranscodeRequestedEvent event = event(true, false);

        consumer.handle(event, message(), channel);

        Mockito.verify(executionService).executeAudioTranscode(TASK_ID, VIDEO_ID, OWNER_ID, true);
        Mockito.verify(channel).basicAck(1L, false);
    }

    @Test
    void handleExecutesWebOptimizeAndAcknowledges() throws IOException {
        TranscodeRequestedEvent event = event(false, true);

        consumer.handle(event, message(), channel);

        Mockito.verify(executionService).executeWebOptimize(TASK_ID, VIDEO_ID, OWNER_ID, true);
        Mockito.verify(channel).basicAck(1L, false);
    }

    @Test
    void handleAcknowledgesWhenTaskWasAlreadyCleaned() throws IOException {
        TranscodeRequestedEvent event = event(false, false);
        Mockito.doThrow(new BusinessException(ErrorCode.TASK_NOT_FOUND, "任务不存在"))
                .when(executionService).execute(TASK_ID, VIDEO_ID, OWNER_ID);

        consumer.handle(event, message(), channel);

        Mockito.verify(channel).basicAck(1L, false);
        Mockito.verify(channel, Mockito.never()).basicNack(Mockito.anyLong(), Mockito.anyBoolean(), Mockito.anyBoolean());
    }

    @Test
    void handleNacksUnexpectedFailure() throws IOException {
        TranscodeRequestedEvent event = event(false, false);
        Mockito.doThrow(new IllegalStateException("transcoder unavailable"))
                .when(executionService).execute(TASK_ID, VIDEO_ID, OWNER_ID);

        consumer.handle(event, message(), channel);

        Mockito.verify(channel).basicNack(1L, false, false);
        Mockito.verify(channel, Mockito.never()).basicAck(Mockito.anyLong(), Mockito.anyBoolean());
    }

    private TranscodeRequestedEvent event(boolean audioOnly, boolean webOptimize) {
        return new TranscodeRequestedEvent(TASK_ID, VIDEO_ID, OWNER_ID, audioOnly, webOptimize);
    }

    private Message message() {
        MessageProperties properties = new MessageProperties();
        properties.setDeliveryTag(1L);
        return new Message(new byte[0], properties);
    }
}
