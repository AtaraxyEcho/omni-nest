package com.omninest.common.security;

import static org.assertj.core.api.Assertions.assertThat;

import com.omninest.common.config.SecurityProperties;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;

/**
 * JWT 编解码配置回环测试。
 *
 * @author OmniNest
 */
class SecurityConfigTest {

    @Test
    void hs256EncoderAndDecoderRoundTrip() {
        SecurityProperties properties = new SecurityProperties();
        properties.setJwtSecret("test-secret-for-hs256-round-trip-at-least-32-bytes");
        SecurityConfig config = new SecurityConfig();
        JwtEncoder encoder = config.jwtEncoder(properties);
        JwtDecoder decoder = config.jwtDecoder(properties);
        Instant issuedAt = Instant.now().minusSeconds(1);
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .subject("10000000-0000-0000-0000-000000000001")
                .issuedAt(issuedAt)
                .expiresAt(issuedAt.plusSeconds(300))
                .claim("token_type", "access")
                .build();

        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
        String token = encoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
        var decoded = decoder.decode(token);

        assertThat(decoded.getSubject()).isEqualTo(claims.getSubject());
        assertThat(decoded.getClaimAsString("token_type")).isEqualTo("access");
        assertThat(decoded.getHeaders().get("alg")).isEqualTo("HS256");
    }
}
