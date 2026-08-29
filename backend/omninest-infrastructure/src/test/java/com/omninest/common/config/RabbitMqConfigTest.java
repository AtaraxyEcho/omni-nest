package com.omninest.common.config;

import com.omninest.common.messaging.QueueNames;
import java.time.Duration;
import java.util.Map;
import org.assertj.core.api.Assertions;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageProperties;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.support.converter.MessageConversionException;
import org.springframework.amqp.support.converter.MessageConverter;

/**
 * RabbitMQ 消息容量、过期时间和兼容队列声明测试。
 *
 * @author OmniNest
 */
class RabbitMqConfigTest {
    private final RabbitMessagingProperties properties = new RabbitMessagingProperties();
    private final RabbitMqConfig config = new RabbitMqConfig(properties);

    @BeforeEach
    void setUp() {
        properties.setMaximumMessageBytes(128);
        properties.setMessageTtl(Duration.ofMinutes(5));
        properties.setConsumerPrefetch(10);
    }

    @Test
    void messageConverterAppliesSizeMetadataAndExpiration() {
        MessageConverter converter = config.rabbitMessageConverter();
        MessageProperties messageProperties = new MessageProperties();

        Message message = converter.toMessage(Map.of("taskId", "task-1"), messageProperties);

        Assertions.assertThat(message.getBody()).isNotEmpty();
        Assertions.assertThat(message.getMessageProperties().getContentLength())
                .isEqualTo(message.getBody().length);
        Assertions.assertThat(message.getMessageProperties().getExpiration()).isEqualTo("300000");
    }

    @Test
    void messageConverterRejectsOversizedOutgoingAndIncomingBodies() {
        MessageConverter converter = config.rabbitMessageConverter();

        Assertions.assertThatThrownBy(() -> converter.toMessage(
                Map.of("payload", "x".repeat(256)),
                new MessageProperties()
        )).isInstanceOf(MessageConversionException.class)
                .hasMessageContaining("消息体超过容量限制");

        Message oversized = new Message(new byte[129], new MessageProperties());
        Assertions.assertThatThrownBy(() -> converter.fromMessage(oversized))
                .isInstanceOf(MessageConversionException.class)
                .hasMessageContaining("消息体超过容量限制");
    }

    @Test
    void durableQueueKeepsExistingDeadLetterArgumentsWithoutNewDeclarationLimits() {
        Queue queue = config.fileIndexQueue();

        Assertions.assertThat(queue.getName()).isEqualTo(QueueNames.FILE_INDEX_QUEUE);
        Assertions.assertThat(queue.getArguments())
                .containsEntry("x-dead-letter-exchange", QueueNames.DEAD_LETTER_EXCHANGE)
                .containsEntry("x-dead-letter-routing-key", QueueNames.DEAD_LETTER_ROUTING_KEY)
                .doesNotContainKeys("x-max-length", "x-max-length-bytes", "x-message-ttl");
    }

    @Test
    void configRefreshQueueUsesSupportedTransientQueueArguments() {
        Queue queue = config.configRefreshQueue();

        Assertions.assertThat(queue.isDurable()).isFalse();
        Assertions.assertThat(queue.isExclusive()).isTrue();
        Assertions.assertThat(queue.isAutoDelete()).isTrue();
        Assertions.assertThat(queue.getArguments()).doesNotContainKey("x-queue-master-locator");
    }
}
