package com.omninest.worker.index;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.modules.file.event.FileRestoredEvent;
import com.rabbitmq.client.Channel;
import java.io.IOException;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.mockito.Mockito;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageProperties;

/**
 * 文件恢复消费者编排测试。
 *
 * @author OmniNest
 */
class FileRestoreIndexConsumerTest {

    private final FileIndexTaskService taskService = Mockito.mock(FileIndexTaskService.class);
    private final FileRestoreDerivedAssetService derivedAssetService = Mockito.mock(
            FileRestoreDerivedAssetService.class
    );
    private final Channel channel = Mockito.mock(Channel.class);
    private final FileRestoreIndexConsumer consumer = new FileRestoreIndexConsumer(taskService, derivedAssetService);

    @Test
    void handleRepairsDerivedAssetsBeforeIndexingAndAcknowledges() throws IOException {
        FileRestoredEvent event = event();

        consumer.handle(event, message(), channel);

        InOrder order = Mockito.inOrder(derivedAssetService, taskService, channel);
        order.verify(derivedAssetService).validateAndRepair(event);
        order.verify(taskService).processRestored(event);
        order.verify(channel).basicAck(1L, false);
    }

    @Test
    void handleAcknowledgesWhenFileEnteredPurgeAgain() throws IOException {
        FileRestoredEvent event = event();
        Mockito.doThrow(new BusinessException(ErrorCode.FILE_LIFECYCLE_CONFLICT, "文件正在永久删除"))
                .when(derivedAssetService)
                .validateAndRepair(event);

        consumer.handle(event, message(), channel);

        Mockito.verify(channel).basicAck(1L, false);
        Mockito.verify(taskService, Mockito.never()).processRestored(event);
    }

    @Test
    void handleDeadLettersMissingPhysicalObject() throws IOException {
        FileRestoredEvent event = event();
        Mockito.doThrow(new BusinessException(ErrorCode.FILE_OBJECT_MISSING, "文件对象缺失"))
                .when(derivedAssetService)
                .validateAndRepair(event);

        consumer.handle(event, message(), channel);

        Mockito.verify(channel).basicNack(1L, false, false);
        Mockito.verify(channel, Mockito.never()).basicAck(Mockito.anyLong(), Mockito.anyBoolean());
        Mockito.verify(taskService, Mockito.never()).processRestored(event);
    }

    private FileRestoredEvent event() {
        return new FileRestoredEvent(UUID.randomUUID(), UUID.randomUUID(), "photo.jpg", Instant.now());
    }

    private Message message() {
        MessageProperties properties = new MessageProperties();
        properties.setDeliveryTag(1L);
        return new Message(new byte[0], properties);
    }
}
