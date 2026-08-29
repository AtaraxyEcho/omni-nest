package com.omninest.app.architecture;

import static org.assertj.core.api.Assertions.assertThat;

import com.omninest.modules.search.service.FileSearchIndexService;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

/**
 * 文件搜索索引服务的 Spring 构造器装配测试。
 *
 * @author OmniNest
 */
class FileSearchIndexServiceWiringTest {

    @TempDir
    Path tempDir;

    @Test
    void fileSearchIndexServiceUsesTheProductionConstructor() {
        new ApplicationContextRunner()
                .withPropertyValues("omninest.search.index-path=" + tempDir.resolve("lucene"))
                .withUserConfiguration(FileSearchIndexService.class)
                .run(context -> {
                    assertThat(context).hasNotFailed();
                    assertThat(context).hasSingleBean(FileSearchIndexService.class);
                });
    }
}
