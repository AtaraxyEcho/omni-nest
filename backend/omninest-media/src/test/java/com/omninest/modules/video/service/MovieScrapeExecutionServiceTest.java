package com.omninest.modules.video.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeast;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.omninest.modules.video.domain.MediaMovie;
import com.omninest.modules.video.domain.MediaVideoItem;
import com.omninest.modules.video.dto.MovieDtos.ScrapeCandidateDto;
import com.omninest.modules.video.event.MediaScrapeRequestedEvent;
import com.omninest.modules.video.repository.MediaMovieRepository;
import com.omninest.modules.video.repository.MediaTvEpisodeRepository;
import com.omninest.modules.video.repository.MediaTvSeasonRepository;
import com.omninest.modules.video.repository.MediaTvSeriesRepository;
import com.omninest.modules.video.repository.MediaVideoItemRepository;
import com.omninest.modules.file.service.DerivedAssetStorageService;
import com.omninest.modules.file.service.FileLifecycleGuard;
import com.omninest.modules.media.service.MediaSyncEventService;
import com.omninest.modules.notification.service.NotificationService;
import com.omninest.modules.task.service.TaskRecordService;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.context.ApplicationEventPublisher;

/**
 * 影视元数据刮削任务执行测试。
 *
 * @author OmniNest
 */
class MovieScrapeExecutionServiceTest {
    private static final UUID TASK_ID = UUID.fromString("40000000-0000-0000-0000-000000000001");
    private static final UUID OWNER_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");
    private static final UUID FILE_ID = UUID.fromString("30000000-0000-0000-0000-000000000001");

    private final MediaRuntimeConfigService configService = Mockito.mock(MediaRuntimeConfigService.class);
    private final MediaVideoItemRepository videoItemRepository = Mockito.mock(MediaVideoItemRepository.class);
    private final TaskRecordService taskRecordService = Mockito.mock(TaskRecordService.class);
    private final MetadataProvider provider = Mockito.mock(MetadataProvider.class);
    private final ContentAssetService contentAssetService = Mockito.mock(ContentAssetService.class);
    private final ApplicationEventPublisher applicationEventPublisher = Mockito.mock(ApplicationEventPublisher.class);
    private final MediaTvSeriesRepository tvSeriesRepository = Mockito.mock(MediaTvSeriesRepository.class);
    private final MediaTvSeasonRepository tvSeasonRepository = Mockito.mock(MediaTvSeasonRepository.class);
    private final MediaMovieRepository movieRepository = Mockito.mock(MediaMovieRepository.class);
    private final MediaTvEpisodeRepository episodeRepository = Mockito.mock(MediaTvEpisodeRepository.class);
    private final NotificationService notificationService = Mockito.mock(NotificationService.class);
    private final DerivedAssetStorageService derivedAssetStorageService = Mockito.mock(DerivedAssetStorageService.class);
    private final MediaSyncEventService syncEventService = Mockito.mock(MediaSyncEventService.class);
    private final FileLifecycleGuard fileLifecycleGuard = Mockito.mock(FileLifecycleGuard.class);
    private final MovieScrapeExecutionService executionService =
            new MovieScrapeExecutionService(
                    configService,
                    videoItemRepository,
                    taskRecordService,
                    List.of(provider),
                    contentAssetService,
                    applicationEventPublisher,
                    tvSeriesRepository,
                    tvSeasonRepository,
                    movieRepository,
                    episodeRepository,
                    notificationService,
                    derivedAssetStorageService,
                    syncEventService,
                    fileLifecycleGuard
            );

    @BeforeEach
    void setUpTaskClaim() {
        when(taskRecordService.claimForExecution(any(UUID.class), any(String.class))).thenReturn(true);
    }

    @Test
    void completesTaskWithoutMetadataLookupWhenProvidersDisabled() {
        when(configService.metadataProvidersEnabled()).thenReturn(false);
        MediaVideoItem item = pendingItem();
        when(videoItemRepository.findByOwnerUserIdAndFileNodeId(OWNER_ID, FILE_ID)).thenReturn(Optional.of(item));

        executionService.execute(event("Inception", 2010));

        assertThat(item.getMetadataStatus()).isEqualTo("PENDING");
        verify(provider, never()).search(any());
        verify(taskRecordService).markCompleted(eq(TASK_ID), argThat(result ->
                "元数据提供器未启用".equals(result.get("message"))));
    }

    @Test
    void createsMediaMovieAndLinksToVideoItemOnSuccessfulScrape() {
        when(configService.metadataProvidersEnabled()).thenReturn(true);
        MediaVideoItem item = pendingItem();
        when(videoItemRepository.findByOwnerUserIdAndFileNodeId(OWNER_ID, FILE_ID)).thenReturn(Optional.of(item));
        when(provider.providerName()).thenReturn("LOCAL");
        ScrapeCandidateDto candidate = new ScrapeCandidateDto(
                "LOCAL",
                "local-inception-2010",
                "Inception",
                null,
                null,
                2010,
                "A dream within a dream.",
                null,
                null,
                null,
                null,
                null,
                null, null, null, null, null, null, null, null, null, null, null
        );
        when(provider.search(new FileNameGuess("Inception", 2010, null, null))).thenReturn(List.of(candidate));
        when(movieRepository.findByTmdbIdAndOwnerUserId(any(), eq(OWNER_ID))).thenReturn(Optional.empty());
        when(movieRepository.save(any(MediaMovie.class))).thenAnswer(invocation -> {
            MediaMovie m = invocation.getArgument(0);
            m.setId(UUID.randomUUID());
            return m;
        });
        when(contentAssetService.syncPrimaryMovieAssets(any(), eq(OWNER_ID), eq(candidate)))
                .thenReturn(new ContentAssetService.MovieAssetResult(null, null));

        executionService.execute(event("Inception", 2010));

        assertThat(item.getMovieId()).isNotNull();
        assertThat(item.getMetadataStatus()).isEqualTo("MATCHED");
        verify(movieRepository, atLeast(2)).save(any(MediaMovie.class));
        verify(contentAssetService).syncPrimaryMovieAssets(any(), eq(OWNER_ID), eq(candidate));
        verify(taskRecordService).markCompleted(eq(TASK_ID), argThat(result ->
                "local-inception-2010".equals(result.get("externalId"))));
    }

    private MediaScrapeRequestedEvent event(String title, Integer year) {
        return new MediaScrapeRequestedEvent(TASK_ID, OWNER_ID, FILE_ID, title, year, null, null, false);
    }

    private MediaVideoItem pendingItem() {
        MediaVideoItem item = new MediaVideoItem();
        item.setId(UUID.fromString("60000000-0000-0000-0000-000000000001"));
        item.setOwnerUserId(OWNER_ID);
        item.setFileNodeId(FILE_ID);
        item.setMediaType("MOVIE");
        item.setMetadataStatus("PENDING");
        return item;
    }
}
