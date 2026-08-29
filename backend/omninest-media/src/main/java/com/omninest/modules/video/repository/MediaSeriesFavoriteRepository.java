package com.omninest.modules.video.repository;

import com.omninest.modules.video.domain.MediaSeriesFavorite;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MediaSeriesFavoriteRepository extends JpaRepository<MediaSeriesFavorite, UUID> {
    boolean existsByOwnerUserIdAndSeriesId(UUID ownerUserId, UUID seriesId);

    Optional<MediaSeriesFavorite> findByOwnerUserIdAndSeriesId(UUID ownerUserId, UUID seriesId);

    List<MediaSeriesFavorite> findByOwnerUserIdAndSeriesIdIn(UUID ownerUserId, Collection<UUID> seriesIds);

    void deleteByOwnerUserIdAndSeriesIdIn(UUID ownerUserId, Collection<UUID> seriesIds);
}
