package com.omninest.modules.user.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.omninest.common.error.BusinessException;
import com.omninest.common.security.ActiveSessionRegistry;
import com.omninest.common.security.AuthenticationTokenPolicy;
import com.omninest.common.security.Permissions;
import com.omninest.common.security.Roles;
import com.omninest.common.storage.ObjectStorageBuckets;
import com.omninest.common.storage.ObjectStorageClient;
import com.omninest.modules.user.domain.AuthActiveSession;
import com.omninest.modules.user.domain.AuthPermission;
import com.omninest.modules.user.domain.AuthRole;
import com.omninest.modules.user.domain.AuthUser;
import com.omninest.modules.user.dto.LoginRequest;
import com.omninest.modules.user.dto.RegisterRequest;
import com.omninest.modules.user.repository.ActiveSessionRepository;
import com.omninest.modules.user.repository.AuthRoleRepository;
import com.omninest.modules.notification.service.NotificationService;
import com.omninest.modules.user.repository.AuthUserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;

class AuthServiceTest {

    private final AuthUserRepository authUserRepository = mock(AuthUserRepository.class);
    private final AuthRoleRepository authRoleRepository = mock(AuthRoleRepository.class);
    private final SessionRevocationService sessionRevocationService = mock(SessionRevocationService.class);
    private final ActiveSessionRegistry activeSessionRegistry = mock(ActiveSessionRegistry.class);
    private final LoginAuditService loginAuditService = mock(LoginAuditService.class);
    private final ActiveSessionRepository activeSessionRepository = mock(ActiveSessionRepository.class);
    private final NotificationService notificationService = mock(NotificationService.class);
    private final ObjectStorageClient objectStorageClient = mock(ObjectStorageClient.class);
    private final ObjectStorageBuckets objectStorageBuckets = createObjectStorageBuckets();
    private final AuthenticationTokenPolicy authenticationTokenPolicy = mock(AuthenticationTokenPolicy.class);
    private final FixedJwtEncoder jwtEncoder = new FixedJwtEncoder();
    private final FixedJwtDecoder jwtDecoder = new FixedJwtDecoder();

    private AuthService service;

    @BeforeEach
    void setUp() {
        when(authenticationTokenPolicy.accessTokenTtl()).thenReturn(Duration.ofMinutes(30));
        when(authenticationTokenPolicy.refreshTokenTtl()).thenReturn(Duration.ofDays(30));
        service = new AuthService(
                authUserRepository,
                authRoleRepository,
                new BCryptPasswordEncoder(),
                new PasswordPolicy(),
                jwtEncoder,
                jwtDecoder,
                authenticationTokenPolicy,
                objectStorageClient,
                objectStorageBuckets,
                sessionRevocationService,
                activeSessionRegistry,
                loginAuditService,
                activeSessionRepository,
                notificationService
        );
    }

    private static ObjectStorageBuckets createObjectStorageBuckets() {
        ObjectStorageBuckets buckets = mock(ObjectStorageBuckets.class);
        when(buckets.derivedAssets()).thenReturn("derived-assets");
        return buckets;
    }

    // ========== 注册测试 ==========

    @Nested
    @DisplayName("register()")
    class RegisterTests {

