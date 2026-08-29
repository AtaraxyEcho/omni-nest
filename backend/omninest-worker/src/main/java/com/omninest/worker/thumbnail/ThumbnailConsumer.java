package com.omninest.worker.thumbnail;

import com.omninest.worker.runtime.ConditionalOnWorkerRuntime;

import com.omninest.common.messaging.QueueNames;
import com.omninest.common.storage.ObjectStorageClient;
import com.omninest.common.storage.ObjectStorageKey;
import com.omninest.modules.file.event.FileUploadedEvent;
import com.omninest.modules.file.service.FileLifecycleGuard;
import com.omninest.modules.photos.service.PhotoThumbnailService;
import com.omninest.modules.photos.service.PhotoAdminService;
import com.rabbitmq.client.Channel;
import java.io.IOException;
import java.io.InputStream;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

/**
 * 缩略图生成消费者：对上传的图片文件自动生成缩略图。
 */
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnWorkerRuntime
public class ThumbnailConsumer {

    private static final Set<String> IMAGE_MIME_PREFIXES = Set.of("image/jpeg", "image/png", "image/gif", "image/bmp");

    private final ObjectStorageClient objectStorageClient;
    private final PhotoThumbnailService photoThumbnailService;
    private final PhotoAdminService photoAdminService;
    private final FileLifecycleGuard fileLifecycleGuard;

    @RabbitListener(queues = QueueNames.THUMBNAIL_QUEUE)
    public void handle(FileUploadedEvent event, Message message, Channel channel) throws IOException {
        long deliveryTag = message.getMessageProperties().getDeliveryTag();
        try {
            if (!isSupportedImage(event.mimeType())) {
                log.debug("跳过非图片文件缩略图生成: fileNodeId={}, mimeType={}", event.fileNodeId(), event.mimeType());
                channel.basicAck(deliveryTag, false);
                return;
            }
            if (!fileLifecycleGuard.isOwnedProcessable(event.ownerUserId(), event.fileNodeId())) {
                log.info("源文件已删除或正在永久删除，跳过缩略图任务: fileNodeId={}", event.fileNodeId());
                channel.basicAck(deliveryTag, false);
                return;
            }
            log.info("开始生成缩略图: fileNodeId={}, fileName={}", event.fileNodeId(), event.fileName());
            ObjectStorageKey key = new ObjectStorageKey(event.bucket(), event.objectKey());
            try (InputStream inputStream = objectStorageClient.getObject(key)) {
                UUID thumbnailId = photoThumbnailService.generateAndStore(
                        event.ownerUserId(), event.fileNodeId(), inputStream, event.fileName());
                if (thumbnailId != null) {
                    photoAdminService.attachCoverIfMissing(
                            event.ownerUserId(), event.fileNodeId(), thumbnailId);
                    log.info("缩略图生成完成: fileNodeId={}, thumbnailId={}", event.fileNodeId(), thumbnailId);
                } else {
                    log.info("缩略图生成跳过（不支持的格式）: fileNodeId={}", event.fileNodeId());
                }
            }
            channel.basicAck(deliveryTag, false);
        } catch (Exception e) {
            log.error("缩略图生成失败: fileNodeId={}", event.fileNodeId(), e);
            channel.basicNack(deliveryTag, false, false);
        }
    }

    private boolean isSupportedImage(String mimeType) {
        if (mimeType == null) {
            return false;
        }
        String lower = mimeType.toLowerCase(Locale.ROOT);
        return IMAGE_MIME_PREFIXES.stream().anyMatch(lower::startsWith);
    }
}
