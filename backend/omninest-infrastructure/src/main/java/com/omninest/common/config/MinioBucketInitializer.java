package com.omninest.common.config;

import io.minio.BucketExistsArgs;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

/**
 * 应用启动时自动创建业务使用的 MinIO bucket。
 *
 * @author OmniNest
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class MinioBucketInitializer implements ApplicationRunner {

    private final MinioClient minioClient;
    private final MinioProperties minioProperties;

    @Override
    public void run(ApplicationArguments args) {
        MinioProperties.Buckets buckets = minioProperties.getBuckets();
        List<String> bucketNames = List.of(
                buckets.getUserFiles(),
                buckets.getDerivedAssets(),
                buckets.getQuarantine()
        );
        for (String bucketName : bucketNames) {
            ensureBucket(bucketName);
        }
    }

    private void ensureBucket(String bucketName) {
        try {
            boolean exists = minioClient.bucketExists(
                    BucketExistsArgs.builder().bucket(bucketName).build()
            );
            if (!exists) {
                minioClient.makeBucket(
                        MakeBucketArgs.builder().bucket(bucketName).build()
                );
                log.info("MinIO bucket 已创建: {}", bucketName);
            }
        } catch (Exception e) {
            log.error("检查或创建 MinIO bucket 失败: {}", bucketName, e);
        }
    }
}
