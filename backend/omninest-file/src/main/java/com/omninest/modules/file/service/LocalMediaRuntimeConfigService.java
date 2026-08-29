package com.omninest.modules.file.service;

import com.omninest.common.config.BaseRuntimeConfigService;
import com.omninest.common.config.ConfigValueProvider;
import com.omninest.common.config.RuntimeConfigCache;
import com.omninest.modules.file.config.LocalMediaStorageProperties;
import org.springframework.stereotype.Service;

/**
 * 本地媒体运行时配置服务。
 *
 * <p>配置中心只能关闭部署已允许的能力，不能扩大宿主机目录访问范围。扫描边界采用程序受校验默认值。
 *
 * @author OmniNest
 */
@Service
public class LocalMediaRuntimeConfigService extends BaseRuntimeConfigService {
    public static final String ENABLED = "file.local-media.enabled";
    public static final String MAX_FILES_PER_SCAN = "file.local-media.max-files-per-scan";
    public static final String MAX_SCAN_DEPTH = "file.local-media.max-scan-depth";
    private final LocalMediaStorageProperties deploymentProperties;

    /**
     * 创建本地媒体运行时配置服务。
     *
     * @param configValueProvider 配置值查询端口
     * @param runtimeConfigCache 运行时配置缓存端口
     * @param deploymentProperties 部署层本地媒体配置
     */
    public LocalMediaRuntimeConfigService(
            ConfigValueProvider configValueProvider,
            RuntimeConfigCache runtimeConfigCache,
            LocalMediaStorageProperties deploymentProperties
    ) {
        super(configValueProvider, runtimeConfigCache);
        this.deploymentProperties = deploymentProperties;
    }

    /**
     * 判断本地媒体能力是否同时通过部署门禁和运行时开关。
     *
     * @return 是否允许访问本地媒体
     */
    public boolean isEnabled() {
        // 本地路径访问属于部署安全边界，不能由租户级运行时配置扩大或改变。
        return deploymentProperties.isEnabled();
    }

    /**
     * 读取单次扫描文件上限。
     *
     * @return 单次扫描文件上限
     */
    public int maxFilesPerScan() {
        return Math.clamp(deploymentProperties.getMaxFilesPerScan(), 1, 1_000_000);
    }

    /**
     * 读取扫描目录深度上限。
     *
     * @return 扫描目录深度上限
     */
    public int maxScanDepth() {
        return Math.clamp(deploymentProperties.getMaxScanDepth(), 1, 128);
    }
}
