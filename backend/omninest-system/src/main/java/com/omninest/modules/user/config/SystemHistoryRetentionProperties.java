package com.omninest.modules.user.config;

import java.time.Duration;
import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 系统任务与审计日志保留策略配置。
 *
 * @author OmniNest
 */
@Data
@ConfigurationProperties(prefix = "omninest.history-retention")
public class SystemHistoryRetentionProperties {

    private boolean enabled = true;

    private Duration taskMaximumAge = Duration.ofDays(30);

    private Duration auditMaximumAge = Duration.ofDays(365);

    private Duration configMaximumAge = Duration.ofDays(365);

    private int configMinimumVersions = 20;

    private int batchSize = 500;

    private int maximumBatches = 20;
}
