package com.omninest.modules.user.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.omninest.modules.user.domain.AuthUser;
import com.omninest.modules.user.repository.AuthUserRepository;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/**
 * 用户存储写入服务测试。
 *
 * @author OmniNest
 */
class UserStorageCommandServiceTest {

    private static final UUID USER_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");

    private final AuthUserRepository authUserRepository = mock(AuthUserRepository.class);
    private final UserStorageCommandService service = new UserStorageCommandService(authUserRepository);

    /**
     * 验证减少用量时不会产生负数。
     */
    @Test
    void decrementUsageClampsToZero() {
        when(authUserRepository.decrementUsageAtomic(USER_ID, 200)).thenReturn(1);

        service.decrementUsage(USER_ID, 200);

        verify(authUserRepository).decrementUsageAtomic(USER_ID, 200);
    }

    /**
     * 验证校准只批量保存发生变化的用户。
     */
    @Test
    void reconcileUsageSavesChangedUsersInBatch() {
        UUID unchangedId = UUID.fromString("10000000-0000-0000-0000-000000000002");
        AuthUser changed = user(USER_ID, 100);
        AuthUser unchanged = user(unchangedId, 50);
        when(authUserRepository.findAllById(Map.of(USER_ID, 300L, unchangedId, 50L).keySet()))
                .thenReturn(List.of(changed, unchanged));

        int result = service.reconcileUsage(Map.of(USER_ID, 300L, unchangedId, 50L));

        assertThat(result).isEqualTo(1);
        verify(authUserRepository).saveAll(List.of(changed));
        assertThat(changed.getUsedBytes()).isEqualTo(300);
    }

    @Test
    void reconcileUsageTreatsMissingAggregateAsZero() {
        AuthUser changed = user(USER_ID, 100);
        when(authUserRepository.findAllById(Map.of(USER_ID, 0L).keySet()))
                .thenReturn(List.of(changed));

        int result = service.reconcileUsage(Map.of(USER_ID, 0L));

        assertThat(result).isEqualTo(1);
        assertThat(changed.getUsedBytes()).isZero();
        verify(authUserRepository).saveAll(List.of(changed));
    }

    private AuthUser user(UUID id, long usedBytes) {
        AuthUser user = new AuthUser();
        user.setId(id);
        user.setUsername("user");
        user.setUsedBytes(usedBytes);
        return user;
    }
}
