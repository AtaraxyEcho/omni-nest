package com.omninest.modules.file.repository;

import com.omninest.modules.file.domain.SharedSpaceUsage;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface SharedSpaceUsageRepository extends JpaRepository<SharedSpaceUsage, UUID> {
    Optional<SharedSpaceUsage> findFirstBy();
}
