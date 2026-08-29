package com.omninest.worker.thumbnail;

import com.omninest.common.storage.ObjectStorageClient;
import com.omninest.common.storage.ObjectStorageKey;
import com.omninest.modules.file.event.FileUploadedEvent;
import com.omninest.modules.file.service.FileLifecycleGuard;
import com.omninest.modules.photos.service.PhotoThumbnailService;
import com.omninest.modules.photos.service.PhotoAdminService;
import com.rabbitmq.client.Channel;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageProperties;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * ThumbnailConsumer 单元测试。
 * 验证缩略图生成逻辑：图片文件触发生成，非图片文件跳过。
 */
@ExtendWith(MockitoExtension.class)
class ThumbnailConsumerTest {

    @Mock
    private ObjectStorageClient objectStorageClient;

    @Mock
    private PhotoThumbnailService photoThumbnailService;

    @Mock
    private PhotoAdminService photoAdminService;

    @Mock
    private FileLifecycleGuard fileLifecycleGuard;

    @Mock
    private Channel channel;

    @InjectMocks
    private ThumbnailConsumer thumbnailConsumer;

    @BeforeEach
    void allowFileProcessing() {
        lenient().when(fileLifecycleGuard.isOwnedProcessable(any(), any())).thenReturn(true);
    }

    /**
     * 构造测试用的文件上传事件。
     */
    private FileUploadedEvent createEvent(String fileName, String mimeType) {
        return new FileUploadedEvent(
                UUID.randomUUID(),
                UUID.randomUUID(),
                UUID.randomUUID(),
                "test-bucket",
                "test-object-key",
                fileName,
                mimeType,
                2048L,
                Instant.now()
        );
    }

    /**
     * 构造测试用的 RabbitMQ 消息。
     */
    private Message createMessage() {
        MessageProperties props = new MessageProperties();
        props.setDeliveryTag(1L);
        return new Message(new byte[0], props);
    }

    @Test
    @DisplayName("JPEG 图片应触发缩略图生成")
    void handle_withJpegImage_shouldGenerateThumbnail() throws IOException {
        FileUploadedEvent event = createEvent("photo.jpg", "image/jpeg");
        InputStream inputStream = new ByteArrayInputStream(new byte[100]);
        UUID thumbnailId = UUID.randomUUID();
        when(objectStorageClient.getObject(any(ObjectStorageKey.class))).thenReturn(inputStream);
        when(photoThumbnailService.generateAndStore(
                any(), any(), any(InputStream.class), any()
        )).thenReturn(thumbnailId);

        thumbnailConsumer.handle(event, createMessage(), channel);

        verify(photoThumbnailService).generateAndStore(
                eq(event.ownerUserId()),
                eq(event.fileNodeId()),
                any(InputStream.class),
                eq(event.fileName())
        );
        verify(photoAdminService).attachCoverIfMissing(
                eq(event.ownerUserId()), eq(event.fileNodeId()), any(UUID.class));
        verify(channel).basicAck(1L, false);
    }

    @Test
    @DisplayName("PNG 图片应触发缩略图生成")
    void handle_withPngImage_shouldGenerateThumbnail() throws IOException {
        FileUploadedEvent event = createEvent("icon.png", "image/png");
        InputStream inputStream = new ByteArrayInputStream(new byte[100]);
        when(objectStorageClient.getObject(any(ObjectStorageKey.class))).thenReturn(inputStream);
        when(photoThumbnailService.generateAndStore(
                any(), any(), any(InputStream.class), any()
        )).thenReturn(UUID.randomUUID());

        thumbnailConsumer.handle(event, createMessage(), channel);

        verify(photoThumbnailService).generateAndStore(
                eq(event.ownerUserId()),
                eq(event.fileNodeId()),
                any(InputStream.class),
                eq(event.fileName())
        );
        verify(channel).basicAck(1L, false);
    }

    @Test
    @DisplayName("WebP 图片应跳过缩略图生成")
    void handle_withWebpImage_shouldSkip() throws IOException {
        FileUploadedEvent event = createEvent("avatar.webp", "image/webp");

        thumbnailConsumer.handle(event, createMessage(), channel);

        verify(photoThumbnailService, never()).generateAndStore(
                any(), any(), any(), any()
        );
        verify(channel).basicAck(1L, false);
    }

