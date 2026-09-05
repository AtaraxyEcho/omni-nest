package com.omninest.modules.photos.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * GeoNames 离线数据导入目录配置。
 *
 * <p>数据文件由管理员手工放置在服务端共享目录，不通过 multipart 上传；
 * 多实例部署时至少 Worker 实例必须挂载该目录。</p>
 *
 * @author OmniNest
 */
@Data
@Component
@ConfigurationProperties(prefix = "photo.geo.import")
public class GeonamesImportProperties {

    /** GeoNames 数据文件根目录（共享目录） */
    private String dir = "./data/geonames";
}