        @Test
        @DisplayName("注册成功：创建 MEMBER 用户并返回 token")
        void registerCreatesMemberUserAndReturnsToken() {
            when(authUserRepository.existsByUsername("newuser")).thenReturn(false);
            AuthRole memberRole = role(Roles.MEMBER, "file:read");
            when(authRoleRepository.findByCode(Roles.MEMBER)).thenReturn(Optional.of(memberRole));
            when(authUserRepository.save(any(AuthUser.class))).thenAnswer(invocation -> {
                AuthUser profile = invocation.getArgument(0);
                if (profile.getId() == null) {
                    profile.setId(UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"));
                }
                return profile;
            });

            var token = service.register(
                    new RegisterRequest("newuser", "New User", "new@example.com", "secret123"),
                    "web",
                    "device-register",
                    "Chrome",
                    "192.168.1.10",
                    "Mozilla/5.0"
            );

            assertThat(token.accessToken()).isEqualTo("access-token");
            assertThat(token.refreshToken()).isEqualTo("refresh-token");
            assertThat(token.tokenType()).isEqualTo("Bearer");
            assertThat(token.user().username()).isEqualTo("newuser");
            assertThat(token.user().roles()).containsExactly(Roles.MEMBER);
            verify(activeSessionRepository).save(any(AuthActiveSession.class));
            verify(activeSessionRegistry).register(
                    any(UUID.class),
                    eq("web"),
                    any(UUID.class),
                    eq(Duration.ofDays(30))
            );
        }

        @Test
        @DisplayName("注册失败：用户名已存在")
        void registerFailsWhenUsernameExists() {
            when(authUserRepository.existsByUsername("existing")).thenReturn(true);

            assertThatThrownBy(() -> service.register(
                    new RegisterRequest("existing", "Existing", "ex@example.com", "pass"),
                    "native",
                    null,
                    null,
                    "127.0.0.1",
                    "test"
            ))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("用户名已存在");
        }
    }

    // ========== 登录测试 ==========

    @Nested
    @DisplayName("login()")
    class LoginTests {

        @Test
        @DisplayName("登录成功：签发含 sid 的 JWT，创建会话，记录审计")
        void loginSuccess() {
            AuthUser user = localUser("admin", new BCryptPasswordEncoder().encode("correct"));
            user.getRoles().add(role(Roles.ADMIN, Permissions.SYSTEM_CONFIG_MANAGE));
            when(authUserRepository.findByUsername("admin")).thenReturn(Optional.of(user));
            when(authUserRepository.save(user)).thenReturn(user);

            var token = service.login(
                    new LoginRequest("admin", "correct"),
                    "web", "device-001", "Chrome 120", "192.168.1.1", "Mozilla/5.0");

            assertThat(token.accessToken()).isNotBlank();
            assertThat(token.refreshToken()).isNotBlank();
            assertThat(token.user().username()).isEqualTo("admin");

            // 验证 sid 被写入 JWT claims
            JwtClaimsSet accessClaims = jwtEncoder.claimsFor("access");
            assertThat(accessClaims.getSubject()).isEqualTo(user.getId().toString());
            assertThat(accessClaims.getClaimAsString("sid")).isNotBlank();
            assertThat(accessClaims.getClaimAsStringList("roles")).containsExactly("ADMIN");

            // 验证审计记录
            verify(loginAuditService).record(eq(user), eq("admin"), eq("web"), eq("device-001"),
                    eq("Chrome 120"), eq("192.168.1.1"), eq("Mozilla/5.0"), eq("SUCCESS"), eq(null));

            // 验证会话创建
            verify(activeSessionRepository).save(any(AuthActiveSession.class));

            // 验证 Redis 活跃会话写入
            verify(activeSessionRegistry).register(
                    eq(user.getId()),
                    eq("web"),
                    any(UUID.class),
                    any(Duration.class)
            );
        }

        @Test
        @DisplayName("登录失败：密码错误，记录 FAILED 审计")
        void loginFailsWithWrongPassword() {
            AuthUser user = localUser("admin", new BCryptPasswordEncoder().encode("correct"));
            when(authUserRepository.findByUsername("admin")).thenReturn(Optional.of(user));

            assertThatThrownBy(() -> service.login(
                    new LoginRequest("admin", "wrong"), "web", null, null, "127.0.0.1", "test"))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("用户名或密码错误");

            verify(loginAuditService).record(eq(user), eq("admin"), eq("web"), any(), any(),
                    eq("127.0.0.1"), eq("test"), eq("FAILED"), eq("密码错误"));
        }

        @Test
        @DisplayName("登录失败：用户不存在，记录 FAILED 审计")
        void loginFailsWithNonExistentUser() {
            when(authUserRepository.findByUsername("ghost")).thenReturn(Optional.empty());

            assertThatThrownBy(() -> service.login(
                    new LoginRequest("ghost", "pass"), "web", null, null, "127.0.0.1", "test"))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("用户名或密码错误");

            // user 参数为 null（用户不存在）
            verify(loginAuditService).record(eq(null), eq("ghost"), eq("web"), any(), any(),
                    eq("127.0.0.1"), eq("test"), eq("FAILED"), eq("用户不存在"));
        }

