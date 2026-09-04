package com.omninest.modules.photos.service;

import com.omninest.common.ai.ImageAnalysisGateway.BoundingBox;
import com.omninest.common.ai.ImageAnalysisGateway.ContentAnalysis;
import com.omninest.modules.file.service.FileLifecycleGuard;
import com.omninest.modules.photos.domain.PhotoContentAnalysisRun;
import com.omninest.modules.photos.domain.PhotoContentLabel;
import com.omninest.modules.photos.domain.PhotoFace;
import com.omninest.modules.photos.domain.PhotoItem;
import com.omninest.modules.photos.dto.PhotoDtos.PhotoContentAnalysisDto;
import com.omninest.modules.photos.dto.PhotoDtos.PhotoContentLabelDto;
import com.omninest.modules.photos.repository.PhotoContentAnalysisRunRepository;
import com.omninest.modules.photos.repository.PhotoContentLabelRepository;
import com.omninest.modules.photos.repository.PhotoFaceRepository;
import com.omninest.modules.photos.repository.PhotoItemRepository;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 图像分析结果的原子落库服务。
 *
 * <p>模型推理在事务外执行，本服务只负责短事务内替换本次运行的人脸和结构化标签。
 *
 * @author OmniNest
 */
@Service
@RequiredArgsConstructor
public class PhotoContentAnalysisService {

    public static final String STATUS_RUNNING = "RUNNING";
    public static final String STATUS_SUCCEEDED = "SUCCEEDED";
    public static final String STATUS_SUPERSEDED = "SUPERSEDED";
    public static final String STATUS_FAILED = "FAILED";
    public static final String STATE_AUTO = "AUTO";

    private final PhotoContentAnalysisRunRepository runRepository;
    private final PhotoContentLabelRepository labelRepository;
    private final PhotoFaceRepository faceRepository;
    private final PhotoItemRepository photoItemRepository;
    private final FileLifecycleGuard fileLifecycleGuard;
    private final PhotoFaceClusterMaintenanceService clusterMaintenanceService;

    /**
     * 在短事务中原子应用一轮图像分析结果。
     *
     * @param ownerUserId 用户标识
     * @param photoId 照片标识
     * @param faces 人脸检测结果
     * @param analysis 结构化分析结果
     * @param labels 经过业务策略筛选的标签
     */
    @Transactional(rollbackFor = Exception.class)
    public void apply(
            UUID ownerUserId,
            UUID photoId,
            List<PhotoFace> faces,
            ContentAnalysis analysis,
            List<PhotoLabelPolicy.PhotoLabel> labels
    ) {
        PhotoItem photo = photoItemRepository.findByOwnerUserIdAndId(ownerUserId, photoId)
                .orElseThrow(() -> new IllegalStateException("照片不存在"));
        fileLifecycleGuard.requireOwnedWritable(ownerUserId, photo.getFileNodeId());
        if (photo.getCoverFileId() != null && !photo.getCoverFileId().equals(photo.getFileNodeId())) {
            fileLifecycleGuard.requireOwnedWritable(ownerUserId, photo.getCoverFileId());
        }

        List<PhotoContentAnalysisRun> previousRuns = runRepository
                .findByOwnerUserIdAndPhotoIdAndStatus(ownerUserId, photoId, STATUS_SUCCEEDED);
        previousRuns.forEach(run -> run.setStatus(STATUS_SUPERSEDED));
        runRepository.saveAll(previousRuns);

        Instant now = Instant.now();
        PhotoContentAnalysisRun run = new PhotoContentAnalysisRun();
        run.setOwnerUserId(ownerUserId);
        run.setPhotoId(photoId);
        run.setContentHash(contentHash(photo));
        run.setPipelineVersion(analysis.pipelineVersion() == null
                ? "content-analysis-v2"
                : analysis.pipelineVersion());
        run.setStatus(STATUS_SUCCEEDED);
        run.setStartedAt(now);
        run.setCompletedAt(now);
        PhotoContentAnalysisRun savedRun = runRepository.save(run);

        List<PhotoFace> removedFaces = faceRepository.findByPhotoId(photoId);
        faceRepository.deleteAll(removedFaces);
        faceRepository.saveAll(faces);
        clusterMaintenanceService.onFacesRemoved(ownerUserId, removedFaces);

        List<PhotoContentLabel> entities = labels.stream()
                .map(label -> toEntity(ownerUserId, photoId, savedRun.getId(), label))
                .toList();
        labelRepository.saveAll(entities);

        Map<String, Object> metadata = photo.getProviderMetadata() == null
                ? new HashMap<>()
                : new HashMap<>(photo.getProviderMetadata());
        metadata.remove("rawSceneLabels");
        metadata.remove("sceneLabels");
        metadata.remove("aiTags");
        metadata.put("contentAnalysis", Map.of(
                "status", STATUS_SUCCEEDED,
                "pipelineVersion", run.getPipelineVersion(),
                "completedAt", now.toString(),
                "labelCount", entities.size()
        ));
        photo.setProviderMetadata(metadata);
        photoItemRepository.save(photo);
    }

