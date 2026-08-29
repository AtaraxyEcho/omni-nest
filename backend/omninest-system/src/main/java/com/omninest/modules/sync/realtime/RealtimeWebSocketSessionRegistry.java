package com.omninest.modules.sync.realtime;

import com.omninest.common.security.SessionRevocationChecker;
import com.omninest.modules.sync.config.SyncEventProperties;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.annotation.PostConstruct;
import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.WebSocketHandlerDecorator;
import org.springframework.web.socket.handler.WebSocketHandlerDecoratorFactory;

/**
 * 跟踪当前 API 实例的原始 WebSocket 会话及认证生命周期。
 *
 * @author OmniNest
 */
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(
        prefix = "omninest.runtime",
        name = "role",
        havingValue = "api",
        matchIfMissing = true
)
public class RealtimeWebSocketSessionRegistry implements WebSocketHandlerDecoratorFactory {
    private static final String ACTIVE_SESSION_METRIC = "omninest.sync.realtime.sessions.active";
    private static final String REJECTED_SESSION_METRIC = "omninest.sync.realtime.sessions.rejected";
    private static final long CAPACITY_WARNING_INTERVAL_NANOS = Duration.ofMinutes(1).toNanos();
    private static final CloseStatus CAPACITY_EXCEEDED_STATUS = new CloseStatus(1013, "Service capacity exceeded");

    private final SessionRevocationChecker sessionRevocationChecker;
    private final SyncEventProperties properties;
    private final MeterRegistry meterRegistry;
    private final Map<String, SessionContext> sessions = new ConcurrentHashMap<>();
    private final AtomicInteger activeSessionCount = new AtomicInteger();
    private final AtomicLong lastCapacityWarningNanos = new AtomicLong(Long.MIN_VALUE);

    @PostConstruct
    void registerMetrics() {
        Gauge.builder(ACTIVE_SESSION_METRIC, activeSessionCount, AtomicInteger::get)
                .description("当前 API 实例的活跃 WebSocket 会话数量")
                .register(meterRegistry);
    }

    /**
     * 装饰 WebSocket 处理器以登记和移除底层连接。
     *
     * @param handler 原始处理器
     * @return 会话跟踪处理器
     */
    @Override
    public WebSocketHandler decorate(WebSocketHandler handler) {
        return new WebSocketHandlerDecorator(handler) {
            @Override
            public void afterConnectionEstablished(WebSocketSession session) throws Exception {
                if (!tryAcquireSessionSlot()) {
                    rejectForCapacity(session);
                    return;
                }
                boolean registered = false;
                try {
                    SessionContext previous = sessions.putIfAbsent(
                            session.getId(),
                            SessionContext.connected(session, Instant.now())
                    );
                    if (previous != null) {
                        activeSessionCount.decrementAndGet();
                        rejectForCapacity(session);
                        return;
                    }
                    registered = true;
                    super.afterConnectionEstablished(session);
                } catch (Exception | Error exception) {
                    if (registered) {
                        unregister(session.getId(), session);
                    }
                    throw exception;
                }
            }

            @Override
            public void afterConnectionClosed(WebSocketSession session, CloseStatus closeStatus) throws Exception {
                if (unregister(session.getId(), session)) {
                    super.afterConnectionClosed(session, closeStatus);
                }
            }
        };
    }

    /**
     * 将完成 STOMP CONNECT 认证的信息关联到底层会话。
     *
     * @param sessionId WebSocket 会话标识
     * @param userId 用户标识
     * @param sid 登录会话标识
     * @param expiresAt JWT 过期时间
     */
    public void authorize(String sessionId, UUID userId, UUID sid, Instant expiresAt) {
        SessionContext current = sessions.get(sessionId);
        if (current == null || !current.session().isOpen()) {
            throw new RealtimeAuthenticationException("WebSocket 会话不存在或已关闭");
        }
        if (!sessions.replace(sessionId, current, current.authorized(userId, sid, expiresAt))) {
            throw new RealtimeAuthenticationException("WebSocket 会话已关闭");
        }
    }

    /**
     * 定期关闭未及时认证、JWT 已过期或 sid 已撤销的连接。
     */
    @Scheduled(fixedDelayString = "${omninest.sync.realtime.session-audit-millis:10000}")
    public void closeInvalidSessions() {
        Instant now = Instant.now();
        sessions.forEach((sessionId, context) -> {
            if (shouldClose(context, now)) {
                close(sessionId, context.session());
            }
        });
    }

    private boolean shouldClose(SessionContext context, Instant now) {
        if (!context.session().isOpen()) {
            return true;
        }
        if (context.userId() == null || context.sid() == null || context.expiresAt() == null) {
            long timeout = Math.max(1L, properties.getRealtime().getAuthenticationTimeoutMillis());
            return context.connectedAt().plusMillis(timeout).isBefore(now);
        }
        if (!context.expiresAt().isAfter(now)) {
            return true;
        }
        return sessionRevocationChecker.isRevoked(context.userId(), context.sid());
    }

    private void close(String sessionId, WebSocketSession session) {
        unregister(sessionId, session);
        if (!session.isOpen()) {
            return;
        }
        try {
            session.close(CloseStatus.POLICY_VIOLATION);
        } catch (IOException ex) {
            log.debug("关闭无效 WebSocket 会话失败: sessionId={}", sessionId, ex);
        }
    }

    private boolean tryAcquireSessionSlot() {
        int limit = Math.max(1, properties.getRealtime().getMaxSessionsPerInstance());
        while (true) {
            int current = activeSessionCount.get();
            if (current >= limit) {
                return false;
            }
            if (activeSessionCount.compareAndSet(current, current + 1)) {
                return true;
            }
        }
    }

    private boolean unregister(String sessionId, WebSocketSession session) {
        SessionContext current = sessions.get(sessionId);
        if (current == null || current.session() != session || !sessions.remove(sessionId, current)) {
            return false;
        }
        activeSessionCount.decrementAndGet();
        return true;
    }

    private void rejectForCapacity(WebSocketSession session) {
        meterRegistry.counter(REJECTED_SESSION_METRIC, "reason", "capacity").increment();
        logCapacityWarning();
        if (!session.isOpen()) {
            return;
        }
        try {
            session.close(CAPACITY_EXCEEDED_STATUS);
        } catch (IOException exception) {
            log.debug("关闭超出容量的 WebSocket 会话失败: sessionId={}", session.getId(), exception);
        }
    }

    private void logCapacityWarning() {
        long now = System.nanoTime();
        long previous = lastCapacityWarningNanos.get();
        if ((previous != Long.MIN_VALUE && now - previous < CAPACITY_WARNING_INTERVAL_NANOS)
                || !lastCapacityWarningNanos.compareAndSet(previous, now)) {
            return;
        }
        log.warn("WebSocket 单实例会话容量已满: activeSessions={}, limit={}",
                activeSessionCount.get(),
                Math.max(1, properties.getRealtime().getMaxSessionsPerInstance()));
    }

    private record SessionContext(
            WebSocketSession session,
            Instant connectedAt,
            UUID userId,
            UUID sid,
            Instant expiresAt
    ) {
        private static SessionContext connected(WebSocketSession session, Instant connectedAt) {
            return new SessionContext(session, connectedAt, null, null, null);
        }

        private SessionContext authorized(UUID userId, UUID sid, Instant expiresAt) {
            return new SessionContext(session, connectedAt, userId, sid, expiresAt);
        }
    }
}
