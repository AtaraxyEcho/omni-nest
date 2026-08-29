package com.omninest.modules.task.domain;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 任务状态。
 */
@Getter
@AllArgsConstructor
public enum TaskStatus {
    QUEUED("QUEUED"),
    RUNNING("RUNNING"),
    RETRY_WAIT("RETRY_WAIT"),
    COMPLETED("COMPLETED"),
    FAILED("FAILED"),
    CANCELLED("CANCELLED"),
    DLQ("DLQ");

    private final String value;

    public static TaskStatus fromValue(String value) {
        for (TaskStatus status : values()) {
            if (status.value.equalsIgnoreCase(value)) {
                return status;
            }
        }
        throw new IllegalArgumentException("未知的任务状态: " + value);
    }

    /**
     * 判断是否为可重试状态。
     */
    public boolean isRetryable() {
        return this == RETRY_WAIT || this == FAILED || this == CANCELLED || this == DLQ;
    }

    /**
     * 判断是否为终态。
     */
    public boolean isTerminal() {
        return this == COMPLETED || this == FAILED || this == CANCELLED || this == DLQ;
    }
}
