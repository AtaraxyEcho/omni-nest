package com.omninest;

import com.omninest.common.runtime.RuntimeRole;
import java.util.Map;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * OmniNest 单镜像应用入口，根据运行角色选择 Web 或后台进程模式。
 *
 * @author OmniNest
 */
@SpringBootApplication
@ConfigurationPropertiesScan
@EnableAsync
@EnableScheduling
public class OmniNestApplication {

    public static void main(String[] args) {
        RuntimeRole role = RuntimeRoleResolver.resolve();
        SpringApplication application = new SpringApplication(OmniNestApplication.class);
        application.setWebApplicationType(role == RuntimeRole.API
                ? WebApplicationType.SERVLET
                : WebApplicationType.NONE);
        application.setDefaultProperties(Map.of("omninest.runtime.role", role.propertyValue()));
        application.run(args);
    }

}
