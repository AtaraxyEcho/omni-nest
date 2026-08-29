package com.omninest.modules.music.repository;

import com.omninest.modules.music.domain.MusicFavorite;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MusicFavoriteRepository extends JpaRepository<MusicFavorite, UUID> {
    List<MusicFavorite> findByOwnerUserIdOrderByCreatedAtDesc(UUID ownerUserId);

    List<MusicFavorite> findByOwnerUserIdAndTrackIdIn(UUID ownerUserId, Collection<UUID> trackIds);

    Optional<MusicFavorite> findByOwnerUserIdAndTrackId(UUID ownerUserId, UUID trackId);

    boolean existsByOwnerUserIdAndTrackId(UUID ownerUserId, UUID trackId);

    void deleteByOwnerUserIdAndTrackId(UUID ownerUserId, UUID trackId);

    void deleteByOwnerUserIdAndTrackIdIn(UUID ownerUserId, Collection<UUID> trackIds);

    /**
     * 按 trackId 删除所有用户的收藏（共享空间文件清理用）。
     */
    @Modifying(clearAutomatically = true)
    @Query("DELETE FROM MusicFavorite f WHERE f.trackId IN :trackIds")
    void deleteByTrackIdIn(@Param("trackIds") Collection<UUID> trackIds);
}
