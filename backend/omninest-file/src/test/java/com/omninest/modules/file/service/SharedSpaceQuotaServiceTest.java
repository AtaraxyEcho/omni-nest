package com.omninest.modules.file.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.omninest.common.config.ConfigValueProvider;
import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.modules.file.domain.SharedSpaceUsage;
import com.omninest.modules.file.dto.SharedSpaceUsageDto;
import com.omninest.modules.file.repository.SharedSpaceUsageRepository;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.orm.ObjectOptimisticLockingFailureException;

/**
 * 共享空间配额服务测试。
 *
 * @author OmniNest
 */
class SharedSpaceQuotaServiceTest {

    private final SharedSpaceUsageRepository usageRepository = mock(SharedSpaceUsageRepository.class);
    private final ConfigValueProvider configValueProvider = mock(ConfigValueProvider.class);

    private SharedSpaceQuotaService service;

    @BeforeEach
    void setUp() {
        service = new SharedSpaceQuotaService(usageRepository, configValueProvider);
    }

    // ── checkQuota ─────────────────────────────────────────────────────

    @Nested
    @DisplayName("checkQuota()")
    class CheckQuotaTests {

        @Test
        @DisplayName("未超限：不抛异常")
        void checkQuota_withinLimit_doesNotThrow() {
            SharedSpaceUsage usage = usage(5000L, 5);
            when(usageRepository.findFirstBy()).thenReturn(Optional.of(usage));
            stubConfig("10000");

            service.checkQuota(3000L);
        }

        @Test
        @DisplayName("刚好满：不抛异常")
        void checkQuota_exactlyAtLimit_doesNotThrow() {
            SharedSpaceUsage usage = usage(7000L, 5);
            when(usageRepository.findFirstBy()).thenReturn(Optional.of(usage));
            stubConfig("10000");

            service.checkQuota(3000L);
        }

        @Test
        @DisplayName("超限：抛出 FILE_QUOTA_EXCEEDED")
        void checkQuota_exceedsLimit_throws() {
            SharedSpaceUsage usage = usage(8000L, 5);
            when(usageRepository.findFirstBy()).thenReturn(Optional.of(usage));
            stubConfig("10000");

            assertThatThrownBy(() -> service.checkQuota(3000L))
                    .isInstanceOf(BusinessException.class)
                    .extracting(ex -> ((BusinessException) ex).errorCode())
                    .isEqualTo(ErrorCode.FILE_QUOTA_EXCEEDED);
        }

        @Test
        @DisplayName("无配置时使用默认值 100GB")
        void checkQuota_noConfig_usesDefault() {
            SharedSpaceUsage usage = usage(50L * 1024 * 1024 * 1024, 100);
            when(usageRepository.findFirstBy()).thenReturn(Optional.of(usage));
            when(configValueProvider.findByKey("shared_space.max_bytes"))
                    .thenReturn(Optional.empty());

            // 50GB + 60GB = 110GB > 100GB default
            assertThatThrownBy(() -> service.checkQuota(60L * 1024 * 1024 * 1024))
                    .isInstanceOf(BusinessException.class)
                    .extracting(ex -> ((BusinessException) ex).errorCode())
                    .isEqualTo(ErrorCode.FILE_QUOTA_EXCEEDED);
        }

        @Test
        @DisplayName("0 表示无限制且不读取用量记录")
        void checkQuota_zeroLimit_isUnlimited() {
            stubConfig("0");

            service.checkQuota(Long.MAX_VALUE);

            verify(usageRepository, times(0)).findFirstBy();
        }
    }

    // ── increaseUsage ──────────────────────────────────────────────────

    @Nested
    @DisplayName("increaseUsage()")
    class IncreaseUsageTests {

        @Test
        @DisplayName("正常增加：usedBytes 和 fileCount 递增")
        void increaseUsage_normal_increments() {
            SharedSpaceUsage usage = usage(5000L, 5);
            when(usageRepository.findFirstBy()).thenReturn(Optional.of(usage));
            when(usageRepository.save(usage)).thenReturn(usage);

            service.increaseUsage(1024L);

            assertThat(usage.getUsedBytes()).isEqualTo(6024L);
            assertThat(usage.getFileCount()).isEqualTo(6L);
            verify(usageRepository).save(usage);
        }

