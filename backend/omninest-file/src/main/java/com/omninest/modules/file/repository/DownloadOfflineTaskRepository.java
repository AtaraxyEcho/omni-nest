package com.omninest.modules.file.repository;

import com.omninest.modules.file.domain.DownloadOfflineTask;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DownloadOfflineTaskRepository extends JpaRepository<DownloadOfflineTask, UUID> {
    List<DownloadOfflineTask> findByOwnerUserIdOrderByCreatedAtDesc(UUID ownerUserId);

    Optional<DownloadOfflineTask> findByIdAndOwnerUserId(UUID id, UUID ownerUserId);
}
