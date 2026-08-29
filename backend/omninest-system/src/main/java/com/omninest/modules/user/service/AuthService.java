package com.omninest.modules.user.service;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.common.security.ActiveSessionRegistry;
import com.omninest.common.security.AuthenticationTokenPolicy;
import com.omninest.common.security.Roles;
import com.omninest.common.storage.ObjectStorageBuckets;
import com.omninest.common.storage.ObjectStorageClient;
import com.omninest.modules.user.domain.AuthActiveSession;
import com.omninest.modules.user.domain.AuthRole;
import com.omninest.modules.user.domain.AuthUser;
import com.omninest.modules.user.dto.AuthTokenResponse;
import com.omninest.modules.user.dto.LoginRequest;
import com.omninest.modules.user.dto.RegisterRequest;
import com.omninest.modules.user.dto.AuthUserDto;
import com.omninest.modules.user.util.AuthUserMapper;
import com.omninest.modules.user.repository.ActiveSessionRepository;
import com.omninest.modules.notification.port.NotificationPublisher;
import com.omninest.modules.user.repository.AuthRoleRepository;
import com.omninest.modules.user.repository.AuthUserRepository;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {
    private static final String TOKEN_TYPE = "Bearer";

    private final AuthUserRepository authUserRepository;
    private final AuthRoleRepository authRoleRepository;
    private final PasswordEncoder passwordEncoder;
    private final PasswordPolicy passwordPolicy;
    private final JwtEncoder jwtEncoder;
    private final JwtDecoder jwtDecoder;
    private final AuthenticationTokenPolicy authenticationTokenPolicy;
    private final ObjectStorageClient objectStorageClient;
    private final ObjectStorageBuckets objectStorageBuckets;
    private final SessionRevocationService sessionRevocationService;
    private final ActiveSessionRegistry activeSessionRegistry;
    private final LoginAuditService loginAuditService;
    private final ActiveSessionRepository activeSessionRepository;
    private final NotificationPublisher notificationService;

    private record LoginResult(AuthUser profile, UUID sessionId) {}

    @Transactional(rollbackFor = Exception.class)
    public AuthTokenResponse register(
            RegisterRequest request,
            String clientPlatform,
            String deviceId,
            String deviceName,
            String ipAddress,
            String userAgent
    ) {
        AuthUser profile = registerInternal(request);
        UUID sessionId = createActiveSession(
                profile,
                clientPlatform,
                deviceId,
                deviceName,
                ipAddress,
                false
        );
        auditLogin(profile, profile.getUsername(), clientPlatform, deviceId, deviceName,
                ipAddress, userAgent, "SUCCESS", null);
        profile.setLastLoginAt(Instant.now());
        authUserRepository.save(profile);
        log.info("用户注册成功: userId={}, username={}", profile.getId(), profile.getUsername());
        return issueToken(toDto(profile), sessionId);
    }

    @Transactional(rollbackFor = Exception.class)
    public AuthTokenResponse login(LoginRequest request, String clientPlatform,
                                   String deviceId, String deviceName,
                                   String ipAddress, String userAgent) {
        LoginResult result = loginInternal(request, clientPlatform, deviceId, deviceName, ipAddress, userAgent);
        log.info("用户登录成功: userId={}, platform={}, ip={}", result.profile().getId(), clientPlatform, ipAddress);
        return issueToken(toDto(result.profile()), result.sessionId());
    }

    private AuthUser registerInternal(RegisterRequest request) {
        String username = normalizeUsername(request.username());
        if (authUserRepository.existsByUsername(username)) {
            throw new BusinessException(ErrorCode.CONFLICT, "用户名已存在");
        }
        passwordPolicy.validate(username, request.password());
        AuthUser profile = new AuthUser();
        profile.setId(UUID.randomUUID());
        profile.setUsername(username);
        profile.setPasswordHash(passwordEncoder.encode(request.password()));
        profile.setDisplayName(normalizeDisplayName(request.displayName(), username));
        profile.setEmail(normalizeEmail(request.email()));
        profile.getRoles().add(defaultUserRole());
        return authUserRepository.save(profile);
    }

    private LoginResult loginInternal(LoginRequest request, String clientPlatform,
                                     String deviceId, String deviceName,
                                     String ipAddress, String userAgent) {
        String username = normalizeUsername(request.username());
        AuthUser profile = authUserRepository.findByUsername(username)
                .orElseThrow(() -> {
                    auditLogin(null, username, clientPlatform, deviceId, deviceName,
                            ipAddress, userAgent, "FAILED", "用户不存在");
                    return new BusinessException(ErrorCode.UNAUTHORIZED, "用户名或密码错误");
                });
        if (!"ACTIVE".equals(profile.getStatus())) {
            auditLogin(profile, username, clientPlatform, deviceId, deviceName,
                    ipAddress, userAgent, "DISABLED", "账号已被禁用");
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "账号已被禁用");
        }
        if (!passwordEncoder.matches(request.password(), profile.getPasswordHash())) {
            auditLogin(profile, username, clientPlatform, deviceId, deviceName,
                    ipAddress, userAgent, "FAILED", "密码错误");
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "用户名或密码错误");
        }

        boolean newDevice = isNewDevice(profile.getId(), clientPlatform, deviceId);
        UUID sessionId = createActiveSession(
                profile,
                clientPlatform,
                deviceId,
                deviceName,
                ipAddress,
                true
        );

        // 审计
        auditLogin(profile, username, clientPlatform, deviceId, deviceName,
                ipAddress, userAgent, "SUCCESS", null);

        if (newDevice) {
            notifyNewDevice(profile, clientPlatform, deviceName, ipAddress);
        }

        profile.setLastLoginAt(Instant.now());
        authUserRepository.save(profile);
        return new LoginResult(profile, sessionId);
    }

    private UUID createActiveSession(
            AuthUser profile,
            String clientPlatform,
            String deviceId,
            String deviceName,
            String ipAddress,
            boolean enforcePlatformMutex
    ) {
        UUID sessionId = UUID.randomUUID();
        if (enforcePlatformMutex) {
            enforceSamePlatformMutex(profile.getId(), clientPlatform, sessionId);
        }
        activeSessionRegistry.register(
                profile.getId(),
                clientPlatform,
                sessionId,
                authenticationTokenPolicy.refreshTokenTtl()
        );

        Instant issuedAt = Instant.now();
        AuthActiveSession session = new AuthActiveSession();
        session.setId(sessionId);
        session.setUserId(profile.getId());
        session.setClientPlatform(clientPlatform);
        session.setDeviceId(deviceId);
        session.setDeviceName(deviceName);
        session.setIpAddress(ipAddress);
        session.setIssuedAt(issuedAt);
        session.setExpiresAt(issuedAt.plus(authenticationTokenPolicy.refreshTokenTtl()));
        activeSessionRepository.save(session);
        return sessionId;
    }

    @Transactional(rollbackFor = Exception.class)
    public AuthTokenResponse refresh(String refreshToken) {
        String token = normalizeToken(refreshToken);
        Jwt jwt;
        try {
            jwt = jwtDecoder.decode(token);
        } catch (RuntimeException ex) {
            log.warn("JWT 解码失败: {}", ex.getMessage());
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "刷新凭证无效");
        }
        if (!"refresh".equals(jwt.getClaimAsString("token_use"))) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "刷新凭证无效");
        }
        UUID userId = parseUserId(jwt.getSubject());
        AuthUser profile = authUserRepository.findWithRolesById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.UNAUTHORIZED, "当前用户不存在"));
        if (!"ACTIVE".equals(profile.getStatus())) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "账号已被禁用");
        }

        UUID sessionId = parseSessionId(jwt.getClaimAsString("sid"));
        AuthActiveSession session = activeSessionRepository.findByIdAndUserId(sessionId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.UNAUTHORIZED, "活动会话不存在"));
        Instant now = Instant.now();
        if (session.isRevoked()) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "活动会话已撤销");
        }
        if (session.getExpiresAt() == null || !session.getExpiresAt().isAfter(now)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "活动会话已过期");
        }
        if (sessionRevocationService.isRevoked(userId, sessionId)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "会话已在其他设备登录");
        }
        session.setLastActiveAt(now);
        activeSessionRepository.save(session);
        return issueToken(toDto(profile), sessionId);
    }

    private AuthTokenResponse issueToken(AuthUserDto user, UUID sessionId) {
        Instant now = Instant.now();
        Instant accessExpiresAt = now.plus(authenticationTokenPolicy.accessTokenTtl());
        Instant refreshExpiresAt = now.plus(authenticationTokenPolicy.refreshTokenTtl());
        String accessToken = encodeToken(user, sessionId, now, accessExpiresAt, "access", true);
        String refreshToken = encodeToken(user, sessionId, now, refreshExpiresAt, "refresh", false);
        return new AuthTokenResponse(
                TOKEN_TYPE,
                accessToken,
                formatInstant(accessExpiresAt),
                refreshToken,
                formatInstant(refreshExpiresAt),
                user
        );
    }

    private String encodeToken(
            AuthUserDto user,
            UUID sessionId,
            Instant issuedAt,
            Instant expiresAt,
            String tokenUse,
            boolean includeAuthorities
    ) {
        JwtClaimsSet.Builder claims = JwtClaimsSet.builder()
                .subject(user.id().toString())
                .issuedAt(issuedAt)
                .expiresAt(expiresAt)
                .claim("token_use", tokenUse)
                .claim("sid", sessionId.toString());
        if (includeAuthorities) {
            claims.claim("username", user.username());
            claims.claim("role", user.role());
            claims.claim("roles", user.roles());
            claims.claim("permissions", user.permissions());
        }
        JwsHeader headers = JwsHeader.with(MacAlgorithm.HS256).build();
        return jwtEncoder.encode(JwtEncoderParameters.from(headers, claims.build())).getTokenValue();
    }

    /**
     * 同平台互斥：撤销同平台其他会话，并发布旧会话撤销结果。
     */
    private void enforceSamePlatformMutex(UUID userId, String clientPlatform, UUID newSessionId) {
        UUID oldSid = activeSessionRegistry.find(userId, clientPlatform).orElse(null);
        if (oldSid != null) {
            sessionRevocationService.revokeSession(userId, oldSid, authenticationTokenPolicy.refreshTokenTtl());
            activeSessionRepository.revokeByUserAndPlatformExcluding(
                    userId, clientPlatform, newSessionId, "同平台新设备登录");
            log.info("同平台互斥: userId={}, platform={}, 旧会话已撤销: {}", userId, clientPlatform, oldSid);
        }
    }

    /**
     * 判断是否为新设备登录。
     * 检查是否存在相同 deviceId 的未撤销会话，如果存在则为同一设备，否则为新设备。
     */
    private boolean isNewDevice(UUID userId, String clientPlatform, String deviceId) {
        if (deviceId == null || deviceId.isBlank()) {
            return false;
        }
        List<AuthActiveSession> existingSessions = activeSessionRepository
                .findByUserIdAndClientPlatformAndRevokedAtIsNull(userId, clientPlatform);
        return existingSessions.stream()
                .noneMatch(session -> deviceId.equals(session.getDeviceId()));
    }

    private void notifyNewDevice(
            AuthUser profile,
            String clientPlatform,
            String deviceName,
            String ipAddress
    ) {
        try {
            String deviceInfo = deviceName != null && !deviceName.isBlank()
                    ? deviceName : clientPlatform;
            notificationService.create(
                    profile.getId(),
                    "NEW_DEVICE_LOGIN",
                    "新设备登录",
                    "检测到新设备登录: " + deviceInfo + " (" + ipAddress + ")",
                    Map.of("platform", clientPlatform, "ip", ipAddress)
            );
        } catch (RuntimeException exception) {
            log.warn("发送新设备登录通知失败: userId={}", profile.getId(), exception);
        }
    }

    /**
     * 记录登录审计日志（独立事务，不随主事务回滚）。
     */
    private void auditLogin(AuthUser user, String username, String clientPlatform,
                            String deviceId, String deviceName,
                            String ipAddress, String userAgent,
                            String result, String failureReason) {
        loginAuditService.record(user, username, clientPlatform, deviceId, deviceName,
                ipAddress, userAgent, result, failureReason);
    }

    private String normalizeUsername(String rawUsername) {
        String username = rawUsername == null ? "" : rawUsername.trim();
        if (username.isEmpty()) {
            throw new BusinessException(ErrorCode.PARAM_ERROR, "用户名不能为空");
        }
        return username;
    }

    private String normalizeDisplayName(String rawDisplayName, String username) {
        String displayName = rawDisplayName == null ? "" : rawDisplayName.trim();
        return displayName.isEmpty() ? username : displayName;
    }

    private String normalizeEmail(String rawEmail) {
        String email = rawEmail == null ? "" : rawEmail.trim();
        return email.isEmpty() ? null : email;
    }

    private String normalizeToken(String rawToken) {
        String token = rawToken == null ? "" : rawToken.trim();
        if (token.isEmpty()) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "刷新凭证不能为空");
        }
        return token;
    }

    private UUID parseUserId(String subject) {
        try {
            return UUID.fromString(subject);
        } catch (RuntimeException ex) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "刷新凭证无效");
        }
    }

    private UUID parseSessionId(String sid) {
        if (sid == null || sid.isBlank()) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "刷新凭证缺少会话标识");
        }
        try {
            return UUID.fromString(sid);
        } catch (RuntimeException exception) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "刷新凭证会话标识无效");
        }
    }

    private String formatInstant(Instant instant) {
        return instant.truncatedTo(ChronoUnit.SECONDS).toString();
    }

    private AuthRole defaultUserRole() {
        return authRoleRepository.findByCode(Roles.MEMBER)
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR, "默认用户角色未初始化"));
    }

    private AuthUserDto toDto(AuthUser profile) {
        String avatarUrl = AuthUserMapper.resolveAvatarUrl(profile, objectStorageClient, objectStorageBuckets);
        return AuthUserMapper.toDto(profile, avatarUrl);
    }
}
