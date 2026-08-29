package com.omninest.modules.photos.repository;

import com.omninest.modules.photos.domain.PhotoContentLabel;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/**
 * 照片图像分析标签仓储。
 *
 * @author OmniNest
 */
@Repository
public interface PhotoContentLabelRepository extends JpaRepository<PhotoContentLabel, UUID> {

    void deleteByRunId(UUID runId);

    List<PhotoContentLabel> findByOwnerUserIdAndPhotoIdAndStateOrderByNamespaceAscLabelCodeAsc(
            UUID ownerUserId,
            UUID photoId,
            String state
    );
}
