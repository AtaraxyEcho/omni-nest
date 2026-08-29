package com.omninest.modules.user.service;

import com.omninest.modules.user.domain.AuthLoginAudit;
import com.omninest.modules.user.domain.AuthUser;
import com.omninest.modules.user.repository.AuthLoginAuditRepository;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * 登录审计服务，使用 REQUIRES_NEW 确保审计记录不随主事务回滚。
 */
@Service
@RequiredArgsConstructor
public class LoginAuditService {

    private final AuthLoginAuditRepository auditRepository;

    /**
     * 记录登录审计日志。独立事务，不受主事务回滚影响。
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW, rollbackFor = Exception.class)
    public void record(AuthUser user, String username, String clientPlatform,
                       String deviceId, String deviceName,
                       String ipAddress, String userAgent,
                       String result, String failureReason) {
        AuthLoginAudit audit = new AuthLoginAudit();
        audit.setId(UUID.randomUUID());
        audit.setUserId(user != null ? user.getId() : null);
        audit.setUsername(username);
        audit.setLoginResult(result);
        audit.setClientPlatform(clientPlatform);
        audit.setDeviceId(deviceId);
        audit.setDeviceName(deviceName);
        audit.setIpAddress(ipAddress);
        audit.setUserAgent(userAgent);
        audit.setFailureReason(failureReason);
        auditRepository.save(audit);
    }
}