        @Test
        @DisplayName("乐观锁冲突：重试最多 3 次")
        void increaseUsage_optimisticLock_retries() {
            // 每次 findSingleton 返回新的实例，模拟数据库读取
            when(usageRepository.findFirstBy())
                    .thenReturn(Optional.of(usage(5000L, 5)))
                    .thenReturn(Optional.of(usage(5000L, 5)))
                    .thenReturn(Optional.of(usage(5000L, 5)));
            when(usageRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
            // 前两次 save 抛出乐观锁异常
            when(usageRepository.save(any()))
                    .thenThrow(new ObjectOptimisticLockingFailureException(SharedSpaceUsage.class, 0))
                    .thenThrow(new ObjectOptimisticLockingFailureException(SharedSpaceUsage.class, 0))
                    .thenAnswer(inv -> inv.getArgument(0));

            service.increaseUsage(1024L);

            verify(usageRepository, times(3)).save(any());
        }

        @Test
        @DisplayName("乐观锁冲突 3 次后抛出异常")
        void increaseUsage_optimisticLockExhausted_throws() {
            SharedSpaceUsage usage = usage(5000L, 5);
            when(usageRepository.findFirstBy()).thenReturn(Optional.of(usage));
            when(usageRepository.save(usage))
                    .thenThrow(new ObjectOptimisticLockingFailureException(SharedSpaceUsage.class, 0))
                    .thenThrow(new ObjectOptimisticLockingFailureException(SharedSpaceUsage.class, 0))
                    .thenThrow(new ObjectOptimisticLockingFailureException(SharedSpaceUsage.class, 0));

            assertThatThrownBy(() -> service.increaseUsage(1024L))
                    .isInstanceOf(ObjectOptimisticLockingFailureException.class);
        }
    }

    // ── decreaseUsage ──────────────────────────────────────────────────

    @Nested
    @DisplayName("decreaseUsage()")
    class DecreaseUsageTests {

        @Test
        @DisplayName("正常减少：usedBytes 和 fileCount 递减")
        void decreaseUsage_normal_decrements() {
            SharedSpaceUsage usage = usage(5000L, 5);
            when(usageRepository.findFirstBy()).thenReturn(Optional.of(usage));
            when(usageRepository.save(usage)).thenReturn(usage);

            service.decreaseUsage(1024L);

            assertThat(usage.getUsedBytes()).isEqualTo(3976L);
            assertThat(usage.getFileCount()).isEqualTo(4L);
        }

        @Test
        @DisplayName("下限为零：usedBytes 不变负数")
        void decreaseUsage_belowZero_clampsToZero() {
            SharedSpaceUsage usage = usage(500L, 1);
            when(usageRepository.findFirstBy()).thenReturn(Optional.of(usage));
            when(usageRepository.save(usage)).thenReturn(usage);

            service.decreaseUsage(1024L);

            assertThat(usage.getUsedBytes()).isEqualTo(0L);
            assertThat(usage.getFileCount()).isEqualTo(0L);
        }

        @Test
        @DisplayName("fileCount 下限为零")
        void decreaseUsage_fileCountBelowZero_clampsToZero() {
            SharedSpaceUsage usage = usage(5000L, 0);
            when(usageRepository.findFirstBy()).thenReturn(Optional.of(usage));
            when(usageRepository.save(usage)).thenReturn(usage);

            service.decreaseUsage(1024L);

            assertThat(usage.getFileCount()).isEqualTo(0L);
        }
    }

    // ── getUsageDto ────────────────────────────────────────────────────

    @Nested
    @DisplayName("getUsageDto()")
    class GetUsageDtoTests {

        @Test
        @DisplayName("返回正确的 DTO")
        void getUsageDto_returnsCorrectDto() {
            SharedSpaceUsage usage = usage(5000L, 10);
            when(usageRepository.findFirstBy()).thenReturn(Optional.of(usage));
            stubConfig("20000");

            SharedSpaceUsageDto dto = service.getUsageDto();

            assertThat(dto.usedBytes()).isEqualTo(5000L);
            assertThat(dto.maxBytes()).isEqualTo(20000L);
            assertThat(dto.fileCount()).isEqualTo(10L);
        }

        @Test
        @DisplayName("用量记录不存在时抛出 INTERNAL_ERROR")
        void getUsageDto_noRecord_throws() {
            when(usageRepository.findFirstBy()).thenReturn(Optional.empty());

            assertThatThrownBy(() -> service.getUsageDto())
                    .isInstanceOf(BusinessException.class)
                    .extracting(ex -> ((BusinessException) ex).errorCode())
                    .isEqualTo(ErrorCode.INTERNAL_ERROR);
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────

    private SharedSpaceUsage usage(long usedBytes, long fileCount) {
        SharedSpaceUsage usage = new SharedSpaceUsage();
        usage.setId(UUID.randomUUID());
        usage.setUsedBytes(usedBytes);
        usage.setFileCount(fileCount);
        usage.setVersion(0);
        return usage;
    }

    private void stubConfig(String value) {
        when(configValueProvider.findByKey("shared_space.max_bytes"))
                .thenReturn(Optional.of(value));
    }
}
