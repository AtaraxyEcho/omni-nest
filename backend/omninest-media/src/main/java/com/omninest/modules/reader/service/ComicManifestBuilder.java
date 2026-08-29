package com.omninest.modules.reader.service;

import com.omninest.modules.reader.domain.ReaderCatalogNode;
import com.omninest.modules.reader.domain.ReaderItem;
import com.omninest.modules.reader.domain.ReaderItemSource;
import com.omninest.modules.reader.domain.ReaderPage;
import com.omninest.modules.reader.repository.ReaderCatalogNodeRepository;
import com.omninest.modules.reader.repository.ReaderItemRepository;
import com.omninest.modules.reader.repository.ReaderItemSourceRepository;
import com.omninest.modules.reader.repository.ReaderPageRepository;
import com.omninest.modules.reader.service.model.ComicManifestDraft;
import com.omninest.modules.reader.service.model.ComicManifestDraft.ComicCatalogDraftNode;
import com.omninest.modules.reader.service.model.ComicManifestDraft.ComicPageDraft;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 漫画清单构建器：将 Parser 输出的 ComicManifestDraft 写入数据库。
 *
 * <p>职责：
 * <ul>
 *   <li>将 ComicPageDraft 转为 ReaderPage 实体</li>
 *   <li>将 ComicCatalogDraftNode 转为 ReaderCatalogNode 实体</li>
 *   <li>通过 catalogKey 将页面映射到目录节点</li>
 *   <li>计算目录节点的 pageStartIndex/pageEndIndex</li>
 *   <li>统一重建清单（排序来源、重排页面、递增版本）</li>
 * </ul>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ComicManifestBuilder {

    private final ReaderItemRepository itemRepository;
    private final ReaderItemSourceRepository sourceRepository;
    private final ReaderCatalogNodeRepository catalogRepository;
    private final ReaderPageRepository pageRepository;

    /**
     * 将 Parser 输出的草稿写入数据库。
     *
     * <p>创建页面记录，构建目录树，更新 source 状态。
     * 不负责 manifestVersion 递增（由 rebuildComicManifest 统一处理）。
     *
     * @param draft Parser 输出的清单草稿
     */
    @Transactional(rollbackFor = Exception.class)
    public List<ReaderPage> applyDraft(ComicManifestDraft draft) {
        UUID itemId = draft.itemId();
        UUID sourceId = draft.sourceId();

        pageRepository.deleteBySourceId(sourceId);

        // 将 ComicPageDraft 转为 ReaderPage 实体
        List<ReaderPage> newPages = new ArrayList<>();
        for (ComicPageDraft pageDraft : draft.pages()) {
            ReaderPage page = new ReaderPage();
            page.setReaderItemId(itemId);
            page.setSourceId(sourceId);
            page.setSourcePageIndex(pageDraft.sourcePageIndex());
            page.setSourcePath(pageDraft.sourcePath());
            page.setWidth(pageDraft.width() > 0 ? pageDraft.width() : null);
            page.setHeight(pageDraft.height() > 0 ? pageDraft.height() : null);
            page.setFingerprint(pageDraft.fingerprint());
            page.setEntryIndex(pageDraft.entryIndex());
            page.setMimeType(pageDraft.mimeType());
            page.setByteSize(pageDraft.byteSize());
            page.setCatalogKey(pageDraft.catalogKey());
            newPages.add(page);
        }
        List<ReaderPage> savedPages = pageRepository.saveAll(newPages);

        // 2. 更新 source 页数和状态
        ReaderItemSource source = sourceRepository.findById(sourceId).orElse(null);
        if (source != null) {
            source.setPageCount(newPages.size());
            sourceRepository.save(source);
        }

        log.debug("草稿应用完成: itemId={}, sourceId={}, pages={}", itemId, sourceId, savedPages.size());
        return savedPages;
    }

    /**
     * 统一重建漫画清单：排序来源、重排页面、重建目录、递增版本。
     *
     * <p>所有格式（CBZ/ZIP/EPUB）解析完页面后都调用此方法完成最终构建。
     * 使用 source-aware 目录构建：目录 key 包含 sourceId，避免多源同名目录冲突。
     *
     * @param itemId 漫画作品 ID
     */
    @Transactional(rollbackFor = Exception.class)
    public void rebuildComicManifest(UUID itemId) {
        rebuildComicManifest(itemId, List.of());
    }

    /**
     * 使用解析器目录草稿重建漫画清单。
     *
     * @param itemId 漫画作品 ID
     * @param catalogDrafts 解析器输出的目录节点草稿
     */
    @Transactional(rollbackFor = Exception.class)
    public void rebuildComicManifest(UUID itemId, List<ComicCatalogDraftNode> catalogDrafts) {
        // 1. 按结构化排序字段排序所有来源
        List<ReaderItemSource> sources = new ArrayList<>(sourceRepository.findByReaderItemId(itemId));
        sources.sort(Comparator
                .comparingInt((ReaderItemSource s) -> s.getSeasonNo() != null ? s.getSeasonNo() : Integer.MAX_VALUE)
                .thenComparingInt(s -> s.getVolumeNo() != null ? s.getVolumeNo() : Integer.MAX_VALUE)
                .thenComparingInt(s -> s.getChapterStart() != null ? s.getChapterStart() : Integer.MAX_VALUE)
                .thenComparingInt(s -> s.getExtraOrder() != null ? s.getExtraOrder() : Integer.MAX_VALUE)
                .thenComparing(s -> s.getSourceSortKey() != null ? s.getSourceSortKey() : ""));

        // 2. 按来源顺序 + sourcePageIndex 重排全局 pageIndex
        List<ReaderPage> allPages = new ArrayList<>();
        for (ReaderItemSource src : sources) {
            List<ReaderPage> sourcePages = pageRepository.findBySourceId(src.getId());
            sourcePages.sort(Comparator.comparingInt(ReaderPage::getSourcePageIndex));
            allPages.addAll(sourcePages);
        }
        for (int i = 0; i < allPages.size(); i++) {
            allPages.get(i).setPageIndex(i);
        }
        pageRepository.saveAll(allPages);

        // 3. 构建 source-aware 目录
        catalogRepository.deleteByReaderItemId(itemId);

        // 构建来源 ID → 来源名称映射
        Map<UUID, String> sourceIdToName = new HashMap<>();
        for (ReaderItemSource src : sources) {
            sourceIdToName.put(src.getId(), src.getSourceName());
        }

        // 全量页面是跨来源目录的事实来源，当前解析任务的草稿仅作为无页面键时的回退。
        List<ReaderCatalogNode> catalogNodes = buildParsedCatalog(allPages, itemId, sourceIdToName);
        if (catalogNodes.isEmpty()) {
            catalogNodes = buildDraftCatalog(catalogDrafts, itemId);
        }
        if (catalogNodes.isEmpty()) {
            catalogNodes = buildSourceAwareCatalog(allPages, itemId, sourceIdToName);
        }
        Instant catalogCreatedAt = Instant.now();
        for (ReaderCatalogNode node : catalogNodes) {
            if (node.getCreatedAt() == null) {
                node.setCreatedAt(catalogCreatedAt);
            }
        }
        catalogNodes = catalogRepository.saveAll(catalogNodes);

        // 4. 通过 catalogKey 将页面映射到目录节点
        Map<String, UUID> catalogKeyToNodeId = new HashMap<>();
        for (ReaderCatalogNode node : catalogNodes) {
            if (node.getCatalogKey() != null) {
                catalogKeyToNodeId.put(node.getCatalogKey(), node.getId());
            }
        }

        for (ReaderPage page : allPages) {
            String catalogKey = resolvePageCatalogKey(page, sourceIdToName);
            UUID nodeId = catalogKeyToNodeId.get(catalogKey);
            if (nodeId == null) {
                // 回退到 ROOT
                nodeId = catalogKeyToNodeId.getOrDefault("root", null);
            }
            page.setCatalogNodeId(nodeId);
        }
        pageRepository.saveAll(allPages);

        // 5. 计算目录节点的 pageStartIndex/pageEndIndex 和页数
        recalculateNodePageRanges(itemId, catalogNodes, allPages);

        // 6. 递增 manifestVersion
        ReaderItem item = itemRepository.findById(itemId).orElse(null);
        if (item != null) {
            item.setManifestVersion(item.getManifestVersion() + 1);
            itemRepository.save(item);
        }

        log.debug("漫画清单重建完成: itemId={}, sources={}, pages={}", itemId, sources.size(), allPages.size());
    }

    /**
     * 根据解析器写入页面的 catalogKey 构建目录。
     */
    private List<ReaderCatalogNode> buildParsedCatalog(
            List<ReaderPage> pages,
            UUID itemId,
            Map<UUID, String> sourceIdToName) {
        Map<String, ReaderCatalogNode> keyMap = new HashMap<>();
        List<ReaderCatalogNode> nodes = new ArrayList<>();

        ReaderCatalogNode rootNode = createCatalogNode(itemId, null, null, "ROOT", "全部", "root");
        nodes.add(rootNode);
        keyMap.put("root", rootNode);

        for (ReaderPage page : pages) {
            String catalogKey = page.getCatalogKey();
            if (catalogKey == null || catalogKey.isBlank()) {
                continue;
            }
            String[] segments = catalogKey.split("/");
            StringBuilder currentKey = new StringBuilder();
            String parentKey = "root";
            for (String segment : segments) {
                if (segment == null || segment.isBlank()) {
                    continue;
                }
                if (currentKey.length() > 0) {
                    currentKey.append('/');
                }
                currentKey.append(segment);
                String key = currentKey.toString();
                if (!keyMap.containsKey(key)) {
                    ReaderCatalogNode parent = keyMap.getOrDefault(parentKey, rootNode);
                    UUID segmentSourceId = parseSourceId(segment);
                    String title = segmentSourceId == null
                            ? segmentTitle(segment)
                            : stripExtension(sourceIdToName.getOrDefault(segmentSourceId, "漫画来源"));
                    String nodeType = segmentSourceId == null ? detectNodeType(title) : "COLLECTION";
                    ReaderCatalogNode node = createCatalogNode(
                            itemId,
                            parent.getId(),
                            segmentSourceId == null ? page.getSourceId() : segmentSourceId,
                            nodeType,
                            title,
                            key);
                    nodes.add(node);
                    keyMap.put(key, node);
                }
                parentKey = key;
            }
        }

        if (nodes.size() <= 1) {
            return List.of();
        }
        assignSortIndices(nodes);
        return nodes;
    }

    /**
     * 根据解析器提供的目录草稿构建目录。
     */
    private List<ReaderCatalogNode> buildDraftCatalog(List<ComicCatalogDraftNode> drafts, UUID itemId) {
        if (drafts == null || drafts.isEmpty()) {
            return List.of();
        }

        List<ReaderCatalogNode> nodes = new ArrayList<>();
        Map<String, ReaderCatalogNode> keyMap = new HashMap<>();
        ReaderCatalogNode rootNode = createCatalogNode(itemId, null, null, "ROOT", "全部", "root");
        nodes.add(rootNode);
        keyMap.put("root", rootNode);

        List<ComicCatalogDraftNode> sortedDrafts = new ArrayList<>(drafts);
        sortedDrafts.sort(Comparator
                .comparingInt((ComicCatalogDraftNode node) -> depthOf(node.catalogKey()))
                .thenComparingInt(ComicCatalogDraftNode::sortOrder));

        for (ComicCatalogDraftNode draft : sortedDrafts) {
            if (draft.catalogKey() == null || draft.catalogKey().isBlank()
                    || keyMap.containsKey(draft.catalogKey())) {
                continue;
            }

            ReaderCatalogNode parent = resolveDraftParent(draft, itemId, keyMap, nodes, rootNode);
            ReaderCatalogNode node = createCatalogNode(
                    itemId,
                    parent.getId(),
                    draft.sourceId(),
                    draft.nodeType(),
                    draft.title(),
                    draft.catalogKey());
            node.setSortIndex(draft.sortOrder());
            nodes.add(node);
            keyMap.put(draft.catalogKey(), node);
        }

        if (nodes.size() <= 1) {
            return List.of();
        }
        assignSortIndices(nodes);
        return nodes;
    }

    private ReaderCatalogNode resolveDraftParent(
            ComicCatalogDraftNode draft,
            UUID itemId,
            Map<String, ReaderCatalogNode> keyMap,
            List<ReaderCatalogNode> nodes,
            ReaderCatalogNode rootNode) {
        String parentKey = draft.parentKey();
        if (parentKey == null || parentKey.isBlank()) {
            return rootNode;
        }
        ReaderCatalogNode existing = keyMap.get(parentKey);
        if (existing != null) {
            return existing;
        }

        ReaderCatalogNode parent = rootNode;
        String[] segments = parentKey.split("/");
        StringBuilder currentKey = new StringBuilder();
        for (String segment : segments) {
            if (segment == null || segment.isBlank()) {
                continue;
            }
            if (currentKey.length() > 0) {
                currentKey.append('/');
            }
            currentKey.append(segment);
            String key = currentKey.toString();
            ReaderCatalogNode node = keyMap.get(key);
            if (node == null) {
                node = createCatalogNode(
                        itemId,
                        parent.getId(),
                        null,
                        detectNodeType(segmentTitle(segment)),
                        segmentTitle(segment),
                        key);
                nodes.add(node);
                keyMap.put(key, node);
            }
            parent = node;
        }
        return parent;
    }

    private int depthOf(String catalogKey) {
        if (catalogKey == null || catalogKey.isBlank()) {
            return 0;
        }
        return catalogKey.split("/").length;
    }

    private ReaderCatalogNode createCatalogNode(
            UUID itemId,
            UUID parentId,
            UUID sourceId,
            String nodeType,
            String title,
            String catalogKey) {
        ReaderCatalogNode node = new ReaderCatalogNode();
        node.setId(UUID.randomUUID());
        node.setReaderItemId(itemId);
        node.setParentId(parentId);
        node.setSourceId(sourceId);
        node.setNodeType(nodeType);
        node.setTitle(title);
        node.setCatalogKey(catalogKey);
        return node;
    }

    private String segmentTitle(String segment) {
        int colonIndex = segment.indexOf(':');
        int lastColonIndex = segment.lastIndexOf(':');
        if (colonIndex >= 0 && colonIndex + 1 < segment.length()) {
            if (lastColonIndex > colonIndex && lastColonIndex + 1 < segment.length()
                    && segment.substring(lastColonIndex + 1).matches("\\d+")) {
                return segment.substring(colonIndex + 1, lastColonIndex);
            }
            return segment.substring(colonIndex + 1);
        }
        return segment;
    }

    private UUID parseSourceId(String segment) {
        if (segment == null || !segment.startsWith("source:")) {
            return null;
        }
        try {
            return UUID.fromString(segment.substring("source:".length()));
        } catch (IllegalArgumentException exception) {
            log.warn("漫画目录来源键无效: segment={}", segment);
            return null;
        }
    }

    /**
     * 构建 source-aware 目录树。
     * 使用 sourceId + normalizedPath 作为唯一键，避免多源同名目录冲突。
     * 优先从 source 元数据（season/volume/chapter）构建聚合目录。
     */
    private List<ReaderCatalogNode> buildSourceAwareCatalog(
            List<ReaderPage> pages, UUID itemId, Map<UUID, String> sourceIdToName) {

        List<ReaderCatalogNode> nodes = new ArrayList<>();

        // 创建 ROOT 节点
        ReaderCatalogNode rootNode = new ReaderCatalogNode();
        rootNode.setId(UUID.randomUUID());
        rootNode.setReaderItemId(itemId);
        rootNode.setNodeType("ROOT");
        rootNode.setTitle("全部");
        rootNode.setSortIndex(0);
        rootNode.setCatalogKey("root");
        nodes.add(rootNode);

        // 检查是否有 source 可以从文件名推断季/卷/话结构
        boolean hasStructuredSources = sourceIdToName.entrySet().stream()
                .anyMatch(e -> !"ROOT".equals(detectNodeType(stripExtension(e.getValue()))));

        if (hasStructuredSources) {
            // 从 source 元数据构建聚合目录
            buildAggregatedCatalog(nodes, itemId, sourceIdToName, pages);
        } else {
            // 检查页面是否有内部目录结构
            boolean hasInternalDirs = pages.stream()
                    .anyMatch(p -> p.getSourcePath() != null && p.getSourcePath().contains("/"));

            if (hasInternalDirs) {
                // 从页面路径构建 source-aware 内部目录
                buildInternalCatalog(nodes, itemId, pages, sourceIdToName);
            } else {
                // 扁平结构：每个 source 一个章节节点
                buildFlatSourceCatalog(nodes, itemId, sourceIdToName);
            }
        }

        // 按深度优先分配 sortIndex
        assignSortIndices(nodes);
        return nodes;
    }

    /**
     * 从 source 文件名元数据构建聚合目录（季→卷→话）。
     * 多个 source 可以挂到同一季/卷下，叶子节点保留各自 sourceId。
     */
    private void buildAggregatedCatalog(
            List<ReaderCatalogNode> nodes, UUID itemId,
            Map<UUID, String> sourceIdToName, List<ReaderPage> pages) {

        // 收集每个 source 的元数据
        Map<UUID, SourceMeta> metaMap = new HashMap<>();
        for (Map.Entry<UUID, String> entry : sourceIdToName.entrySet()) {
            String name = stripExtension(entry.getValue());
            SourceMeta meta = parseSourceMeta(entry.getKey(), name);
            metaMap.put(entry.getKey(), meta);
        }

        // 构建聚合节点：season:N, season:N/volume:N
        Map<String, ReaderCatalogNode> keyMap = new HashMap<>();
        for (SourceMeta meta : metaMap.values()) {
            if (meta.seasonNo != null) {
                String seasonKey = "season:" + meta.seasonNo;
                if (!keyMap.containsKey(seasonKey)) {
                    ReaderCatalogNode seasonNode = new ReaderCatalogNode();
                    seasonNode.setId(UUID.randomUUID());
                    seasonNode.setReaderItemId(itemId);
                    seasonNode.setParentId(nodes.get(0).getId());
                    seasonNode.setNodeType("SEASON");
                    seasonNode.setTitle("第" + meta.seasonNo + "季");
                    seasonNode.setCatalogKey(seasonKey);
                    nodes.add(seasonNode);
                    keyMap.put(seasonKey, seasonNode);
                }

                if (meta.volumeNo != null) {
                    String volKey = seasonKey + "/volume:" + meta.volumeNo;
                    if (!keyMap.containsKey(volKey)) {
                        ReaderCatalogNode volNode = new ReaderCatalogNode();
                        volNode.setId(UUID.randomUUID());
                        volNode.setReaderItemId(itemId);
                        volNode.setParentId(keyMap.get(seasonKey).getId());
                        volNode.setNodeType("VOLUME");
                        volNode.setTitle("第" + meta.volumeNo + "卷");
                        volNode.setCatalogKey(volKey);
                        nodes.add(volNode);
                        keyMap.put(volKey, volNode);
                    }
                }
            }
        }

        // 为每个 source 创建叶子节点
        for (SourceMeta meta : metaMap.values()) {
            String leafKey = buildLeafCatalogKey(meta);
            if (keyMap.containsKey(leafKey)) continue;

            ReaderCatalogNode leafNode = new ReaderCatalogNode();
            leafNode.setId(UUID.randomUUID());
            leafNode.setReaderItemId(itemId);
            leafNode.setSourceId(meta.sourceId);
            leafNode.setNodeType(detectNodeType(stripExtension(meta.sourceName)));
            leafNode.setTitle(stripExtension(meta.sourceName));
            leafNode.setCatalogKey(leafKey);

            // 确定父节点
            String parentKey = buildParentCatalogKey(meta);
            if (parentKey != null && keyMap.containsKey(parentKey)) {
                leafNode.setParentId(keyMap.get(parentKey).getId());
            } else {
                leafNode.setParentId(nodes.get(0).getId());
            }

            nodes.add(leafNode);
            keyMap.put(leafKey, leafNode);
        }

        // 将页面分配到叶子节点的 catalogKey
        // （在 rebuildComicManifest 中通过 resolvePageCatalogKey 完成）
    }

    /**
     * 从页面路径构建 source-aware 内部目录。
     * 使用 sourceId + normalizedPath 作为唯一键。
     */
    private void buildInternalCatalog(
            List<ReaderCatalogNode> nodes, UUID itemId,
            List<ReaderPage> pages, Map<UUID, String> sourceIdToName) {

        // 收集所有 sourceId + 目录路径的唯一组合
        Map<String, ReaderCatalogNode> keyMap = new HashMap<>();

        for (ReaderPage page : pages) {
            String parentDir = getParentDir(page.getSourcePath());
            if (parentDir == null || parentDir.isEmpty()) continue;

            // 逐级构建目录节点
            String[] segments = parentDir.split("/");
            StringBuilder currentPath = new StringBuilder();
            for (int i = 0; i < segments.length; i++) {
                if (i > 0) currentPath.append('/');
                currentPath.append(segments[i]);

                // source-aware key: source:{sourceId}/path:{normalizedPath}
                String catalogKey = "source:" + page.getSourceId() + "/path:" + currentPath;

                if (!keyMap.containsKey(catalogKey)) {
                    String dirName = segments[i];
                    String nodeType = detectNodeType(dirName);

                    ReaderCatalogNode node = new ReaderCatalogNode();
                    node.setId(UUID.randomUUID());
                    node.setReaderItemId(itemId);
                    node.setNodeType(nodeType);
                    node.setTitle(dirName);
                    node.setCatalogKey(catalogKey);
                    node.setSourceId(page.getSourceId());

                    // 确定父节点
                    if (i == 0) {
                        // 检查是否有对应的 source 叶子节点
                        String sourceLeafKey = "source:" + page.getSourceId();
                        ReaderCatalogNode sourceLeaf = keyMap.get(sourceLeafKey);
                        if (sourceLeaf != null) {
                            node.setParentId(sourceLeaf.getId());
                        } else {
                            node.setParentId(nodes.get(0).getId());
                        }
                    } else {
                        String parentCatalogKey = "source:" + page.getSourceId() + "/path:" + currentPath.substring(0, currentPath.length() - segments[i].length() - 1);
                        ReaderCatalogNode parent = keyMap.get(parentCatalogKey);
                        if (parent != null) {
                            node.setParentId(parent.getId());
                        } else {
                            node.setParentId(nodes.get(0).getId());
                        }
                    }

                    nodes.add(node);
                    keyMap.put(catalogKey, node);
                }
            }
        }
    }

    /**
     * 扁平结构：每个 source 创建一个章节节点。
     */
    private void buildFlatSourceCatalog(
            List<ReaderCatalogNode> nodes, UUID itemId, Map<UUID, String> sourceIdToName) {

        int sortIndex = 1;
        for (Map.Entry<UUID, String> entry : sourceIdToName.entrySet()) {
            UUID sourceId = entry.getKey();
            String sourceName = entry.getValue();
            String stripped = stripExtension(sourceName);
            String nodeType = detectNodeType(stripped);

            if ("ROOT".equals(nodeType)) continue;

            ReaderCatalogNode sourceNode = new ReaderCatalogNode();
            sourceNode.setId(UUID.randomUUID());
            sourceNode.setReaderItemId(itemId);
            sourceNode.setParentId(nodes.get(0).getId());
            sourceNode.setSourceId(sourceId);
            sourceNode.setNodeType(nodeType);
            sourceNode.setTitle(stripped);
            sourceNode.setSortIndex(sortIndex++);
            sourceNode.setCatalogKey("source:" + sourceId);
            nodes.add(sourceNode);
        }
    }

    /**
     * 解析页面对应的 catalogKey。
     * 优先匹配 source-aware 路径，回退到 source 叶子节点。
     */
    private String resolvePageCatalogKey(ReaderPage page, Map<UUID, String> sourceIdToName) {
        if (page.getCatalogKey() != null && !page.getCatalogKey().isBlank()) {
            return page.getCatalogKey();
        }
        String parentDir = getParentDir(page.getSourcePath());
        if (parentDir != null && !parentDir.isEmpty()) {
            return "source:" + page.getSourceId() + "/path:" + parentDir;
        }
        return "source:" + page.getSourceId();
    }

    /**
     * 重新计算目录节点的 pageStartIndex/pageEndIndex 和页数。
     */
    private void recalculateNodePageRanges(
            UUID itemId, List<ReaderCatalogNode> catalogNodes, List<ReaderPage> allPages) {

        // 收集每个节点的直接页面
        Map<UUID, List<Integer>> nodePageIndices = new HashMap<>();
        for (ReaderPage page : allPages) {
            if (page.getCatalogNodeId() != null) {
                nodePageIndices.computeIfAbsent(page.getCatalogNodeId(), k -> new ArrayList<>())
                        .add(page.getPageIndex());
            }
        }

        // 构建父→子映射
        Map<UUID, List<ReaderCatalogNode>> childrenMap = new HashMap<>();
        for (ReaderCatalogNode node : catalogNodes) {
            if (node.getParentId() != null) {
                childrenMap.computeIfAbsent(node.getParentId(), k -> new ArrayList<>()).add(node);
            }
        }

        // 递归聚合
        for (ReaderCatalogNode node : catalogNodes) {
            List<Integer> allIndices = aggregatePageIndices(node.getId(), nodePageIndices, childrenMap);
            if (!allIndices.isEmpty()) {
                allIndices.sort(Integer::compareTo);
                node.setPageIndexStart(allIndices.get(0));
                node.setPageIndexEnd(allIndices.get(allIndices.size() - 1));
                node.setPageCount(allIndices.size());
            } else {
                node.setPageCount(0);
            }
        }
        catalogRepository.saveAll(catalogNodes);
    }

    private List<Integer> aggregatePageIndices(
            UUID nodeId,
            Map<UUID, List<Integer>> directCounts,
            Map<UUID, List<ReaderCatalogNode>> childrenMap) {

        List<Integer> indices = new ArrayList<>(directCounts.getOrDefault(nodeId, List.of()));
        for (ReaderCatalogNode child : childrenMap.getOrDefault(nodeId, List.of())) {
            indices.addAll(aggregatePageIndices(child.getId(), directCounts, childrenMap));
        }
        return indices;
    }

    // ── Helper methods ────────────────────────────────────────────

    private static class SourceMeta {
        UUID sourceId;
        String sourceName;
        Integer seasonNo;
        Integer volumeNo;
        Integer chapterStart;
        Integer chapterEnd;
        Integer extraOrder;
    }

    private SourceMeta parseSourceMeta(UUID sourceId, String name) {
        SourceMeta meta = new SourceMeta();
        meta.sourceId = sourceId;
        meta.sourceName = name;
        if (name == null) return meta;
        String lower = name.toLowerCase().replaceAll("\\.[^.]+$", "");

        Matcher season = Pattern.compile("s(\\d+)|season\\s*(\\d+)|第(\\d+)季").matcher(lower);
        if (season.find()) {
            String num = season.group(1) != null ? season.group(1) : season.group(2) != null ? season.group(2) : season.group(3);
            meta.seasonNo = Integer.parseInt(num);
        }

        Matcher vol = Pattern.compile("vol\\.?\\s*(\\d+)|volume\\s*(\\d+)|第(\\d+)卷").matcher(lower);
        if (vol.find()) {
            String num = vol.group(1) != null ? vol.group(1) : vol.group(2) != null ? vol.group(2) : vol.group(3);
            meta.volumeNo = Integer.parseInt(num);
        }

        // 话/章区间：兼容 ch/chapter/第X话章 及日式"話001-010"
        ComicVolumeParser.PartInfo part = ComicVolumeParser.parse(name);
        if (part.matched() && part.partNo() != null
                && ("EPISODE".equals(part.partKind()) || "CHAPTER".equals(part.partKind()))) {
            meta.chapterStart = part.partNo();
            meta.chapterEnd = part.rangeEnd() != null ? part.rangeEnd() : part.partNo();
        } else {
            Matcher range = Pattern.compile(
                    "(?:ch\\.?\\s*|chapter\\s*|第)(\\d{1,4})\\s*[-~]\\s*(\\d{1,4})(?:话|章)?").matcher(lower);
            if (range.find()) {
                meta.chapterStart = Integer.parseInt(range.group(1));
                meta.chapterEnd = Integer.parseInt(range.group(2));
            } else {
                Matcher singleCh = Pattern.compile("(?:ch\\.?\\s*|chapter\\s*|第)(\\d+)(?:话|章)?").matcher(lower);
                if (singleCh.find()) {
                    int ch = Integer.parseInt(singleCh.group(1));
                    meta.chapterStart = ch;
                    meta.chapterEnd = ch;
                }
            }
        }

        if (lower.contains("extra") || lower.contains("番外") || lower.contains("special")) {
            Matcher extraNum = Pattern.compile("(?:extra|番外|special)\\s*(\\d+)").matcher(lower);
            meta.extraOrder = extraNum.find() ? Integer.parseInt(extraNum.group(1)) : 1;
        }

        return meta;
    }

    private String buildLeafCatalogKey(SourceMeta meta) {
        StringBuilder key = new StringBuilder();
        if (meta.seasonNo != null) key.append("season:").append(meta.seasonNo);
        if (meta.volumeNo != null) key.append("/volume:").append(meta.volumeNo);
        if (key.length() > 0) key.append('/');
        key.append("source:").append(meta.sourceId);
        return key.toString();
    }

    private String buildParentCatalogKey(SourceMeta meta) {
        if (meta.seasonNo != null && meta.volumeNo != null) {
            return "season:" + meta.seasonNo + "/volume:" + meta.volumeNo;
        }
        if (meta.seasonNo != null) {
            return "season:" + meta.seasonNo;
        }
        return null;
    }

    /**
     * 深度优先分配 sortIndex。
     */
    private void assignSortIndices(List<ReaderCatalogNode> nodes) {
        Map<UUID, List<ReaderCatalogNode>> childrenMap = new HashMap<>();
        ReaderCatalogNode root = null;
        for (ReaderCatalogNode node : nodes) {
            if ("ROOT".equals(node.getNodeType())) {
                root = node;
            }
            if (node.getParentId() != null) {
                childrenMap.computeIfAbsent(node.getParentId(), k -> new ArrayList<>()).add(node);
            }
        }
        if (root == null) return;

        int[] counter = {0};
        assignDfs(root, childrenMap, counter);
    }

    private void assignDfs(ReaderCatalogNode node, Map<UUID, List<ReaderCatalogNode>> childrenMap, int[] counter) {
        node.setSortIndex(counter[0]++);
        for (ReaderCatalogNode child : childrenMap.getOrDefault(node.getId(), List.of())) {
            assignDfs(child, childrenMap, counter);
        }
    }

    private String detectNodeType(String name) {
        if (name == null) return "CHAPTER";
        String lower = name.toLowerCase();
        if (lower.matches("s\\d+.*|season\\s*\\d+|第.+季")) return "SEASON";
        if (lower.matches("vol\\.?\\s*\\d+|volume\\s*\\d+|第.+卷")) return "VOLUME";
        if (lower.matches("ch\\.?\\s*\\d+|chapter\\s*\\d+|第.+话|第.+章")) return "CHAPTER";
        if (lower.matches("\\d+\\s*[-~]\\s*\\d+")) return "COLLECTION";
        if (lower.contains("extra") || lower.contains("sp") || lower.contains("番外")) return "EXTRA";
        return "CHAPTER";
    }

    private String stripExtension(String fileName) {
        if (fileName == null) return "";
        int lastDot = fileName.lastIndexOf('.');
        return lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
    }

    private String getParentDir(String path) {
        if (path == null) return null;
        int lastSlash = path.lastIndexOf('/');
        return lastSlash > 0 ? path.substring(0, lastSlash) : null;
    }
}
