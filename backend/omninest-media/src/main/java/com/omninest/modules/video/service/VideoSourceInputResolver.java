package com.omninest.modules.video.service;

import com.omninest.modules.file.dto.FileProcessInput;
import com.omninest.modules.file.service.FileQueryService;
import java.net.URI;
import java.time.Duration;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

/**
 * 将统一文件内容输入转换为 FFmpeg 容器可读取的地址。
 *
 * @author OmniNest
 */
@Service
public class VideoSourceInputResolver {
    private static final Duration PRESIGN_TTL = Duration.ofMinutes(35);
    private static final String MINIO = "MINIO";

    private final FileQueryService fileQueryService;
    private final S3Presigner dockerPresigner;

    /**
     * 创建视频源输入解析器。
     *
     * @param fileQueryService 文件查询服务
     * @param dockerPresigner Docker 网络地址使用的对象存储签名器
     */
    public VideoSourceInputResolver(
            FileQueryService fileQueryService,
            @Qualifier("dockerS3Presigner") S3Presigner dockerPresigner
    ) {
        this.fileQueryService = fileQueryService;
        this.dockerPresigner = dockerPresigner;
    }

    /**
     * 解析指定文件的 FFmpeg 容器输入。
     *
     * @param ownerUserId 所有者用户 ID
     * @param fileNodeId 文件节点 ID
     * @return MinIO 预签名 URL 或本地只读容器路径
     */
    public String resolveDockerInput(UUID ownerUserId, UUID fileNodeId) {
        FileProcessInput input = fileQueryService.createOwnedProcessInput(ownerUserId, fileNodeId);
        if (!MINIO.equals(input.providerType())) {
            return input.input();
        }
        return createDockerPresignedUrl(input.input());
    }

    private String createDockerPresignedUrl(String presignedUrl) {
        URI uri = URI.create(presignedUrl);
        String path = uri.getPath();
        int firstSlash = path.indexOf('/', 1);
        if (firstSlash < 0) {
            return presignedUrl;
        }
        String bucket = path.substring(1, firstSlash);
        String objectKey = path.substring(firstSlash + 1);
        return dockerPresigner.presignGetObject(builder -> builder
                .signatureDuration(PRESIGN_TTL)
                .getObjectRequest(request -> request.bucket(bucket).key(objectKey))
        ).url().toString();
    }
}
