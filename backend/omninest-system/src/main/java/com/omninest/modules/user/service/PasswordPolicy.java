package com.omninest.modules.user.service;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.Set;
import org.springframework.stereotype.Component;

/**
 * 统一校验本地账户密码，确保所有账号创建和改密入口使用相同边界。
 *
 * @author OmniNest
 */
@Component
public class PasswordPolicy {

    public static final int MIN_LENGTH = 8;
    public static final int MAX_BCRYPT_BYTES = 72;

    private static final Set<String> BLOCKED_PASSWORDS = Set.of(
            "12341234",
            "12345678",
            "123456789",
            "123456789012",
            "admin12345678",
            "password",
            "password123",
            "password1234",
            "qwerty123456"
    );

    /**
     * 校验密码长度、BCrypt 字节边界和常见弱口令。
     *
     * @param username 账户名
     * @param password 待校验密码
     */
    public void validate(String username, String password) {
        if (password == null || password.length() < MIN_LENGTH) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "密码长度不能少于 8 个字符");
        }
        if (password.getBytes(StandardCharsets.UTF_8).length > MAX_BCRYPT_BYTES) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "密码 UTF-8 编码后不能超过 72 字节");
        }
        String normalizedPassword = password.toLowerCase(Locale.ROOT);
        String normalizedUsername = username == null ? "" : username.trim().toLowerCase(Locale.ROOT);
        if (BLOCKED_PASSWORDS.contains(normalizedPassword)
                || (!normalizedUsername.isEmpty() && normalizedPassword.equals(normalizedUsername))) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "密码不能使用常见弱口令或与用户名相同");
        }
    }
}
