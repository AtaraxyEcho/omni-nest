package com.omninest.common.security;

import static org.assertj.core.api.Assertions.assertThat;

import com.omninest.common.config.SecurityProperties;
import org.junit.jupiter.api.Test;

/**
 * HMAC-SHA256 文本负载签名测试。
 *
 * @author OmniNest
 */
class HmacSha256PayloadAuthenticatorTest {

    private final PayloadAuthenticator authenticator =
            new HmacSha256PayloadAuthenticator(new SecurityProperties());

    @Test
    void verifyAcceptsMatchingPayloadAndSignature() {
        String signature = authenticator.sign("session-1.1780000000");

        assertThat(authenticator.verify("session-1.1780000000", signature)).isTrue();
    }

    @Test
    void verifyRejectsChangedPayloadOrSignature() {
        String signature = authenticator.sign("session-1.1780000000");

        assertThat(authenticator.verify("session-2.1780000000", signature)).isFalse();
        assertThat(authenticator.verify("session-1.1780000000", signature + "x")).isFalse();
    }
}
