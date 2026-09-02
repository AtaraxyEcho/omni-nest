package com.omninest.modules.user.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.omninest.common.error.BusinessException;
import com.omninest.modules.user.domain.AuditLog;
import com.omninest.modules.user.domain.AuthActiveSession;
import com.omninest.modules.user.domain.AuthLoginAudit;
import com.omninest.modules.user.domain.AuthUser;
import com.omninest.modules.user.repository.ActiveSessionRepository;
import com.omninest.modules.user.repository.AuditLogAdminRepository;
import com.omninest.modules.user.repository.AuthLoginAuditRepository;
import com.omninest.modules.user.repository.AuthUserRepository;
import com.omninest.modules.user.repository.TaskRecordAdminRepository;
import java.time.Instant;
import java.util.Collections;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;

/**
 * 管理端分页查询服务测试。
 *
 * @author OmniNest
 */
class AdminOperationsPagingServiceTest {
    private final TaskRecordAdminRepository taskRepository = mock(TaskRecordAdminRepository.class);
    private final AuditLogAdminRepository auditRepository = mock(AuditLogAdminRepository.class);
    private final ActiveSessionRepository sessionRepository = mock(ActiveSessionRepository.class);
    private final AuthLoginAuditRepository loginAuditRepository = mock(AuthLoginAuditRepository.class);
    private final AuthUserRepository userRepository = mock(AuthUserRepository.class);
    private final AdminOperationsPagingService service = new AdminOperationsPagingService(
            taskRepository,
            auditRepository,
            sessionRepository,
            loginAuditRepository,
            userRepository
    );

    @Test
    void taskPageBoundsInputAndMapsStableProjection() {
        UUID taskId = UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
        List<Object[]> rows = Collections.singletonList(new Object[]{
                taskId, "FILE_INDEX", "FAILED", 40, "file.index", "失败", 2,
                Instant.parse("2026-08-25T08:00:00Z"), Instant.parse("2026-08-25T08:01:00Z")
        });
        when(taskRepository.findPage(0, 100, "FAILED", "FILE_INDEX", "%index%"))
                .thenReturn(new TaskRecordAdminRepository.TaskPage(rows, 101));

        var result = service.taskPage(-1, 500, "failed", "file_index", " INDEX ");

        assertThat(result.page()).isZero();
        assertThat(result.size()).isEqualTo(100);
        assertThat(result.totalElements()).isEqualTo(101);
        assertThat(result.totalPages()).isEqualTo(2);
        assertThat(result.items()).extracting("id").containsExactly(taskId);
    }

    @Test
    void logPageReturnsLastLegalPageWhenRequestedPageIsEmpty() {
        AuditLog audit = new AuditLog();
        audit.setId(UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"));
        audit.setAction("ADMIN_CONFIG_UPDATE");
        audit.setResourceType("config_entries");
        audit.setCreatedAt(Instant.parse("2026-08-25T08:00:00Z"));
        when(auditRepository.searchAdminLogs("ADMIN_CONFIG_UPDATE", "%config%", PageRequest.of(9, 25)))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(9, 25), 26));
        when(auditRepository.searchAdminLogs("ADMIN_CONFIG_UPDATE", "%config%", PageRequest.of(1, 25)))
                .thenReturn(new PageImpl<>(List.of(audit), PageRequest.of(1, 25), 26));

        var result = service.logPage(9, 25, "admin_config_update", "config");

        assertThat(result.page()).isEqualTo(1);
        assertThat(result.items()).extracting("id").containsExactly(audit.getId());
    }

    @Test
    void sessionPageFiltersInRepositoryAndResolvesUsernamesInBatch() {
        UUID userId = UUID.fromString("cccccccc-cccc-cccc-cccc-cccccccccccc");
        AuthActiveSession session = new AuthActiveSession();
        session.setId(UUID.fromString("dddddddd-dddd-dddd-dddd-dddddddddddd"));
        session.setUserId(userId);
        session.setClientPlatform("web");
        session.setExpiresAt(Instant.parse("2026-08-26T08:00:00Z"));
        AuthUser user = new AuthUser();
        user.setId(userId);
        user.setUsername("admin");
        when(sessionRepository.searchAdminSessions(
                eq("ACTIVE"),
                eq("web"),
                eq("%admin%"),
                any(Instant.class),
                eq(PageRequest.of(0, 25, Sort.by(Sort.Direction.DESC, "lastActiveAt")))
        )).thenReturn(new PageImpl<>(List.of(session), PageRequest.of(0, 25), 1));
        when(userRepository.findAllById(Set.of(userId))).thenReturn(List.of(user));

        var result = service.sessionPage(0, 25, "active", "WEB", "admin", "lastActiveAt");

        assertThat(result.items()).extracting("username").containsExactly("admin");
        verify(userRepository).findAllById(Set.of(userId));
    }

    @Test
    void loginAuditPageMapsFilteredResult() {
        AuthLoginAudit audit = new AuthLoginAudit();
        audit.setId(UUID.fromString("eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee"));
        audit.setUserId(UUID.fromString("ffffffff-ffff-ffff-ffff-ffffffffffff"));
        audit.setUsername("admin");
        audit.setLoginResult("FAILED");
        audit.setClientPlatform("android");
        audit.setCreatedAt(Instant.parse("2026-08-25T08:00:00Z"));
        when(loginAuditRepository.searchAdminAudits(
                "FAILED", "android", "%admin%", PageRequest.of(0, 25)
        )).thenReturn(new PageImpl<>(List.of(audit), PageRequest.of(0, 25), 1));

        var result = service.loginAuditPage(0, 25, "failed", "ANDROID", "admin");

        assertThat(result.items()).extracting("loginResult").containsExactly("FAILED");
    }

    @Test
    void pageQueriesRejectExcessiveSearchLength() {
        assertThatThrownBy(() -> service.logPage(0, 25, "", "x".repeat(201)))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("200");
    }
}