    @Test
    @DisplayName("PDF 文件不应触发缩略图生成")
    void handle_withPdfFile_shouldSkip() throws IOException {
        FileUploadedEvent event = createEvent("doc.pdf", "application/pdf");

        thumbnailConsumer.handle(event, createMessage(), channel);

        verify(objectStorageClient, never()).getObject(any());
        verify(photoThumbnailService, never()).generateAndStore(
                any(), any(), any(), any()
        );
        verify(channel).basicAck(1L, false);
    }

    @Test
    @DisplayName("文本文件不应触发缩略图生成")
    void handle_withTextFile_shouldSkip() throws IOException {
        FileUploadedEvent event = createEvent("readme.txt", "text/plain");

        thumbnailConsumer.handle(event, createMessage(), channel);

        verify(objectStorageClient, never()).getObject(any());
        verify(photoThumbnailService, never()).generateAndStore(
                any(), any(), any(), any()
        );
        verify(channel).basicAck(1L, false);
    }

    @Test
    @DisplayName("mimeType 为 null 时不应触发缩略图生成")
    void handle_withNullMimeType_shouldSkip() throws IOException {
        FileUploadedEvent event = createEvent("unknown", null);

        thumbnailConsumer.handle(event, createMessage(), channel);

        verify(objectStorageClient, never()).getObject(any());
        verify(photoThumbnailService, never()).generateAndStore(
                any(), any(), any(), any()
        );
        verify(channel).basicAck(1L, false);
    }

    @Test
    @DisplayName("缩略图服务返回 null 时不抛异常")
    void handle_whenThumbnailServiceReturnsNull_shouldCompleteNormally() throws IOException {
        FileUploadedEvent event = createEvent("photo.jpg", "image/jpeg");
        InputStream inputStream = new ByteArrayInputStream(new byte[100]);
        when(objectStorageClient.getObject(any(ObjectStorageKey.class))).thenReturn(inputStream);
        when(photoThumbnailService.generateAndStore(
                any(), any(), any(InputStream.class), any()
        )).thenReturn(null);

        thumbnailConsumer.handle(event, createMessage(), channel);

        verify(photoThumbnailService).generateAndStore(
                eq(event.ownerUserId()),
                eq(event.fileNodeId()),
                any(InputStream.class),
                eq(event.fileName())
        );
        verify(channel).basicAck(1L, false);
    }

    @Test
    @DisplayName("对象存储抛出异常时应 nack 消息")
    void handle_whenStorageThrows_shouldNackMessage() throws IOException {
        FileUploadedEvent event = createEvent("photo.jpg", "image/jpeg");
        when(objectStorageClient.getObject(any(ObjectStorageKey.class)))
                .thenThrow(new RuntimeException("存储服务不可用"));

        thumbnailConsumer.handle(event, createMessage(), channel);

        verify(photoThumbnailService, never()).generateAndStore(
                any(), any(), any(), any()
        );
        verify(channel).basicNack(1L, false, false);
    }

    @Test
    @DisplayName("缩略图服务抛出异常时应 nack 消息")
    void handle_whenThumbnailServiceThrows_shouldNackMessage() throws IOException {
        FileUploadedEvent event = createEvent("photo.jpg", "image/jpeg");
        InputStream inputStream = new ByteArrayInputStream(new byte[100]);
        when(objectStorageClient.getObject(any(ObjectStorageKey.class))).thenReturn(inputStream);
        when(photoThumbnailService.generateAndStore(
                any(), any(), any(InputStream.class), any()
        )).thenThrow(new RuntimeException("图片处理失败"));

        thumbnailConsumer.handle(event, createMessage(), channel);

        verify(channel).basicNack(1L, false, false);
    }

    @Test
    @DisplayName("MIME 类型大小写不敏感匹配")
    void handle_withUppercaseMimeType_shouldStillGenerate() throws IOException {
        FileUploadedEvent event = createEvent("photo.JPG", "IMAGE/JPEG");
        InputStream inputStream = new ByteArrayInputStream(new byte[100]);
        when(objectStorageClient.getObject(any(ObjectStorageKey.class))).thenReturn(inputStream);
        when(photoThumbnailService.generateAndStore(
                any(), any(), any(InputStream.class), any()
        )).thenReturn(UUID.randomUUID());

        thumbnailConsumer.handle(event, createMessage(), channel);

        verify(photoThumbnailService).generateAndStore(
                eq(event.ownerUserId()),
                eq(event.fileNodeId()),
                any(InputStream.class),
                eq(event.fileName())
        );
        verify(channel).basicAck(1L, false);
    }
}
