package com.omninest.modules.photos.service;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.omninest.common.ai.ImageAnalysisGateway;
import com.omninest.common.ai.ImageAnalysisGateway.ContentAnalysis;
import com.omninest.common.ai.ImageAnalysisGateway.ContentObservation;
import com.omninest.common.ai.ImageAnalysisGateway.FaceDetection;
import com.omninest.modules.file.dto.FileContentStream;
import com.omninest.modules.file.service.FileLifecycleGuard;
import com.omninest.modules.file.service.FileQueryService;
import com.omninest.modules.photos.domain.PhotoFace;
import com.omninest.modules.photos.domain.PhotoFaceCluster;
import com.omninest.modules.photos.domain.PhotoItem;
import com.omninest.modules.photos.repository.PhotoFaceClusterRepository;
import com.omninest.modules.photos.repository.PhotoFaceRepository;
import com.omninest.modules.photos.repository.PhotoFavoriteRepository;
import com.omninest.modules.photos.repository.PhotoItemRepository;
import com.omninest.modules.photos.repository.PhotoTagRepository;
import java.io.ByteArrayInputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentMatchers;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Mockito;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 照片图像分析文件解析和临时文件生命周期测试。
 *
 * @author OmniNest
 */
@ExtendWith(MockitoExtension.class)
class PhotoAiServiceTest {

    @Mock
    private ImageAnalysisGateway imageAnalysisGateway;
    @Spy
    private PhotoLabelPolicy labelPolicy = new PhotoLabelPolicy();
    @Mock
    private PhotoContentAnalysisService contentAnalysisService;
    @Mock
    private PhotosRuntimeConfigService configService;
    @Mock
    private PhotoFaceRepository faceRepository;
    @Mock
    private PhotoFaceClusterRepository clusterRepository;
    @Mock
    private PhotoItemRepository photoItemRepository;
    @Mock
    private PhotoFavoriteRepository favoriteRepository;
    @Mock
    private PhotoTagRepository tagRepository;
    @Mock
    private FileQueryService fileQueryService;
    @Mock
    private FileLifecycleGuard fileLifecycleGuard;

    @InjectMocks
    private PhotoAiService service;

    @Test
    void shouldResolveCoverNodeAndDeleteStagedFileAfterProcessing() {
        UUID ownerUserId = UUID.randomUUID();
        UUID photoId = UUID.randomUUID();
        UUID coverNodeId = UUID.randomUUID();
        PhotoItem photo = new PhotoItem();
        photo.setId(photoId);
        photo.setOwnerUserId(ownerUserId);
        photo.setCoverFileId(coverNodeId);
        photo.setProviderMetadata(new HashMap<>());
        AtomicReference<Path> stagedFile = new AtomicReference<>();

        Mockito.when(photoItemRepository.findByOwnerUserIdAndId(ownerUserId, photoId))
                .thenReturn(Optional.of(photo));
        Mockito.when(imageAnalysisGateway.maxImageBytes()).thenReturn(1024L);
        Mockito.when(configService.aiEndpoint()).thenReturn("http://localhost:8090");
        Mockito.when(configService.aiTimeoutSeconds()).thenReturn(5);
        Mockito.when(fileQueryService.openOwnedFileContent(ownerUserId, coverNodeId))
                .thenReturn(new FileContentStream(
                        new ByteArrayInputStream(new byte[]{1, 2, 3, 4}),
                        "cover.jpg",
                        4,
                        "image/jpeg"
                ));
        Mockito.when(imageAnalysisGateway.detectFaces(
                        ArgumentMatchers.any(Path.class),
                        ArgumentMatchers.anyString(),
                        ArgumentMatchers.anyInt()))
                .thenAnswer(invocation -> {
                    Path path = invocation.getArgument(0);
                    stagedFile.set(path);
                    return List.of();
                });
        Mockito.when(imageAnalysisGateway.analyzeContent(
                        ArgumentMatchers.any(Path.class),
                        ArgumentMatchers.anyString(),
                        ArgumentMatchers.anyInt()))
                .thenReturn(emptyAnalysis());

        service.processPhoto(ownerUserId, photoId);

        Mockito.verify(fileQueryService).openOwnedFileContent(ownerUserId, coverNodeId);
        assertTrue(stagedFile.get() != null);
        assertFalse(Files.exists(stagedFile.get()));
    }

