package com.omninest.modules.photos.repository;

import com.omninest.modules.photos.domain.PhotoFace;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/**
 * 照片人脸检测数据访问层。
 */
@Repository
public interface PhotoFaceRepository extends JpaRepository<PhotoFace, UUID> {

    List<PhotoFace> findByPhotoId(UUID photoId);

    List<PhotoFace> findByOwnerUserId(UUID ownerUserId);

    List<PhotoFace> findByClusterId(UUID clusterId);

    long countByClusterId(UUID clusterId);

    /**
     * 查询多张照片的人脸检测数据。
     *
     * @param photoIds 照片 ID 集合
     * @return 人脸检测数据
     */
    List<PhotoFace> findByPhotoIdIn(Collection<UUID> photoIds);

    /**
     * 按照片 ID 删除人脸检测数据
     */
    void deleteByPhotoId(UUID photoId);

    /**
     * 批量删除指定照片的人脸检测数据。
     *
     * @param photoIds 照片 ID 集合
     */
    void deleteByPhotoIdIn(Collection<UUID> photoIds);
}