        @Test
        @DisplayName("登录失败：账号已禁用")
        void loginFailsWhenAccountDisabled() {
            AuthUser user = localUser("admin", new BCryptPasswordEncoder().encode("pass"));
            user.setStatus("DISABLED");
            when(authUserRepository.findByUsername("admin")).thenReturn(Optional.of(user));

            assertThatThrownBy(() -> service.login(
                    new LoginRequest("admin", "pass"), "web", null, null, "127.0.0.1", "test"))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("账号已被禁用");

            verify(loginAuditService).record(eq(user), eq("admin"), eq("web"), any(), any(),
                    eq("127.0.0.1"), eq("test"), eq("DISABLED"), eq("账号已被禁用"));
        }

        @Test
        @DisplayName("同平台互斥：新登录撤销旧会话")
        void loginRevokesSamePlatformSession() {
            AuthUser user = localUser("admin", new BCryptPasswordEncoder().encode("pass"));
            user.getRoles().add(role(Roles.MEMBER, "file:read"));
            UUID oldSessionId = UUID.fromString("11111111-1111-1111-1111-111111111111");
            when(authUserRepository.findByUsername("admin")).thenReturn(Optional.of(user));
            when(authUserRepository.save(user)).thenReturn(user);
            when(activeSessionRegistry.find(user.getId(), "android")).thenReturn(Optional.of(oldSessionId));

            service.login(new LoginRequest("admin", "pass"), "android", "new-device", "Pixel 8", "10.0.0.1", "okhttp");

            // 验证旧会话被加入黑名单
            verify(sessionRevocationService).revokeSession(
                    eq(user.getId()),
                    eq(oldSessionId),
                    any(Duration.class)
            );
            // 验证旧会话在 DB 中被撤销
            verify(activeSessionRepository).revokeByUserAndPlatformExcluding(
                    eq(user.getId()), eq("android"), any(UUID.class), eq("同平台新设备登录"));
        }

        @Test
        @DisplayName("跨平台不互斥：Android 登录不影响 Web 会话")
        void loginDoesNotRevokeCrossPlatformSession() {
            AuthUser user = localUser("admin", new BCryptPasswordEncoder().encode("pass"));
            user.getRoles().add(role(Roles.MEMBER, "file:read"));
            when(authUserRepository.findByUsername("admin")).thenReturn(Optional.of(user));
            when(authUserRepository.save(user)).thenReturn(user);
            // Android 没有旧会话
            when(activeSessionRegistry.find(user.getId(), "android")).thenReturn(Optional.empty());

            service.login(new LoginRequest("admin", "pass"), "android", "device", "Pixel", "10.0.0.1", "okhttp");

            // 不应撤销任何会话
            verify(sessionRevocationService, never()).revokeSession(any(), any(), any());
            verify(activeSessionRepository, never()).revokeByUserAndPlatformExcluding(any(), any(), any(), any());
        }

        @Test
        @DisplayName("同一设备再次登录不发送新设备通知")
        void loginDoesNotNotifyKnownDevice() {
            AuthUser user = localUser("admin", new BCryptPasswordEncoder().encode("pass"));
            AuthActiveSession knownSession = activeSession(user.getId());
            knownSession.setDeviceId("known-device");
            when(authUserRepository.findByUsername("admin")).thenReturn(Optional.of(user));
            when(authUserRepository.save(user)).thenReturn(user);
            when(activeSessionRepository.findByUserIdAndClientPlatformAndRevokedAtIsNull(
                    user.getId(), "android"))
                    .thenReturn(List.of(knownSession));

            service.login(
                    new LoginRequest("admin", "pass"),
                    "android",
                    "known-device",
                    "Pixel",
                    "10.0.0.1",
                    "okhttp"
            );

            verifyNoInteractions(notificationService);
        }

