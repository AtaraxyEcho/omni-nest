package com.omninest.modules.preferences.repository;

import com.omninest.modules.preferences.domain.UserPreference;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 用户偏好持久化仓库。
 *
 * @author Notask Flow Team
 */
public interface UserPreferenceRepository extends JpaRepository<UserPreference, UUID> {
    /**
     * 按用户和作用域查询偏好。
     *
     * @param ownerUserId 用户 ID
     * @param scope 偏好作用域
     * @return 用户偏好
     */
    Optional<UserPreference> findByOwnerUserIdAndScope(UUID ownerUserId, String scope);
}
