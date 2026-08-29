package com.omninest.modules.video.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.omninest.common.messaging.QueueNames;
import com.omninest.common.error.BusinessException;
import com.omninest.modules.file.domain.StorageLocation;
import com.omninest.modules.file.service.StorageLocationService;
import com.omninest.modules.task.service.TaskDispatchService;
import com.omninest.modules.task.service.TaskRecordService;
import com.omninest.modules.video.domain.VideoLibrarySource;
import com.omninest.modules.video.domain.MediaImportPolicy;
import com.omninest.modules.video.domain.MediaLibraryType;
import com.omninest.modules.video.domain.MediaScanRun;
import com.omninest.modules.video.dto.MovieDtos.ScrapeTaskDto;
import com.omninest.modules.video.dto.VideoLibrarySourceDtos.CreateVideoLibrarySourceRequest;
import com.omninest.modules.video.event.LocalVideoLibraryScanRequestedEvent;
import com.omninest.modules.video.repository.VideoLibrarySourceRepository;
import com.omninest.modules.video.repository.MediaScanRunRepository;
import com.omninest.modules.video.repository.MediaScanBatchRepository;
import com.omninest.modules.video.repository.MediaScanCandidateRepository;
import com.omninest.modules.video.repository.MediaVideoItemRepository;
import java.util.Optional;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/**
 * 影视库本地来源任务编排服务测试。
 *
 * @author OmniNest
 */
class VideoLibrarySourceServiceTest {
    private static final UUID OWNER_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");
    private static final UUID SOURCE_ID = UUID.fromString("20000000-0000-0000-0000-000000000001");
    private static final UUID LOCATION_ID = UUID.fromString("30000000-0000-0000-0000-000000000001");
    private static final UUID RUN_ID = UUID.fromString("40000000-0000-0000-0000-000000000001");

    private final VideoLibrarySourceRepository sourceRepository = mock(VideoLibrarySourceRepository.class);
    private final MediaScanRunRepository runRepository = mock(MediaScanRunRepository.class);
    private final MediaScanBatchRepository batchRepository = mock(MediaScanBatchRepository.class);
    private final MediaScanCandidateRepository candidateRepository = mock(MediaScanCandidateRepository.class);
    private final MediaVideoItemRepository videoItemRepository = mock(MediaVideoItemRepository.class);
    private final StorageLocationService storageLocationService = mock(StorageLocationService.class);
    private final TaskRecordService taskRecordService = mock(TaskRecordService.class);
    private final TaskDispatchService taskDispatchService = mock(TaskDispatchService.class);
    private final MediaLibraryDiscoveryExecutor discoveryExecutor = mock(MediaLibraryDiscoveryExecutor.class);
    private final MediaLibraryAccessService accessService = mock(MediaLibraryAccessService.class);
    private final VideoLibrarySourceService service = new VideoLibrarySourceService(
            sourceRepository,
            runRepository,
            batchRepository,
            candidateRepository,
            videoItemRepository,
            storageLocationService,
            taskRecordService,
            taskDispatchService,
            discoveryExecutor,
            accessService
    );

    @Test
    void scanPersistsTaskAndOutboxWithoutScanningOnRequestThread() {
        VideoLibrarySource source = source("COMPLETED");
        when(accessService.requireManage(OWNER_ID, SOURCE_ID)).thenReturn(source);
        when(sourceRepository.save(source)).thenReturn(source);
        when(runRepository.existsByLibrarySourceIdAndStatusIn(eq(SOURCE_ID), any()))
                .thenReturn(false);
        when(runRepository.findFirstByLibrarySourceIdOrderByCreatedAtDesc(SOURCE_ID))
                .thenReturn(Optional.empty());
        when(runRepository.save(any(MediaScanRun.class))).thenAnswer(invocation -> {
            MediaScanRun run = invocation.getArgument(0);
            run.setId(RUN_ID);
            return run;
        });

        ScrapeTaskDto result = service.scan(OWNER_ID, SOURCE_ID);

        assertThat(result.status()).isEqualTo("QUEUED");
        assertThat(source.getScanStatus()).isEqualTo("QUEUED");
        verify(taskRecordService).createQueuedTask(
                eq(result.taskId()),
                eq(OWNER_ID),
                eq("LOCAL_VIDEO_LIBRARY_DISCOVERY"),
                eq(QueueNames.LOCAL_VIDEO_LIBRARY_SCAN_ROUTING_KEY),
                eq("QUEUED"),
                eq("MEDIA_SCAN_RUN"),
                eq(RUN_ID),
                any()
        );
        verify(taskDispatchService).enqueue(
                eq(result.taskId()),
                eq(QueueNames.TASK_EXCHANGE),
                eq(QueueNames.LOCAL_VIDEO_LIBRARY_SCAN_ROUTING_KEY),
                any(LocalVideoLibraryScanRequestedEvent.class)
        );
    }

    @Test
    void executeScanDelegatesToDiscoveryExecutor() {
        UUID taskId = UUID.fromString("50000000-0000-0000-0000-000000000001");
        LocalVideoLibraryScanRequestedEvent event = new LocalVideoLibraryScanRequestedEvent(
                taskId,
                OWNER_ID,
                SOURCE_ID,
                RUN_ID
        );

        service.executeScan(event);

        verify(discoveryExecutor).execute(event);
    }

    @Test
    void createRejectsCaseInsensitiveChildPathOverlap() {
        StorageLocation location = new StorageLocation();
        location.setScopeType("SYSTEM");
        VideoLibrarySource existing = source("READY");
        existing.setRelativeRoot("Movies");
        when(storageLocationService.requireAccessibleLocation(OWNER_ID, LOCATION_ID)).thenReturn(location);
        when(sourceRepository.findByStorageLocationId(LOCATION_ID)).thenReturn(List.of(existing));

        CreateVideoLibrarySourceRequest request = new CreateVideoLibrarySourceRequest(
                "动作电影",
                LOCATION_ID,
                "movies/Action",
                MediaLibraryType.MOVIE,
                MediaImportPolicy.MANUAL_REVIEW,
                true
        );

        assertThatThrownBy(() -> service.create(OWNER_ID, request))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("重复或重叠");
    }

    private VideoLibrarySource source(String scanStatus) {
        VideoLibrarySource source = new VideoLibrarySource();
        source.setId(SOURCE_ID);
        source.setOwnerUserId(OWNER_ID);
        source.setStorageLocationId(LOCATION_ID);
        source.setName("本地影片");
        source.setRelativeRoot("movies");
        source.setLibraryType(MediaLibraryType.MOVIE.name());
        source.setEnabled(true);
        source.setScanStatus(scanStatus);
        return source;
    }
}