    @Test
    void shouldPropagateSidecarFailureWithoutReplacingExistingAnalysis() {
        UUID ownerUserId = UUID.randomUUID();
        UUID photoId = UUID.randomUUID();
        UUID coverNodeId = UUID.randomUUID();
        PhotoItem photo = new PhotoItem();
        photo.setId(photoId);
        photo.setOwnerUserId(ownerUserId);
        photo.setCoverFileId(coverNodeId);
        photo.setProviderMetadata(new HashMap<>());

        Mockito.when(photoItemRepository.findByOwnerUserIdAndId(ownerUserId, photoId))
                .thenReturn(Optional.of(photo));
        Mockito.when(imageAnalysisGateway.maxImageBytes()).thenReturn(1024L);
        Mockito.when(configService.aiEndpoint()).thenReturn("http://localhost:8090");
        Mockito.when(configService.aiTimeoutSeconds()).thenReturn(5);
        Mockito.when(fileQueryService.openOwnedFileContent(ownerUserId, coverNodeId))
                .thenReturn(new FileContentStream(
                        new ByteArrayInputStream(new byte[]{1, 2, 3, 4}),
                        "cover.jpg",
                        4,
                        "image/jpeg"
                ));
        Mockito.when(imageAnalysisGateway.detectFaces(
                        ArgumentMatchers.any(Path.class),
                        ArgumentMatchers.anyString(),
                        ArgumentMatchers.anyInt()))
                .thenThrow(new IllegalStateException("sidecar unavailable"));

        assertThrows(IllegalStateException.class, () -> service.processPhoto(ownerUserId, photoId));

        Mockito.verify(contentAnalysisService, Mockito.never()).apply(
                ArgumentMatchers.any(),
                ArgumentMatchers.any(),
                ArgumentMatchers.anyList(),
                ArgumentMatchers.any(),
                ArgumentMatchers.anyList()
        );
    }

    @Test
    void shouldReplaceFaceAnalysisWhenPhotoIsProcessedAgain() {
        UUID ownerUserId = UUID.randomUUID();
        UUID photoId = UUID.randomUUID();
        UUID coverNodeId = UUID.randomUUID();
        PhotoItem photo = new PhotoItem();
        photo.setId(photoId);
        photo.setOwnerUserId(ownerUserId);
        photo.setCoverFileId(coverNodeId);
        photo.setProviderMetadata(new HashMap<>());

        Mockito.when(photoItemRepository.findByOwnerUserIdAndId(ownerUserId, photoId))
                .thenReturn(Optional.of(photo));
        Mockito.when(imageAnalysisGateway.maxImageBytes()).thenReturn(1024L);
        Mockito.when(configService.aiEndpoint()).thenReturn("http://localhost:8090");
        Mockito.when(configService.aiTimeoutSeconds()).thenReturn(5);
        Mockito.when(fileQueryService.openOwnedFileContent(ownerUserId, coverNodeId))
                .thenReturn(new FileContentStream(
                        new ByteArrayInputStream(new byte[]{1, 2, 3, 4}),
                        "cover.jpg",
                        4,
                        "image/jpeg"
                ));
        Mockito.when(imageAnalysisGateway.detectFaces(
                        ArgumentMatchers.any(Path.class),
                        ArgumentMatchers.anyString(),
                        ArgumentMatchers.anyInt()))
                .thenReturn(List.of(new FaceDetection(1, 2, 3, 4, new float[]{0.5F})));
        Mockito.when(imageAnalysisGateway.analyzeContent(
                        ArgumentMatchers.any(Path.class),
                        ArgumentMatchers.anyString(),
                        ArgumentMatchers.anyInt()))
                .thenReturn(emptyAnalysis());

        service.processPhoto(ownerUserId, photoId);

        Mockito.verify(contentAnalysisService).apply(
                ArgumentMatchers.eq(ownerUserId),
                ArgumentMatchers.eq(photoId),
                ArgumentMatchers.anyList(),
                ArgumentMatchers.any(ContentAnalysis.class),
                ArgumentMatchers.anyList()
        );
    }

