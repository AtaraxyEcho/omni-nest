package com.omninest.modules.user.repository;

import com.omninest.modules.user.domain.SessionRevocationEntity;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 会话撤销记录 JPA 仓储（Spring Data 自动实现）。
 */
public interface SessionRevocationJpaRepository extends JpaRepository<SessionRevocationEntity, UUID> {

    boolean existsByUserIdAndSessionId(UUID userId, UUID sessionId);
}
