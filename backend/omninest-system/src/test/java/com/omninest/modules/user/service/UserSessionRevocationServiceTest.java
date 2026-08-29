package com.omninest.modules.user.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.omninest.modules.user.domain.AuthActiveSession;
import com.omninest.modules.user.repository.ActiveSessionRepository;
import java.time.Duration;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * 用户会话批量撤销服务测试。
 *
 * @author OmniNest
 */
class UserSessionRevocationServiceTest {

    private static final UUID USER_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");
    private static final UUID SESSION_ID = UUID.fromString("20000000-0000-0000-0000-000000000001");

    private final ActiveSessionRepository activeSessionRepository = Mockito.mock(ActiveSessionRepository.class);
    private final SessionRevocationService sessionRevocationService = Mockito.mock(SessionRevocationService.class);
    private final UserSessionRevocationService service = new UserSessionRevocationService(
            activeSessionRepository,
            sessionRevocationService
    );

    @Test
    void blacklistIsWrittenOnlyAfterTransactionCommit() {
        AuthActiveSession session = new AuthActiveSession();
        session.setId(SESSION_ID);
        session.setUserId(USER_ID);
        Mockito.when(activeSessionRepository.findByUserIdInAndRevokedAtIsNull(List.of(USER_ID)))
                .thenReturn(List.of(session));
        TransactionSynchronizationManager.initSynchronization();
        try {
            service.revokeAll(List.of(USER_ID), "权限变更");

            Mockito.verify(sessionRevocationService).recordRevocations(
                    USER_ID,
                    List.of(SESSION_ID)
            );
            Mockito.verify(sessionRevocationService, Mockito.never()).publishRevocations(
                    Mockito.any(),
                    Mockito.anyCollection(),
                    Mockito.any()
            );
            List<TransactionSynchronization> synchronizations =
                    TransactionSynchronizationManager.getSynchronizations();
            assertThat(synchronizations).hasSize(1);
            synchronizations.forEach(TransactionSynchronization::afterCommit);
            Mockito.verify(sessionRevocationService).publishRevocations(
                    USER_ID,
                    List.of(SESSION_ID),
                    Duration.ofDays(30)
            );
            Mockito.verify(activeSessionRepository).revokeByUserIdIn(List.of(USER_ID), "权限变更");
        } finally {
            TransactionSynchronizationManager.clearSynchronization();
        }
    }
}
