package com.omninest.modules.photos.event;

import java.util.UUID;

/**
 * 照片索引事件，通过 RabbitMQ 发送到 Worker 进行 Lucene 索引。
 */
public record PhotoIndexEvent(UUID photoId, UUID ownerUserId) {
}
