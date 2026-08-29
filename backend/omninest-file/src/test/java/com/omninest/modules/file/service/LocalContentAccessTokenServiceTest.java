package com.omninest.modules.file.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.omninest.common.error.BusinessException;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/**
 * 本地内容短期访问令牌测试。
 *
 * @author OmniNest
 */
class LocalContentAccessTokenServiceTest {

    private final LocalContentAccessTokenService service = new LocalContentAccessTokenService();

    @Test
    void shouldIssueFileScopedRandomTokens() {
        UUID ownerUserId = UUID.randomUUID();
        UUID fileId = UUID.randomUUID();

        LocalContentAccessTokenService.IssuedAccess first = service.issue(ownerUserId, fileId);
        LocalContentAccessTokenService.IssuedAccess second = service.issue(ownerUserId, fileId);

        assertNotEquals(first.token(), second.token());
        LocalContentAccessTokenService.AccessGrant grant = service.requireGrant(first.token());
        assertEquals(ownerUserId, grant.ownerUserId());
        assertEquals(fileId, grant.fileId());
    }

    @Test
    void shouldRejectUnknownToken() {
        assertThrows(BusinessException.class, () -> service.requireGrant("unknown"));
    }
}