        @Test
        @DisplayName("缺少设备标识时不发送新设备通知")
        void loginDoesNotNotifyWithoutDeviceId() {
            AuthUser user = localUser("admin", new BCryptPasswordEncoder().encode("pass"));
            when(authUserRepository.findByUsername("admin")).thenReturn(Optional.of(user));
            when(authUserRepository.save(user)).thenReturn(user);

            service.login(
                    new LoginRequest("admin", "pass"),
                    "web",
                    null,
                    "Browser",
                    "10.0.0.1",
                    "Mozilla/5.0"
            );

            verifyNoInteractions(notificationService);
        }
    }

    // ========== 刷新测试 ==========

    @Nested
    @DisplayName("refresh()")
    class RefreshTests {

        @Test
        @DisplayName("刷新成功：返回新 token")
        void refreshSuccess() {
            AuthUser user = localUser("admin", new BCryptPasswordEncoder().encode("pass"));
            user.getRoles().add(role(Roles.MEMBER, "file:read"));
            when(authUserRepository.findWithRolesById(UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")))
                    .thenReturn(Optional.of(user));
            AuthActiveSession session = activeSession(user.getId());
            when(activeSessionRepository.findByIdAndUserId(session.getId(), user.getId()))
                    .thenReturn(Optional.of(session));
            when(sessionRevocationService.isRevoked(any(), any())).thenReturn(false);

            var token = service.refresh("refresh-token");

            assertThat(token.accessToken()).isNotBlank();
            assertThat(token.refreshToken()).isNotBlank();
        }

        @Test
        @DisplayName("刷新失败：会话已被撤销")
        void refreshFailsWhenSessionRevoked() {
            AuthUser user = localUser("admin", new BCryptPasswordEncoder().encode("pass"));
            when(authUserRepository.findWithRolesById(UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")))
                    .thenReturn(Optional.of(user));
            AuthActiveSession session = activeSession(user.getId());
            when(activeSessionRepository.findByIdAndUserId(session.getId(), user.getId()))
                    .thenReturn(Optional.of(session));
            when(sessionRevocationService.isRevoked(any(), any())).thenReturn(true);

            assertThatThrownBy(() -> service.refresh("refresh-token"))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("会话已在其他设备登录");
        }

        @Test
        @DisplayName("刷新失败：活动会话不存在")
        void refreshFailsWhenSessionIsMissing() {
            AuthUser user = localUser("admin", new BCryptPasswordEncoder().encode("pass"));
            when(authUserRepository.findWithRolesById(user.getId())).thenReturn(Optional.of(user));
            UUID sessionId = UUID.fromString("22222222-2222-2222-2222-222222222222");
            when(activeSessionRepository.findByIdAndUserId(sessionId, user.getId()))
                    .thenReturn(Optional.empty());

            assertThatThrownBy(() -> service.refresh("refresh-token"))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("活动会话不存在");
        }

        @Test
        @DisplayName("刷新失败：数据库会话已撤销")
        void refreshFailsWhenDatabaseSessionIsRevoked() {
            AuthUser user = localUser("admin", new BCryptPasswordEncoder().encode("pass"));
            AuthActiveSession session = activeSession(user.getId());
            session.setRevokedAt(Instant.now());
            when(authUserRepository.findWithRolesById(user.getId())).thenReturn(Optional.of(user));
            when(activeSessionRepository.findByIdAndUserId(session.getId(), user.getId()))
                    .thenReturn(Optional.of(session));

            assertThatThrownBy(() -> service.refresh("refresh-token"))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("活动会话已撤销");
        }

        @Test
        @DisplayName("刷新失败：数据库会话已过期")
        void refreshFailsWhenDatabaseSessionIsExpired() {
            AuthUser user = localUser("admin", new BCryptPasswordEncoder().encode("pass"));
            AuthActiveSession session = activeSession(user.getId());
            session.setExpiresAt(Instant.now().minusSeconds(1));
            when(authUserRepository.findWithRolesById(user.getId())).thenReturn(Optional.of(user));
            when(activeSessionRepository.findByIdAndUserId(session.getId(), user.getId()))
                    .thenReturn(Optional.of(session));

            assertThatThrownBy(() -> service.refresh("refresh-token"))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("活动会话已过期");
        }

        @Test
        @DisplayName("刷新失败：无效 token")
        void refreshFailsWithInvalidToken() {
            assertThatThrownBy(() -> service.refresh("invalid-token"))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("刷新凭证无效");
        }

        @Test
        @DisplayName("刷新失败：账号已禁用")
        void refreshFailsWhenAccountDisabled() {
            AuthUser user = localUser("admin", new BCryptPasswordEncoder().encode("pass"));
            user.setStatus("DISABLED");
            when(authUserRepository.findWithRolesById(UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")))
                    .thenReturn(Optional.of(user));

            assertThatThrownBy(() -> service.refresh("refresh-token"))
                    .isInstanceOf(BusinessException.class)
                    .hasMessageContaining("账号已被禁用");
        }
    }

    // ========== 辅助方法 ==========

    private AuthUser localUser(String username, String passwordHash) {
        AuthUser profile = new AuthUser();
        profile.setId(UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"));
        profile.setUsername(username);
        profile.setDisplayName(username);
        profile.setEmail(username + "@example.com");
        profile.setPasswordHash(passwordHash);
        profile.setStatus("ACTIVE");
        return profile;
    }

    private AuthRole role(String code, String permissionCode) {
        AuthPermission permission = new AuthPermission();
        permission.setId(UUID.randomUUID());
        permission.setCode(permissionCode);
        permission.setName(permissionCode);
        permission.setModule("system");
        permission.setEnabled(true);

        AuthRole role = new AuthRole();
        role.setId(UUID.randomUUID());
        role.setCode(code);
        role.setName(code);
        role.setEnabled(true);
        role.getPermissions().add(permission);
        return role;
    }

    private AuthActiveSession activeSession(UUID userId) {
        AuthActiveSession session = new AuthActiveSession();
        session.setId(UUID.fromString("22222222-2222-2222-2222-222222222222"));
        session.setUserId(userId);
        session.setClientPlatform("web");
        session.setIssuedAt(Instant.now().minusSeconds(60));
        session.setExpiresAt(Instant.now().plus(Duration.ofDays(1)));
        return session;
    }

    /**
     * 固定 JWT 编码器，记录 claims 供断言使用。
     */
    private static class FixedJwtEncoder implements JwtEncoder {
        private final Map<String, JwtClaimsSet> claimsByTokenUse = new HashMap<>();

        @Override
        public Jwt encode(JwtEncoderParameters parameters) {
            JwtClaimsSet claims = parameters.getClaims();
            String tokenUse = claims.getClaimAsString("token_use");
            claimsByTokenUse.put(tokenUse, claims);
            String tokenValue = "refresh".equals(tokenUse) ? "refresh-token" : "access-token";
            return new Jwt(
                    tokenValue,
                    Instant.parse("2026-05-29T00:00:00Z"),
                    Instant.parse("2026-05-29T01:00:00Z"),
                    Map.of("alg", "HS256"),
                    Map.of("sub", "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")
            );
        }

        private JwtClaimsSet claimsFor(String tokenUse) {
            return claimsByTokenUse.get(tokenUse);
        }
    }

    /**
     * 固定 JWT 解码器，返回预设的 refresh token claims。
     */
    private static class FixedJwtDecoder implements JwtDecoder {
        @Override
        public Jwt decode(String token) throws JwtException {
            if (!"refresh-token".equals(token)) {
                throw new JwtException("invalid refresh token");
            }
            return new Jwt(
                    token,
                    Instant.parse("2026-05-29T00:00:00Z"),
                    Instant.parse("2026-06-28T00:00:00Z"),
                    Map.of("alg", "HS256"),
                    Map.of(
                            "sub", "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
                            "token_use", "refresh",
                            "sid", "22222222-2222-2222-2222-222222222222"
                    )
            );
        }
    }
}
