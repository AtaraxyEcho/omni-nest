package com.omninest.common.security;

import com.omninest.common.config.SecurityProperties;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.util.Base64;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 使用安全配置密钥提供 HMAC-SHA256 文本负载签名。
 *
 * @author OmniNest
 */
@Component
@RequiredArgsConstructor
public class HmacSha256PayloadAuthenticator implements PayloadAuthenticator {
    private static final String HMAC_ALGORITHM = "HmacSHA256";

    private final SecurityProperties securityProperties;

    @Override
    public String sign(String payload) {
        try {
            Mac mac = Mac.getInstance(HMAC_ALGORITHM);
            SecretKeySpec keySpec = new SecretKeySpec(
                    securityProperties.getJwtSecret().getBytes(StandardCharsets.UTF_8),
                    HMAC_ALGORITHM
            );
            mac.init(keySpec);
            byte[] digest = mac.doFinal(payload.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(digest);
        } catch (GeneralSecurityException exception) {
            throw new IllegalStateException("负载签名失败", exception);
        }
    }

    @Override
    public boolean verify(String payload, String signature) {
        if (payload == null || signature == null) {
            return false;
        }
        byte[] expected = sign(payload).getBytes(StandardCharsets.UTF_8);
        byte[] actual = signature.getBytes(StandardCharsets.UTF_8);
        return MessageDigest.isEqual(expected, actual);
    }
}
