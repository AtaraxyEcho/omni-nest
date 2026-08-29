package com.omninest.modules.photos.repository;

import com.omninest.modules.photos.domain.PhotoFaceCluster;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/**
 * 照片人脸聚类数据访问层。
 */
@Repository
public interface PhotoFaceClusterRepository extends JpaRepository<PhotoFaceCluster, UUID> {

    List<PhotoFaceCluster> findByOwnerUserIdOrderByFaceCountDesc(UUID ownerUserId);

    Optional<PhotoFaceCluster> findByIdAndOwnerUserId(UUID id, UUID ownerUserId);
}
