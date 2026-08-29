package com.omninest.modules.file.service;

import com.omninest.common.config.ConfigValueProvider;
import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.modules.file.domain.SharedSpaceUsage;
import com.omninest.modules.file.dto.SharedSpaceUsageDto;
import com.omninest.modules.file.repository.SharedSpaceUsageRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 共享空间配额服务，管理共享空间的容量限制和用量统计。
 *
 * @author OmniNest
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class SharedSpaceQuotaService {

    private final SharedSpaceUsageRepository usageRepository;
    private final ConfigValueProvider configValueProvider;

    private static final String CONFIG_MAX_BYTES = "share.max-bytes";
    private static final String LEGACY_CONFIG_MAX_BYTES = "shared_space.max_bytes";
    // 数据库配置缺失时使用保守的 100GB 部署回退值；正常安装由 share.max-bytes 提供 300GB 默认值。
    private static final long DEFAULT_MAX_BYTES = 100L * 1024 * 1024 * 1024;

    /**
     * 检查共享空间是否有足够容量。
     */
    @Transactional(readOnly = true)
    public void checkQuota(long additionalBytes) {
        long maxBytes = getConfigLong(CONFIG_MAX_BYTES, LEGACY_CONFIG_MAX_BYTES, DEFAULT_MAX_BYTES);
        if (maxBytes <= 0) {
            return;
        }
        SharedSpaceUsage usage = getUsage();
        if (usage.getUsedBytes() + additionalBytes > maxBytes) {
            throw new BusinessException(ErrorCode.FILE_QUOTA_EXCEEDED, "共享空间容量不足");
        }
    }

    /**
     * 增加共享空间用量（乐观锁重试）。
     */
    @Transactional(rollbackFor = Exception.class)
    public void increaseUsage(long bytes) {
        for (int attempt = 1; attempt <= 3; attempt++) {
            try {
                SharedSpaceUsage usage = getUsage();
                usage.setUsedBytes(usage.getUsedBytes() + bytes);
                usage.setFileCount(usage.getFileCount() + 1);
                usageRepository.save(usage);
                return;
            } catch (ObjectOptimisticLockingFailureException e) {
                if (attempt == 3) {
                    log.error("共享空间用量更新失败（乐观锁冲突重试耗尽）", e);
                    throw e;
                }
                log.info("共享空间用量更新乐观锁冲突，第{}次重试", attempt);
            }
        }
    }

    /**
     * 减少共享空间用量（乐观锁重试）。
     */
    @Transactional(rollbackFor = Exception.class)
    public void decreaseUsage(long bytes) {
        for (int attempt = 1; attempt <= 3; attempt++) {
            try {
                SharedSpaceUsage usage = getUsage();
                usage.setUsedBytes(Math.max(0, usage.getUsedBytes() - bytes));
                usage.setFileCount(Math.max(0, usage.getFileCount() - 1));
                usageRepository.save(usage);
                return;
            } catch (ObjectOptimisticLockingFailureException e) {
                if (attempt == 3) {
                    log.error("共享空间用量更新失败（乐观锁冲突重试耗尽）", e);
                    throw e;
                }
                log.info("共享空间用量更新乐观锁冲突，第{}次重试", attempt);
            }
        }
    }

    /**
     * 获取共享空间用量 DTO。
     */
    @Transactional(readOnly = true)
    public SharedSpaceUsageDto getUsageDto() {
        SharedSpaceUsage usage = getUsage();
        long maxBytes = getConfigLong(CONFIG_MAX_BYTES, LEGACY_CONFIG_MAX_BYTES, DEFAULT_MAX_BYTES);
        return new SharedSpaceUsageDto(usage.getUsedBytes(), maxBytes, usage.getFileCount());
    }

    /**
     * 从 config_entries 读取 long 配置值。
     */
    private long getConfigLong(String key, String legacyKey, long defaultValue) {
        return configValueProvider.findByKey(key)
                .or(() -> configValueProvider.findByKey(legacyKey))
                .map(value -> {
                    try {
                        return Long.parseLong(value);
                    } catch (NumberFormatException e) {
                        log.warn("配置项{}值格式错误，使用默认值: {}", key, defaultValue);
                        return defaultValue;
                    }
                })
                .orElse(defaultValue);
    }

    private SharedSpaceUsage getUsage() {
        return usageRepository.findFirstBy()
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR, "共享空间用量记录不存在"));
    }
}
