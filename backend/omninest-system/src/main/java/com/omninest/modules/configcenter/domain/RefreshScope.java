package com.omninest.modules.configcenter.domain;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 配置刷新范围。
 */
@Getter
@AllArgsConstructor
public enum RefreshScope {
    HOT("HOT"),
    COLD("COLD"),
    LAZY("LAZY");

    private final String value;

    public static RefreshScope fromValue(String value) {
        for (RefreshScope scope : values()) {
            if (scope.value.equalsIgnoreCase(value)) {
                return scope;
            }
        }
        throw new IllegalArgumentException("未知的刷新范围: " + value);
    }
}
