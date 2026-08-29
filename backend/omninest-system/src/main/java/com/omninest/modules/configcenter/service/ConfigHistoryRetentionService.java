package com.omninest.modules.configcenter.service;

import com.omninest.modules.configcenter.repository.ConfigHistoryRepository;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 按配置键保护最近版本并分批清理过期配置历史。
 *
 * @author OmniNest
 */
@Service
@RequiredArgsConstructor
public class ConfigHistoryRetentionService {
    private static final int CONFIG_KEY_PAGE_SIZE = 100;

    private final ConfigHistoryRepository configHistoryRepository;

    /**
     * 删除一批超过保留时间且不属于最近保护版本的配置历史。
     *
     * @param cutoff 截止时间
     * @param minimumVersions 每个配置键最少保留版本数
     * @param batchSize 单批删除数量
     * @return 删除记录数
     */
    @Transactional(rollbackFor = Exception.class)
    public int deleteExpiredBatch(Instant cutoff, int minimumVersions, int batchSize) {
        int normalizedMinimumVersions = Math.max(1, Math.min(minimumVersions, 100));
        int normalizedBatchSize = Math.max(1, Math.min(batchSize, 5000));
        List<UUID> candidateIds = new ArrayList<>(normalizedBatchSize);

        for (int page = 0; candidateIds.size() < normalizedBatchSize; page++) {
            List<String> configKeys = configHistoryRepository.findDistinctConfigKeysCreatedBefore(
                    cutoff,
                    PageRequest.of(page, CONFIG_KEY_PAGE_SIZE)
            );
            if (configKeys.isEmpty()) {
                break;
            }
            collectCandidates(
                    configKeys,
                    cutoff,
                    normalizedMinimumVersions,
                    normalizedBatchSize,
                    candidateIds
            );
            if (configKeys.size() < CONFIG_KEY_PAGE_SIZE) {
                break;
            }
        }

        if (candidateIds.isEmpty()) {
            return 0;
        }
        configHistoryRepository.deleteAllByIdInBatch(candidateIds);
        return candidateIds.size();
    }

    private void collectCandidates(
            List<String> configKeys,
            Instant cutoff,
            int minimumVersions,
            int batchSize,
            List<UUID> candidateIds
    ) {
        for (String configKey : configKeys) {
            int remaining = batchSize - candidateIds.size();
            if (remaining <= 0) {
                return;
            }
            List<UUID> protectedIds = configHistoryRepository.findRecentIdsByConfigKey(
                    configKey,
                    PageRequest.of(0, minimumVersions)
            );
            if (protectedIds.isEmpty()) {
                continue;
            }
            candidateIds.addAll(configHistoryRepository.findExpiredIdsExcluding(
                    configKey,
                    cutoff,
                    protectedIds,
                    PageRequest.of(0, remaining)
            ));
        }
    }
}
