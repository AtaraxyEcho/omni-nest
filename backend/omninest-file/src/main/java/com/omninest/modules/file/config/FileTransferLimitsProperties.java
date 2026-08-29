package com.omninest.modules.file.config;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;
import org.springframework.validation.annotation.Validated;

/**
 * 文件导入和离线下载结果处理的资源限制。
 *
 * @author OmniNest
 */
@Data
@Component
@Validated
@ConfigurationProperties(prefix = "file.transfer-limits")
public class FileTransferLimitsProperties {

    @Min(1)
    @Max(100000)
    private int maxFilesPerTask = 10000;
}
