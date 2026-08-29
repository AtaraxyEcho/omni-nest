package com.omninest.modules.user.port;

import java.util.List;
import java.util.UUID;

/**
 * 外部存储账户管理端口。
 *
 * @author OmniNest
 */
public interface ExternalStorageAdministration {

    /**
     * 统计外部存储账户数量。
     *
     * @return 外部存储账户数量
     */
    long countAccounts();

    /**
     * 按最近更新时间查询全部外部存储账户。
     *
     * @return 外部存储账户摘要列表
     */
    List<ExternalStorageAccountSummary> listAccounts();

    /**
     * 创建外部存储账户。
     *
     * @param ownerUserId 所有者用户标识
     * @param provider 存储提供方
     * @param displayName 显示名称
     * @param encryptedCredentials 加密凭据
     * @return 新建账户摘要
     */
    ExternalStorageAccountSummary createAccount(
            UUID ownerUserId,
            String provider,
            String displayName,
            String encryptedCredentials
    );

    /**
     * 更新外部存储账户状态。
     *
     * @param accountId 账户标识
     * @param status 目标状态
     * @return 更新后的账户摘要
     */
    ExternalStorageAccountSummary updateStatus(UUID accountId, String status);
}
