package com.omninest.modules.configcenter.service;

import com.omninest.modules.configcenter.repository.ConfigHistoryRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.assertj.core.api.Assertions;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentMatchers;
import org.mockito.Mockito;
import org.springframework.data.domain.PageRequest;

/**
 * 配置历史最近版本保护与分批清理测试。
 *
 * @author OmniNest
 */
class ConfigHistoryRetentionServiceTest {
    private final ConfigHistoryRepository repository = Mockito.mock(ConfigHistoryRepository.class);
    private final ConfigHistoryRetentionService service = new ConfigHistoryRetentionService(repository);

    @Test
    void deleteExpiredBatchProtectsRecentVersionsPerConfigKey() {
        Instant cutoff = Instant.parse("2025-07-25T00:00:00Z");
        UUID protectedA = UUID.randomUUID();
        UUID protectedB = UUID.randomUUID();
        UUID expiredA = UUID.randomUUID();
        UUID expiredB = UUID.randomUUID();
        Mockito.when(repository.findDistinctConfigKeysCreatedBefore(cutoff, PageRequest.of(0, 100)))
                .thenReturn(List.of("feature.a", "feature.b"));
        Mockito.when(repository.findRecentIdsByConfigKey("feature.a", PageRequest.of(0, 2)))
                .thenReturn(List.of(protectedA));
        Mockito.when(repository.findRecentIdsByConfigKey("feature.b", PageRequest.of(0, 2)))
                .thenReturn(List.of(protectedB));
        Mockito.when(repository.findExpiredIdsExcluding(
                "feature.a",
                cutoff,
                List.of(protectedA),
                PageRequest.of(0, 2)
        )).thenReturn(List.of(expiredA));
        Mockito.when(repository.findExpiredIdsExcluding(
                "feature.b",
                cutoff,
                List.of(protectedB),
                PageRequest.of(0, 1)
        )).thenReturn(List.of(expiredB));

        int deleted = service.deleteExpiredBatch(cutoff, 2, 2);

        Assertions.assertThat(deleted).isEqualTo(2);
        Mockito.verify(repository).deleteAllByIdInBatch(List.of(expiredA, expiredB));
    }

    @Test
    void deleteExpiredBatchKeepsOnlyAvailableHistoryAsRollbackBaseline() {
        Instant cutoff = Instant.parse("2025-07-25T00:00:00Z");
        UUID protectedId = UUID.randomUUID();
        Mockito.when(repository.findDistinctConfigKeysCreatedBefore(cutoff, PageRequest.of(0, 100)))
                .thenReturn(List.of("feature.a"));
        Mockito.when(repository.findRecentIdsByConfigKey("feature.a", PageRequest.of(0, 20)))
                .thenReturn(List.of(protectedId));
        Mockito.when(repository.findExpiredIdsExcluding(
                ArgumentMatchers.eq("feature.a"),
                ArgumentMatchers.eq(cutoff),
                ArgumentMatchers.eq(List.of(protectedId)),
                ArgumentMatchers.any()
        )).thenReturn(List.of());

        int deleted = service.deleteExpiredBatch(cutoff, 20, 500);

        Assertions.assertThat(deleted).isZero();
        Mockito.verify(repository, Mockito.never()).deleteAllByIdInBatch(ArgumentMatchers.anyList());
    }
}
