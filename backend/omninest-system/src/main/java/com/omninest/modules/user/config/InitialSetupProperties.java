package com.omninest.modules.user.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 首次安装向导的服务端安全配置。
 *
 * @author OmniNest
 */
@Data
@ConfigurationProperties(prefix = "omninest.setup")
public class InitialSetupProperties {
    private boolean enabled = true;
    private String token;
    private boolean persistentStateEnabled = true;
    private String webBaseUrl;
}
