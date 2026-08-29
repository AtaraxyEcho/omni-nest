package com.omninest.modules.user.repository;

import com.omninest.modules.user.domain.AuthRole;
import java.util.Optional;
import java.util.UUID;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * 认证角色仓储。
 *
 * @author OmniNest
 */
public interface AuthRoleRepository extends JpaRepository<AuthRole, UUID> {

    /**
     * 按编码查询角色。
     *
     * @param code 角色编码
     * @return 匹配角色
     */
    Optional<AuthRole> findByCode(String code);

    /**
     * 锁定并读取角色，用于串行化首次安装流程。
     *
     * @param code 角色编码
     * @return 匹配角色
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select role from AuthRole role where role.code = :code")
    Optional<AuthRole> findByCodeForUpdate(@Param("code") String code);
}
