package com.omninest.worker.runtime;

import com.omninest.common.runtime.WorkerRuntimeRegistry;
import com.omninest.common.runtime.WorkerRuntimeState;
import com.omninest.modules.photos.service.PhotosRuntimeConfigService;
import java.time.Duration;
import org.assertj.core.api.Assertions;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.Mockito;

/**
 * Worker 运行状态上报测试。
 *
 * @author OmniNest
 */
class WorkerRuntimeReporterTest {

    @Test
    void publishReportsDisabledPhotoAi() {
        WorkerRuntimeRegistry registry = Mockito.mock(WorkerRuntimeRegistry.class);
        PhotosRuntimeConfigService photosConfig = Mockito.mock(PhotosRuntimeConfigService.class);
        Mockito.when(photosConfig.isAiEnabled()).thenReturn(false);
        WorkerRuntimeProperties runtimeProperties = new WorkerRuntimeProperties();
        runtimeProperties.setInstanceId("worker-test");
        runtimeProperties.setHeartbeatTtl(Duration.ofSeconds(45));
        runtimeProperties.setProbeTimeout(Duration.ofMillis(200));
        WorkerRuntimeReporter reporter = new WorkerRuntimeReporter(
                registry,
                runtimeProperties,
                photosConfig
        );

        reporter.publish();

        ArgumentCaptor<WorkerRuntimeState> stateCaptor = ArgumentCaptor.forClass(WorkerRuntimeState.class);
        Mockito.verify(registry).publish(stateCaptor.capture(), Mockito.eq(Duration.ofSeconds(45)));
        WorkerRuntimeState state = stateCaptor.getValue();
        Assertions.assertThat(state.instanceId()).isEqualTo("worker-test");
        Assertions.assertThat(state.reportedAt()).isNotNull();
        Assertions.assertThat(state.capability(WorkerRuntimeState.PHOTO_AI_CAPABILITY).status())
                .isEqualTo("DISABLED");
    }
}