    /**
     * 查询照片当前成功的图像分析结果。
     *
     * @param ownerUserId 用户标识
     * @param photoId 照片标识
     * @return 当前分析结果，不存在时返回 null
     */
    @Transactional(readOnly = true)
    public PhotoContentAnalysisDto current(UUID ownerUserId, UUID photoId) {
        PhotoContentAnalysisRun run = runRepository
                .findTopByOwnerUserIdAndPhotoIdAndStatusOrderByCreatedAtDesc(
                        ownerUserId,
                        photoId,
                        STATUS_SUCCEEDED
                );
        if (run == null) {
            return null;
        }
        List<PhotoContentLabelDto> labels = labelRepository
                .findByOwnerUserIdAndPhotoIdAndStateOrderByNamespaceAscLabelCodeAsc(
                        ownerUserId,
                        photoId,
                        STATE_AUTO
                )
                .stream()
                .filter(label -> run.getId().equals(label.getRunId()))
                .map(this::toDto)
                .toList();
        return new PhotoContentAnalysisDto(
                run.getStatus(),
                run.getPipelineVersion(),
                run.getCompletedAt(),
                labels
        );
    }

    private PhotoContentLabel toEntity(
            UUID ownerUserId,
            UUID photoId,
            UUID runId,
            PhotoLabelPolicy.PhotoLabel label
    ) {
        PhotoContentLabel entity = new PhotoContentLabel();
        entity.setOwnerUserId(ownerUserId);
        entity.setPhotoId(photoId);
        entity.setRunId(runId);
        entity.setNamespace(label.namespace());
        entity.setLabelCode(label.code());
        entity.setConfidence(label.confidence());
        entity.setSource(label.source() == null || label.source().isBlank()
                ? "unknown"
                : label.source());
        entity.setModelVersion("content-analysis-v2");
        entity.setBoxes(label.boxes().stream().map(this::toBox).toList());
        entity.setState(STATE_AUTO);
        return entity;
    }

    private Map<String, Object> toBox(BoundingBox box) {
        Map<String, Object> result = new HashMap<>();
        result.put("x", box.x());
        result.put("y", box.y());
        result.put("width", box.width());
        result.put("height", box.height());
        return result;
    }

    private PhotoContentLabelDto toDto(PhotoContentLabel label) {
        return new PhotoContentLabelDto(
                label.getId(),
                label.getNamespace(),
                label.getLabelCode(),
                label.getConfidence(),
                label.getSource(),
                label.getState(),
                label.getBoxes() == null ? List.of() : label.getBoxes()
        );
    }

    private String contentHash(PhotoItem photo) {
        if (photo.getProviderMetadata() == null) {
            return null;
        }
        Object value = photo.getProviderMetadata().get("contentHash");
        return value == null ? null : value.toString();
    }
}
