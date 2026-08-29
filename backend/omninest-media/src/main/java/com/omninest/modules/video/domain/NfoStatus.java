package com.omninest.modules.video.domain;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * NFO 导出状态。
 */
@Getter
@AllArgsConstructor
public enum NfoStatus {
    PENDING("PENDING"),
    GENERATED("GENERATED"),
    DISABLED("DISABLED");

    private final String value;

    public static NfoStatus fromValue(String value) {
        for (NfoStatus status : values()) {
            if (status.value.equalsIgnoreCase(value)) {
                return status;
            }
        }
        throw new IllegalArgumentException("未知的 NFO 状态: " + value);
    }
}
