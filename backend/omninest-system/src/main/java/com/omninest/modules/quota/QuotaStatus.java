package com.omninest.modules.quota;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 存储配额状态枚举。
 */
@Getter
@AllArgsConstructor
public enum QuotaStatus {
    NORMAL("NORMAL", "正常"),
    WARNING("WARNING", "接近上限"),
    CRITICAL("CRITICAL", "即将满额");

    private final String value;
    private final String label;

    /**
     * 根据使用比例计算配额状态。
     *
     * @param usedBytes  已使用字节数
     * @param quotaBytes 配额字节数
     * @param warningPercent 预警阈值百分比（如 80 表示 80%）
     * @return 配额状态
     */
    public static QuotaStatus resolve(long usedBytes, long quotaBytes, int warningPercent) {
        if (quotaBytes < 0) {
            return CRITICAL;
        }
        if (quotaBytes == 0) {
            return CRITICAL;
        }
        double usagePercent = (double) usedBytes / quotaBytes * 100;
        if (usagePercent >= 95) {
            return CRITICAL;
        }
        if (usagePercent >= warningPercent) {
            return WARNING;
        }
        return NORMAL;
    }
}
