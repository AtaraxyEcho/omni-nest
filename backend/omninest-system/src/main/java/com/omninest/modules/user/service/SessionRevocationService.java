package com.omninest.modules.user.service;

import com.omninest.common.security.SessionRevocationCache;
import com.omninest.common.security.SessionRevocationChecker;
import com.omninest.modules.user.domain.SessionRevocationEntity;
import com.omninest.modules.user.repository.SessionRevocationJpaRepository;
import java.time.Duration;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 编排会话撤销记录、正命中缓存和安全降级判定。
 *
 * @author OmniNest
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SessionRevocationService implements SessionRevocationChecker {

    private static final Duration DEFAULT_REVOCATION_TTL = Duration.ofDays(30);

    private final SessionRevocationJpaRepository repository;
    private final SessionRevocationCache cache;
    private final TransactionTemplate transactionTemplate;

    /**
     * 撤销单个会话，并将撤销结果写入持久层和缓存。
     *
     * @param userId 用户标识
     * @param sessionId 会话标识
     * @param ttl 撤销缓存保留时间
     */
    public void revokeSession(UUID userId, UUID sessionId, Duration ttl) {
        try {
            transactionTemplate.executeWithoutResult(status -> repository.save(entity(userId, sessionId)));
        } catch (RuntimeException exception) {
            log.error("数据库会话撤销写入失败: userId={}, sessionId={}", userId, sessionId, exception);
        }
        publishRevocations(userId, List.of(sessionId), ttl);
    }

    /**
     * 在调用方事务中记录一组已撤销会话。
     *
     * @param userId 用户标识
     * @param sessionIds 会话标识集合
     */
    @Transactional(propagation = Propagation.MANDATORY, rollbackFor = Exception.class)
    public void recordRevocations(UUID userId, Collection<UUID> sessionIds) {
        if (sessionIds == null || sessionIds.isEmpty()) {
            return;
        }
        repository.saveAll(entities(userId, sessionIds));
    }

    /**
     * 发布已提交的会话撤销结果，使其可被安全链即时判定。
     *
     * @param userId 用户标识
     * @param sessionIds 会话标识集合
     * @param ttl 撤销缓存保留时间
     */
    public void publishRevocations(UUID userId, Collection<UUID> sessionIds, Duration ttl) {
        cache.markRevoked(userId, sessionIds, ttl);
    }

    /**
     * {@inheritDoc}
     */
    @Override
    public boolean isRevoked(UUID userId, UUID sessionId) {
        if (cache.contains(userId, sessionId)) {
            return true;
        }
        try {
            boolean revoked = repository.existsByUserIdAndSessionId(userId, sessionId);
            if (revoked) {
                publishRevocations(userId, List.of(sessionId), DEFAULT_REVOCATION_TTL);
            }
            return revoked;
        } catch (RuntimeException exception) {
            log.error("数据库会话撤销查询失败，拒绝当前会话: userId={}", userId, exception);
            return true;
        }
    }

    private List<SessionRevocationEntity> entities(UUID userId, Collection<UUID> sessionIds) {
        return sessionIds.stream().map(sessionId -> entity(userId, sessionId)).toList();
    }

    private SessionRevocationEntity entity(UUID userId, UUID sessionId) {
        return new SessionRevocationEntity(null, userId, sessionId, null);
    }
}