    @Test
    void shouldApplyStructuredContentLabelsWithoutCrossNamespaceInference() {
        UUID ownerUserId = UUID.randomUUID();
        UUID photoId = UUID.randomUUID();
        UUID coverNodeId = UUID.randomUUID();
        PhotoItem photo = new PhotoItem();
        photo.setId(photoId);
        photo.setOwnerUserId(ownerUserId);
        photo.setCoverFileId(coverNodeId);
        photo.setProviderMetadata(new HashMap<>());

        Mockito.when(photoItemRepository.findByOwnerUserIdAndId(ownerUserId, photoId))
                .thenReturn(Optional.of(photo));
        Mockito.when(imageAnalysisGateway.maxImageBytes()).thenReturn(1024L);
        Mockito.when(configService.aiEndpoint()).thenReturn("http://localhost:8090");
        Mockito.when(configService.aiTimeoutSeconds()).thenReturn(5);
        Mockito.when(fileQueryService.openOwnedFileContent(ownerUserId, coverNodeId))
                .thenReturn(new FileContentStream(
                        new ByteArrayInputStream(new byte[]{1, 2, 3, 4}),
                        "cover.jpg",
                        4,
                        "image/jpeg"
                ));
        Mockito.when(imageAnalysisGateway.detectFaces(
                        ArgumentMatchers.any(Path.class),
                        ArgumentMatchers.anyString(),
                        ArgumentMatchers.anyInt()))
                .thenReturn(List.of(new FaceDetection(1, 2, 3, 4, new float[]{0.5F})));
        ContentAnalysis analysis = new ContentAnalysis(
                2,
                "content-analysis-v2",
                List.of(
                        new ContentObservation("SUBJECT", "cat", 0.91F, "coco", List.of()),
                        new ContentObservation("SCENE", "mountain", 0.72F, "places365", List.of())
                )
        );
        Mockito.when(imageAnalysisGateway.analyzeContent(
                        ArgumentMatchers.any(Path.class),
                        ArgumentMatchers.anyString(),
                        ArgumentMatchers.anyInt()))
                .thenReturn(analysis);

        service.processPhoto(ownerUserId, photoId);

        Mockito.verify(contentAnalysisService).apply(
                ArgumentMatchers.eq(ownerUserId),
                ArgumentMatchers.eq(photoId),
                ArgumentMatchers.anyList(),
                ArgumentMatchers.eq(analysis),
                ArgumentMatchers.argThat(labels -> labels.stream().anyMatch(label ->
                        label.namespace().equals(PhotoLabelPolicy.SUBJECT)
                                && label.code().equals("cat"))
                        && labels.stream().anyMatch(label ->
                        label.namespace().equals(PhotoLabelPolicy.SCENE)
                                && label.code().equals("mountain"))
                        && labels.stream().noneMatch(label -> label.code().equals("animal")))
        );
    }

    @Test
    void shouldClearStaleAssignmentsAndIgnoreNoiseWhenClustering() {
        UUID ownerUserId = UUID.randomUUID();
        UUID staleClusterId = UUID.randomUUID();
        PhotoFace first = face(ownerUserId, staleClusterId, 0.1F);
        PhotoFace second = face(ownerUserId, staleClusterId, 0.2F);
        PhotoFace noise = face(ownerUserId, staleClusterId, 9.9F);
        PhotoFaceCluster staleCluster = new PhotoFaceCluster();
        staleCluster.setId(staleClusterId);

        Mockito.when(faceRepository.findByOwnerUserId(ownerUserId))
                .thenReturn(List.of(first, second, noise));
        Mockito.when(configService.aiEndpoint()).thenReturn("http://localhost:8090");
        Mockito.when(configService.aiTimeoutSeconds()).thenReturn(5);
        Mockito.when(imageAnalysisGateway.clusterFaces(
                        ArgumentMatchers.anyList(),
                        ArgumentMatchers.anyString(),
                        ArgumentMatchers.anyInt()))
                .thenReturn(List.of(0, 0, -1));
        Mockito.when(clusterRepository.findByOwnerUserIdOrderByFaceCountDesc(ownerUserId))
                .thenReturn(List.of(staleCluster));
        Mockito.when(clusterRepository.save(ArgumentMatchers.any(PhotoFaceCluster.class)))
                .thenAnswer(invocation -> {
                    PhotoFaceCluster cluster = invocation.getArgument(0);
                    cluster.setId(UUID.randomUUID());
                    return cluster;
                });

        service.clusterFaces(ownerUserId);

        assertNotNull(first.getClusterId());
        assertNotNull(second.getClusterId());
        assertNull(noise.getClusterId());
        Mockito.verify(clusterRepository).deleteAll(List.of(staleCluster));
        Mockito.verify(faceRepository, Mockito.times(2)).saveAll(List.of(first, second, noise));
    }

    private PhotoFace face(UUID ownerUserId, UUID clusterId, float embedding) {
        PhotoFace face = new PhotoFace();
        face.setId(UUID.randomUUID());
        face.setPhotoId(UUID.randomUUID());
        face.setOwnerUserId(ownerUserId);
        face.setClusterId(clusterId);
        face.setEmbedding(ByteBuffer.allocate(Float.BYTES)
                .order(ByteOrder.LITTLE_ENDIAN)
                .putFloat(embedding)
                .array());
        return face;
    }

    private ContentAnalysis emptyAnalysis() {
        return new ContentAnalysis(2, "content-analysis-v2", List.of());
    }
}
