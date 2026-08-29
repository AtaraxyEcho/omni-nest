package com.omninest.modules.search.repository;

import com.omninest.modules.search.domain.SearchIndexState;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 搜索索引状态仓储
 */
public interface SearchIndexStateRepository extends JpaRepository<SearchIndexState, UUID> {

    Optional<SearchIndexState> findByOwnerUserIdIsNull();
}
