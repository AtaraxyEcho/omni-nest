package com.omninest.modules.file.event;

import java.time.Instant;
import java.util.UUID;

/**
 * 文件上传完成事件。
 *
 * @param fileNodeId 文件节点 ID
 * @param fileObjectId 文件对象 ID
 * @param ownerUserId 所有者用户 ID
 * @param bucket 对象存储桶
 * @param objectKey 对象键
 * @param fileName 文件名
 * @param mimeType MIME 类型
 * @param sizeBytes 文件字节数
 * @param occurredAt 发生时间
 * @author OmniNest
 */
public record FileUploadedEvent(
        UUID fileNodeId,
        UUID fileObjectId,
        UUID ownerUserId,
        String bucket,
        String objectKey,
        String fileName,
        String mimeType,
        long sizeBytes,
        Instant occurredAt
) {
}
