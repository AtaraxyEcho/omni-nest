package com.omninest.modules.search.service;

import com.omninest.modules.search.dto.SearchResultDto;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * 文件搜索应用服务，将 Lucene 候选结果与数据库当前状态合并。
 *
 * @author OmniNest
 */
@Service
@RequiredArgsConstructor
public class FileSearchService {

    private static final int MAX_RESULTS = 50;
    private static final int CANDIDATE_MULTIPLIER = 3;
    private final FileSearchIndexService fileSearchIndexService;
    private final SearchableFileQuery searchableFileQuery;

    /**
     * 搜索当前用户个人空间中的活动文件。
     *
     * @param ownerUserId 当前用户 ID
     * @param query 搜索关键词
     * @return 经数据库复核的搜索结果
     */
    public List<SearchResultDto> search(UUID ownerUserId, String query) {
        if (query == null || query.isBlank()) {
            return List.of();
        }
        List<SearchResultDto> candidates = fileSearchIndexService.search(
                ownerUserId,
                query.trim(),
                MAX_RESULTS * CANDIDATE_MULTIPLIER
        );
        if (candidates.isEmpty()) {
            return List.of();
        }
        List<UUID> candidateIds = candidates.stream().map(SearchResultDto::fileId).toList();
        Map<UUID, String> currentNames = searchableFileQuery.findCurrentNames(ownerUserId, candidateIds);
        return candidates.stream()
                .filter(candidate -> currentNames.containsKey(candidate.fileId()))
                .limit(MAX_RESULTS)
                .map(candidate -> new SearchResultDto(
                        candidate.fileId(),
                        currentNames.get(candidate.fileId()),
                        candidate.snippet(),
                        candidate.score()
                ))
                .toList();
    }
}
