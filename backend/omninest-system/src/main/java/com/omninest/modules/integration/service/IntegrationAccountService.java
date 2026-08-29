package com.omninest.modules.integration.service;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.TypeReference;
import com.omninest.common.security.CredentialCipher;
import com.omninest.modules.integration.domain.IntegrationAccount;
import com.omninest.modules.integration.repository.IntegrationAccountRepository;
import java.time.Instant;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 管理用户外部集成账号及其加密凭据。
 *
 * @author OmniNest
 */
@Service
@RequiredArgsConstructor
public class IntegrationAccountService {
    private static final String ACTIVE_STATUS = "ACTIVE";

    private final IntegrationAccountRepository accountRepository;
    private final CredentialCipher credentialCipher;

    /**
     * 查询并解密用户的集成账号。
     *
     * @param ownerUserId 所属用户 ID
     * @param integrationType 集成类型
     * @param provider 提供者
     * @return 账号数据
     */
    @Transactional(readOnly = true)
    public Optional<IntegrationAccountData> find(
            UUID ownerUserId,
            String integrationType,
            String provider
    ) {
        return accountRepository.findByOwnerUserIdAndIntegrationTypeAndProvider(
                        ownerUserId,
                        normalize(integrationType),
                        normalize(provider)
                )
                .map(this::toData);
    }

    /**
     * 创建或更新外部集成账号。
     *
     * @param ownerUserId 所属用户 ID
     * @param integrationType 集成类型
     * @param provider 提供者
     * @param externalUserId 外部用户 ID
     * @param displayName 显示名称
     * @param avatarUrl 头像地址
     * @param credentials 明文凭据
     * @return 保存后的账号数据
     */
    @Transactional(rollbackFor = Exception.class)
    public IntegrationAccountData save(
            UUID ownerUserId,
            String integrationType,
            String provider,
            String externalUserId,
            String displayName,
            String avatarUrl,
            Map<String, String> credentials
    ) {
        String normalizedType = normalize(integrationType);
        String normalizedProvider = normalize(provider);
        IntegrationAccount account = accountRepository
                .findByOwnerUserIdAndIntegrationTypeAndProvider(ownerUserId, normalizedType, normalizedProvider)
                .orElseGet(IntegrationAccount::new);
        account.setOwnerUserId(ownerUserId);
        account.setIntegrationType(normalizedType);
        account.setProvider(normalizedProvider);
        account.setExternalUserId(externalUserId);
        account.setDisplayName(displayName);
        account.setAvatarUrl(avatarUrl);
        account.setEncryptedCredentials(credentialCipher.encrypt(JSON.toJSONString(credentials)));
        account.setCredentialKeyVersion(credentialCipher.currentKeyVersion());
        account.setStatus(ACTIVE_STATUS);
        account.setLastVerifiedAt(Instant.now());
        return toData(accountRepository.save(account));
    }

    /**
     * 删除用户的外部集成账号。
     *
     * @param ownerUserId 所属用户 ID
     * @param integrationType 集成类型
     * @param provider 提供者
     */
    @Transactional(rollbackFor = Exception.class)
    public void delete(UUID ownerUserId, String integrationType, String provider) {
        accountRepository.findByOwnerUserIdAndIntegrationTypeAndProvider(
                        ownerUserId,
                        normalize(integrationType),
                        normalize(provider)
                )
                .ifPresent(accountRepository::delete);
    }

    private IntegrationAccountData toData(IntegrationAccount account) {
        String plaintext = credentialCipher.decrypt(account.getEncryptedCredentials());
        Map<String, String> credentials = JSON.parseObject(
                plaintext,
                new TypeReference<Map<String, String>>() {
                }
        );
        return new IntegrationAccountData(
                account.getId(),
                account.getOwnerUserId(),
                account.getIntegrationType(),
                account.getProvider(),
                account.getExternalUserId(),
                account.getDisplayName(),
                account.getAvatarUrl(),
                Map.copyOf(credentials),
                account.getStatus(),
                account.getLastVerifiedAt()
        );
    }

    private String normalize(String value) {
        return value == null ? "" : value.trim().toUpperCase(Locale.ROOT);
    }
}
