package com.omninest.modules.photos.service;

import com.omninest.common.config.BaseRuntimeConfigService;
import com.omninest.common.config.AiSidecarProperties;
import com.omninest.common.config.ConfigValueProvider;
import com.omninest.common.config.LegacyDeploymentConfigResolver;
import com.omninest.common.config.RuntimeConfigCache;
import org.springframework.stereotype.Service;

/**
 * 照片模块运行时配置服务。
 * 从配置中心读取照片图像分析和备份相关的配置项。
 *
 * @author OmniNest
 */
@Service
public class PhotosRuntimeConfigService extends BaseRuntimeConfigService {

    public static final String PHOTO_AI_ENABLED = "photo.ai.enabled";
    public static final String PHOTO_AI_ENDPOINT = "photo.ai.url";
    public static final String PHOTO_AI_TIMEOUT = "photo.ai.timeout";
    public static final String PHOTO_BACKUP_ENABLED = "photo.backup";
    public static final String PHOTO_GEO_RATE = "photo.geo.rate";

    private final AiSidecarProperties deploymentProperties;
    private final LegacyDeploymentConfigResolver legacyDeploymentConfigResolver;

    /**
     * 创建照片运行时配置服务。
     *
     * @param configValueProvider 配置值查询端口
     * @param runtimeConfigCache 运行时配置缓存端口
     */
    public PhotosRuntimeConfigService(
            ConfigValueProvider configValueProvider,
            RuntimeConfigCache runtimeConfigCache,
            AiSidecarProperties deploymentProperties,
            LegacyDeploymentConfigResolver legacyDeploymentConfigResolver
    ) {
        super(configValueProvider, runtimeConfigCache);
        this.deploymentProperties = deploymentProperties;
        this.legacyDeploymentConfigResolver = legacyDeploymentConfigResolver;
    }

    /** @return 是否启用照片图像分析 */
    public boolean isAiEnabled() {
        return booleanConfig(PHOTO_AI_ENABLED, true);
    }

    /** @return AI 服务地址 */
    public String aiEndpoint() {
        return nonDefaultConfigValue(PHOTO_AI_ENDPOINT, "http://localhost:8090")
                .or(() -> nonDefaultConfigValue("photo.ai.endpoint", "http://localhost:8090"))
                .orElseGet(() -> legacyDeploymentConfigResolver.stringValue(
                        "OMNINEST_PHOTO_AI_ENDPOINT",
                        PHOTO_AI_ENDPOINT,
                        deploymentProperties.getEndpoint(),
                        "http://localhost:8090"
                ));
    }

    /** @return AI 请求超时秒数 */
    public int aiTimeoutSeconds() {
        return Math.clamp(
                cachedConfigValue(PHOTO_AI_TIMEOUT)
                        .or(() -> cachedConfigValue("photo.ai.timeout-seconds"))
                        .map(value -> parseInt(value, 30))
                        .orElse(30),
                3,
                120
        );
    }

    /** @return 是否启用照片备份 */
    public boolean isBackupEnabled() {
        return cachedConfigValue(PHOTO_BACKUP_ENABLED)
                .or(() -> cachedConfigValue("photo.backup.enabled"))
                .map(value -> parseBoolean(value, true))
                .orElse(true);
    }

    /** @return Nominatim 每秒请求上限 */
    public int geoRateLimitPerSecond() {
        return Math.clamp(
                cachedConfigValue(PHOTO_GEO_RATE)
                        .or(() -> cachedConfigValue("photo.geo.rate-limit-per-second"))
                        .map(value -> parseInt(value, 1))
                        .orElse(1),
                1,
                10
        );
    }

    /** @return 是否启用地理编码缓存 */
    public boolean isGeoCacheEnabled() {
        return true;
    }

    /**
     * 返回旧版全量列表端点的响应条目上限。
     *
     * @return 旧端点条目上限，范围为 1 到 100
     */
    public int legacyListLimit() {
        return 100;
    }
}
