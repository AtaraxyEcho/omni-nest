package com.omninest.modules.reader.service;

import com.omninest.modules.reader.service.model.ComicManifestDraft.ComicCatalogDraftNode;
import com.omninest.modules.reader.service.model.ComicManifestDraft.ComicPageDraft;
import com.omninest.modules.reader.service.model.ReaderCoverDraft;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import lombok.extern.slf4j.Slf4j;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

/**
 * EPUB 漫画专用解析器。
 *
 * <p>解析流程：container.xml → OPF → manifest/spine → nav/toc → 页面图片。
 * 使用 XML parser 解析 OPF，不用正则。
 * 支持 RTL/LTR、SVG wrapper、URL decode、相对路径规范化。
 * 按 entry 流式读取，不全量加载图片到内存。
 *
 * @author OmniNest
 */
@Slf4j
public class ComicEpubParser {

    private static final long MAX_COVER_BYTES = 20L * 1024 * 1024;

    /**
     * EPUB 解析结果。
     */
    public record EpubParseResult(
            String title,
            String author,
            String readingDirection,
            List<EpubSpineItem> spine,
            Map<String, EpubManifestItem> manifest,
            List<EpubTocEntry> toc,
            EpubCover cover
    ) {}

    /**
     * EPUB 封面引用。
     *
     * @param path 压缩包内图片路径
     * @param mimeType 图片 MIME 类型
     */
    public record EpubCover(String path, String mimeType) {
    }

    /**
     * OPF manifest 条目。
     */
    public record EpubManifestItem(
            String id,
            String href,
            String mediaType,
            String properties
    ) {}

    /**
     * Spine 条目（阅读顺序）。
     */
    public record EpubSpineItem(
            String idref,
            boolean linear
    ) {}

    /**
     * 目录条目。
     */
    public record EpubTocEntry(
            String title,
            String href,
            int level,
            List<EpubTocEntry> children
    ) {}

    // 基于 EpubArchive 的流式解析方法，不在内存中保留图片正文。

    /**
     * 使用 EpubArchive 解析 EPUB 元数据（不读取图片）。
     * 随机访问小文件，不将整个 EPUB 读入内存。
     *
     * @param archive EPUB 文件的随机访问抽象
     * @return 解析结果
     */
    public EpubParseResult parseMetadata(EpubArchive archive) {
        try {
            // 1. 找 container.xml → OPF 路径
            String containerXml = archive.readSmallText("META-INF/container.xml");
            if (containerXml == null) {
                log.warn("EPUB 缺少 container.xml");
                return null;
            }
            String opfPath = parseContainerXml(containerXml);
            if (opfPath == null) {
                log.warn("EPUB container.xml 未指定 OPF 路径");
                return null;
            }

            // 2. 读取 OPF
            String opfXml = archive.readSmallText(opfPath);
            if (opfXml == null) {
                log.warn("EPUB OPF 文件不存在: pathLength={}", opfPath.toString().length());
                return null;
            }

            String opfDir = "";
            int lastSlash = opfPath.lastIndexOf('/');
            if (lastSlash > 0) {
                opfDir = opfPath.substring(0, lastSlash + 1);
            }

            // 3. 解析 OPF
            Document opfDoc = parseXml(opfXml);
            String title = extractMetadataText(opfDoc, "title");
            String author = extractMetadataText(opfDoc, "creator");

            // manifest
            Map<String, EpubManifestItem> manifest = parseManifest(opfDoc, opfDir);

            // spine
            List<EpubSpineItem> spine = parseSpine(opfDoc);

            // reading direction
            String readingDirection = null;
            Element spineElement = (Element) opfDoc.getElementsByTagName("spine").item(0);
            if (spineElement != null) {
                readingDirection = spineElement.getAttribute("page-progression-direction");
                if (readingDirection.isEmpty()) readingDirection = null;
            }

            // 4. 尝试读取 nav.xhtml 或 toc.ncx
            List<EpubTocEntry> toc = new ArrayList<>();
            String navPath = findNavPath(manifest);
            if (navPath != null) {
                String navHtml = archive.readSmallText(navPath);
                if (navHtml != null) {
                    toc = parseNavToc(navHtml, getParentDir(navPath));
                }
            }
            if (toc.isEmpty()) {
                String ncxPath = findNcxPath(manifest);
                if (ncxPath != null) {
                    String ncxXml = archive.readSmallText(ncxPath);
                    if (ncxXml != null) {
                        toc = parseNcxToc(ncxXml, getParentDir(ncxPath));
                    }
                }
            }

            EpubCover cover = findCover(archive, opfDoc, opfDir, manifest, spine);
            return new EpubParseResult(title, author, readingDirection, spine, manifest, toc, cover);
        } catch (Exception e) {
            log.error("EPUB 元数据解析失败", e);
            return null;
        }
    }

    /**
     * 使用 EpubArchive 按 spine 顺序提取页面草稿。
     * 不将图片读入内存，只读取头部获取宽高。
     * sourcePath 保存图片 entry 路径，用于按需读取。
     *
     * @param archive    EPUB 文件的随机访问抽象
     * @param parseResult 之前解析的元数据
     * @param sourceId   来源 ID
     * @return 页面草稿列表
     */
    public List<ComicPageDraft> extractPageDrafts(EpubArchive archive, EpubParseResult parseResult, UUID sourceId) {
        List<ComicPageDraft> pages = new ArrayList<>();
        Map<String, String> spineCatalogKeys = buildSpineCatalogKeys(parseResult, sourceId);
        int pageIndex = 0;

        for (EpubSpineItem spineItem : parseResult.spine()) {
            if (!spineItem.linear()) continue;

            EpubManifestItem manifestItem = parseResult.manifest().get(spineItem.idref());
            if (manifestItem == null) continue;

            String xhtmlPath = manifestItem.href();

            // 读取 XHTML
            String xhtml = archive.readSmallText(xhtmlPath);
            if (xhtml == null) continue;

            // 提取主图片路径
            String imagePath = extractMainImagePath(xhtml, xhtmlPath);
            if (imagePath == null) continue;

            // 读取图片头部获取宽高（不读取完整图片）
            int width = 0;
            int height = 0;
            byte[] header = archive.readImageHeader(imagePath, 65536);
            if (header != null && header.length > 24) {
                int[] dims = readImageDimensions(header);
                width = dims[0];
                height = dims[1];
            }

            String mime = detectMimeType(imagePath);
            long entrySize = archive.getEntrySize(imagePath);
            long entryCrc = archive.getEntryCrc(imagePath);

            // fingerprint 基于 entry 路径 + 大小 + CRC
            String fingerprint = computeEpubFingerprint(imagePath, entrySize, entryCrc);

            pages.add(new ComicPageDraft(
                    sourceId,
                    imagePath,      // sourcePath = 图片 entry 路径
                    pageIndex,
                    width,
                    height,
                    mime,
                    fingerprint,
                    entrySize > 0 ? entrySize : 0,
                    null,           // entryIndex (EPUB 无此概念)
                    spineCatalogKeys.get(xhtmlPath)
            ));
            pageIndex++;
        }

        return pages;
    }

    /**
     * 读取 EPUB 封面图片。
     *
     * @param archive EPUB 文件随机访问抽象
     * @param parseResult EPUB 元数据解析结果
     * @return 封面草稿，未找到有效封面时返回 null
     */
    public ReaderCoverDraft extractCover(EpubArchive archive, EpubParseResult parseResult) {
        if (parseResult == null || parseResult.cover() == null) {
            return null;
        }
        EpubCover cover = parseResult.cover();
        long entrySize = archive.getEntrySize(cover.path());
        if (entrySize <= 0 || entrySize > MAX_COVER_BYTES) {
            return null;
        }
        try (InputStream input = archive.openEntryStream(cover.path())) {
            if (input == null) {
                return null;
            }
            ByteArrayOutputStream output = new ByteArrayOutputStream((int) entrySize);
            byte[] buffer = new byte[8192];
            long totalRead = 0;
            int read;
            while ((read = input.read(buffer)) != -1) {
                totalRead += read;
                if (totalRead > MAX_COVER_BYTES) {
                    return null;
                }
                output.write(buffer, 0, read);
            }
            return new ReaderCoverDraft(output.toByteArray(), cover.mimeType(), cover.path());
        } catch (IOException exception) {
            log.warn("EPUB 封面读取失败: errorType={}", exception.getClass().getSimpleName());
            return null;
        }
    }

    /**
     * 将 EPUB nav/toc 转为目录草稿。
     *
     * @param parseResult EPUB 元数据解析结果
     * @param sourceId 来源 ID
     * @return 目录草稿列表
     */
    public List<ComicCatalogDraftNode> extractCatalogDrafts(EpubParseResult parseResult, UUID sourceId) {
        List<ComicCatalogDraftNode> nodes = new ArrayList<>();
        String sourceKey = buildSourceKey(sourceId);
        String sourceTitle = parseResult.title() == null || parseResult.title().isBlank()
                ? "漫画来源"
                : parseResult.title();
        nodes.add(new ComicCatalogDraftNode(
                sourceKey,
                null,
                sourceTitle,
                "COLLECTION",
                0,
                sourceId));
        appendCatalogDrafts(parseResult.toc(), sourceKey, nodes, sourceId);
        return nodes;
    }

    /**
     * 计算 EPUB 页面指纹（基于 entry 路径 + 大小 + CRC）。
     */
    private String computeEpubFingerprint(String path, long size, long crc) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            md.update(path.getBytes());
            md.update(String.valueOf(size).getBytes());
            md.update(String.valueOf(crc).getBytes());
            byte[] hash = md.digest();
            StringBuilder hex = new StringBuilder(16);
            for (int i = 0; i < 8; i++) {
                hex.append(String.format("%02x", hash[i]));
            }
            return hex.toString();
        } catch (Exception e) {
            return "";
        }
    }

    private Map<String, String> buildSpineCatalogKeys(EpubParseResult parseResult, UUID sourceId) {
        Map<String, String> byHref = new LinkedHashMap<>();
        appendTocHrefKeys(parseResult.toc(), buildSourceKey(sourceId), byHref);

        Map<String, String> spineKeys = new LinkedHashMap<>();
        String currentKey = null;
        for (EpubSpineItem spineItem : parseResult.spine()) {
            EpubManifestItem manifestItem = parseResult.manifest().get(spineItem.idref());
            if (manifestItem == null) {
                continue;
            }
            String spineHref = stripFragment(manifestItem.href());
            String tocKey = byHref.get(spineHref);
            if (tocKey != null) {
                currentKey = tocKey;
            }
            spineKeys.put(spineHref, currentKey);
        }
        return spineKeys;
    }

    private void appendTocHrefKeys(List<EpubTocEntry> entries, String parentKey, Map<String, String> byHref) {
        int index = 0;
        for (EpubTocEntry entry : entries) {
            String key = buildTocKey(parentKey, entry.title(), index);
            if (entry.href() != null && !entry.href().isBlank()) {
                byHref.put(stripFragment(entry.href()), key);
            }
            appendTocHrefKeys(entry.children(), key, byHref);
            index++;
        }
    }

    private void appendCatalogDrafts(
            List<EpubTocEntry> entries,
            String parentKey,
            List<ComicCatalogDraftNode> nodes,
            UUID sourceId) {
        int index = 0;
        for (EpubTocEntry entry : entries) {
            String key = buildTocKey(parentKey, entry.title(), index);
            nodes.add(new ComicCatalogDraftNode(
                    key,
                    parentKey,
                    entry.title(),
                    detectCatalogNodeType(entry.title()),
                    index,
                    sourceId));
            appendCatalogDrafts(entry.children(), key, nodes, sourceId);
            index++;
        }
    }

    private String buildTocKey(String parentKey, String title, int index) {
        String titlePart = title == null || title.isBlank() ? "目录" + (index + 1) : title.trim();
        String segment = "toc:" + sanitizeCatalogSegment(titlePart) + ":" + index;
        return parentKey == null || parentKey.isBlank() ? segment : parentKey + "/" + segment;
    }

    private String sanitizeCatalogSegment(String value) {
        return value
                .replace('\\', '/')
                .replaceAll("[/\\s]+", "_")
                .replaceAll("[^\\p{IsHan}\\p{Alnum}_\\-]", "");
    }

    private String detectCatalogNodeType(String title) {
        if (title == null) {
            return "CHAPTER";
        }
        String lower = title.toLowerCase(Locale.ROOT);
        if (lower.matches(".*(season|第.+季|s\\d+).*")) {
            return "SEASON";
        }
        if (lower.matches(".*(volume|vol\\.?|第.+卷).*")) {
            return "VOLUME";
        }
        if (lower.contains("extra") || lower.contains("special") || lower.contains("番外")) {
            return "EXTRA";
        }
        return "CHAPTER";
    }

    // ── Private helpers ─────────────────────────────────────────

    private String parseContainerXml(String xml) {
        Document doc = parseXml(xml);
        NodeList rootfiles = doc.getElementsByTagName("rootfile");
        if (rootfiles.getLength() > 0) {
            return ((Element) rootfiles.item(0)).getAttribute("full-path");
        }
        return null;
    }

    private String extractMetadataText(Document opfDoc, String name) {
        NodeList nodes = opfDoc.getElementsByTagNameNS("*", name);
        if (nodes.getLength() > 0) {
            return nodes.item(0).getTextContent().trim();
        }
        return "";
    }

    private Map<String, EpubManifestItem> parseManifest(Document opfDoc, String opfDir) {
        Map<String, EpubManifestItem> map = new LinkedHashMap<>();
        NodeList items = opfDoc.getElementsByTagNameNS("*", "item");
        for (int i = 0; i < items.getLength(); i++) {
            Element el = (Element) items.item(i);
            String id = el.getAttribute("id");
            String href = el.getAttribute("href");
            String mediaType = el.getAttribute("media-type");
            String properties = el.getAttribute("properties");
            String resolvedHref = resolvePath(href, opfDir);
            map.put(id, new EpubManifestItem(id, resolvedHref, mediaType, properties));
        }
        return map;
    }

    private String buildSourceKey(UUID sourceId) {
        return "source:" + sourceId;
    }

    private EpubCover findCover(
            EpubArchive archive,
            Document opfDoc,
            String opfDir,
            Map<String, EpubManifestItem> manifest,
            List<EpubSpineItem> spine
    ) {
        NodeList metadataEntries = opfDoc.getElementsByTagNameNS("*", "meta");
        for (int i = 0; i < metadataEntries.getLength(); i++) {
            Element metadata = (Element) metadataEntries.item(i);
            if ("cover".equalsIgnoreCase(metadata.getAttribute("name"))) {
                EpubCover cover = coverFromManifestItem(archive, manifest.get(metadata.getAttribute("content")), manifest);
                if (cover != null) {
                    return cover;
                }
            }
        }

        for (EpubManifestItem item : manifest.values()) {
            if (hasProperty(item.properties(), "cover-image")) {
                EpubCover cover = coverFromManifestItem(archive, item, manifest);
                if (cover != null) {
                    return cover;
                }
            }
        }

        NodeList references = opfDoc.getElementsByTagNameNS("*", "reference");
        for (int i = 0; i < references.getLength(); i++) {
            Element reference = (Element) references.item(i);
            if (reference.getAttribute("type").toLowerCase(Locale.ROOT).contains("cover")) {
                String path = resolvePath(reference.getAttribute("href"), opfDir);
                EpubCover cover = resolveCoverPath(archive, path, null, manifest);
                if (cover != null) {
                    return cover;
                }
            }
        }

        for (EpubSpineItem spineItem : spine) {
            if (!spineItem.linear()) {
                continue;
            }
            EpubManifestItem item = manifest.get(spineItem.idref());
            if (item == null) {
                continue;
            }
            EpubCover cover = coverFromManifestItem(archive, item, manifest);
            if (cover != null) {
                return cover;
            }
        }
        return null;
    }

    private boolean hasProperty(String properties, String expectedProperty) {
        if (properties == null || properties.isBlank()) {
            return false;
        }
        for (String property : properties.trim().split("\\s+")) {
            if (expectedProperty.equals(property)) {
                return true;
            }
        }
        return false;
    }

    private EpubCover coverFromManifestItem(
            EpubArchive archive,
            EpubManifestItem item,
            Map<String, EpubManifestItem> manifest
    ) {
        if (item == null) {
            return null;
        }
        return resolveCoverPath(archive, item.href(), item.mediaType(), manifest);
    }

    private EpubCover resolveCoverPath(
            EpubArchive archive,
            String path,
            String mimeType,
            Map<String, EpubManifestItem> manifest
    ) {
        if (path == null || path.isBlank()) {
            return null;
        }
        String normalizedPath = stripFragment(path);
        String normalizedMimeType = mimeType == null ? "" : mimeType.toLowerCase(Locale.ROOT);
        if (normalizedMimeType.startsWith("image/") || archive.getEntrySize(normalizedPath) > 0
                && isImagePath(normalizedPath)) {
            String resolvedMimeType = normalizedMimeType.startsWith("image/")
                    ? normalizedMimeType
                    : detectMimeType(normalizedPath);
            return new EpubCover(normalizedPath, resolvedMimeType);
        }

        String document = archive.readSmallText(normalizedPath);
        if (document == null) {
            return null;
        }
        String imagePath = extractMainImagePath(document, normalizedPath);
        if (imagePath == null || archive.getEntrySize(imagePath) <= 0) {
            return null;
        }
        String resolvedMimeType = manifest.values().stream()
                .filter(candidate -> imagePath.equals(stripFragment(candidate.href())))
                .map(EpubManifestItem::mediaType)
                .filter(candidate -> candidate != null && candidate.startsWith("image/"))
                .findFirst()
                .orElseGet(() -> detectMimeType(imagePath));
        return new EpubCover(imagePath, resolvedMimeType);
    }

    private boolean isImagePath(String path) {
        String lower = path.toLowerCase(Locale.ROOT);
        return lower.endsWith(".jpg")
                || lower.endsWith(".jpeg")
                || lower.endsWith(".png")
                || lower.endsWith(".gif")
                || lower.endsWith(".webp")
                || lower.endsWith(".bmp")
                || lower.endsWith(".avif");
    }

    private List<EpubSpineItem> parseSpine(Document opfDoc) {
        List<EpubSpineItem> list = new ArrayList<>();
        NodeList spines = opfDoc.getElementsByTagNameNS("*", "spine");
        if (spines.getLength() == 0) {
            return list;
        }

        Element spine = (Element) spines.item(0);
        NodeList itemrefs = spine.getElementsByTagNameNS("*", "itemref");
        for (int i = 0; i < itemrefs.getLength(); i++) {
            Element el = (Element) itemrefs.item(i);
            String idref = el.getAttribute("idref");
            String linear = el.getAttribute("linear");
            boolean isLinear = !"no".equals(linear);
            list.add(new EpubSpineItem(idref, isLinear));
        }
        return list;
    }

    /**
     * 解析 nav.xhtml 中的目录。
     */
    private List<EpubTocEntry> parseNavToc(String navXml, String opfDir) {
        List<EpubTocEntry> entries = new ArrayList<>();
        try {
            Document doc = parseXml(navXml);
            NodeList navs = doc.getElementsByTagNameNS("*", "nav");
            Element tocNav = null;
            for (int i = 0; i < navs.getLength(); i++) {
                Element el = (Element) navs.item(i);
                String type = el.getAttributeNS("http://www.idpf.org/2007/ops", "type");
                if ("toc".equals(type)) {
                    tocNav = el;
                    break;
                }
            }
            if (tocNav == null) {
                return entries;
            }

            NodeList ols = tocNav.getElementsByTagNameNS("*", "ol");
            if (ols.getLength() > 0) {
                parseNavList((Element) ols.item(0), entries, 0, opfDir);
            }
        } catch (Exception e) {
            log.warn("nav.xhtml 解析失败: {}", e.getMessage());
        }
        return entries;
    }

    private void parseNavList(Element ol, List<EpubTocEntry> entries, int level, String opfDir) {
        NodeList childNodes = ol.getChildNodes();
        for (int i = 0; i < childNodes.getLength(); i++) {
            Node child = childNodes.item(i);
            if (!(child instanceof Element li) || !"li".equalsIgnoreCase(li.getLocalName())) {
                continue;
            }

            Element anchor = findDirectChild(li, "a");
            Element span = findDirectChild(li, "span");
            String title = anchor != null ? anchor.getTextContent().trim()
                    : span != null ? span.getTextContent().trim() : "";
            String href = anchor != null ? anchor.getAttribute("href") : "";
            String resolvedHref = href.isBlank() ? "" : resolvePath(href, opfDir);

            List<EpubTocEntry> children = new ArrayList<>();
            Element nestedOl = findDirectChild(li, "ol");
            if (nestedOl != null) {
                parseNavList(nestedOl, children, level + 1, opfDir);
            }

            entries.add(new EpubTocEntry(title, resolvedHref, level, children));
        }
    }

    private Element findDirectChild(Element parent, String tagName) {
        NodeList childNodes = parent.getChildNodes();
        for (int i = 0; i < childNodes.getLength(); i++) {
            Node child = childNodes.item(i);
            if (child instanceof Element element && hasName(element, tagName)) {
                return element;
            }
        }
        return null;
    }

    private boolean hasName(Element element, String tagName) {
        String localName = element.getLocalName();
        String nodeName = element.getNodeName();
        return tagName.equalsIgnoreCase(localName) || tagName.equalsIgnoreCase(nodeName);
    }

    /**
     * 解析 toc.ncx (EPUB2)。
     */
    private List<EpubTocEntry> parseNcxToc(String ncxXml, String opfDir) {
        List<EpubTocEntry> entries = new ArrayList<>();
        try {
            Document doc = parseXml(ncxXml);
            NodeList navMaps = doc.getElementsByTagNameNS("*", "navMap");
            if (navMaps.getLength() > 0) {
                parseNcxNavPoints((Element) navMaps.item(0), entries, 0, opfDir);
            }
        } catch (Exception e) {
            log.warn("toc.ncx 解析失败: {}", e.getMessage());
        }
        return entries;
    }

    private void parseNcxNavPoints(Element parent, List<EpubTocEntry> entries, int level, String opfDir) {
        NodeList points = parent.getElementsByTagNameNS("*", "navPoint");
        for (int i = 0; i < points.getLength(); i++) {
            Element point = (Element) points.item(i);
            if (point.getParentNode() != parent) {
                continue;
            }

            NodeList labels = point.getElementsByTagNameNS("*", "text");
            String title = labels.getLength() > 0 ? labels.item(0).getTextContent().trim() : "";

            NodeList contents = point.getElementsByTagNameNS("*", "content");
            String href = contents.getLength() > 0
                    ? ((Element) contents.item(0)).getAttribute("src") : "";

            String resolvedHref = resolvePath(href, opfDir);

            List<EpubTocEntry> children = new ArrayList<>();
            parseNcxNavPoints(point, children, level + 1, opfDir);

            entries.add(new EpubTocEntry(title, resolvedHref, level, children));
        }
    }

    /**
     * 从 XHTML 中提取主图片路径。
     * 支持：<img src="">、SVG <image href="">、<picture><source>
     */
    private String extractMainImagePath(String xhtml, String xhtmlPath) {
        // 1. <img src="...">
        int imgIdx = xhtml.indexOf("<img");
        if (imgIdx >= 0) {
            String after = xhtml.substring(imgIdx);
            String src = extractAttribute(after, "src");
            if (src != null && !src.isEmpty()) {
                return resolveRelativePath(src, xhtmlPath);
            }
        }

        // 2. SVG <image href="..."> 或 <image xlink:href="...">
        int imageIdx = xhtml.indexOf("<image");
        if (imageIdx >= 0) {
            String after = xhtml.substring(imageIdx);
            String href = extractAttribute(after, "href");
            if (href == null || href.isEmpty()) {
                href = extractAttribute(after, "xlink:href");
            }
            if (href != null && !href.isEmpty()) {
                return resolveRelativePath(href, xhtmlPath);
            }
        }

        return null;
    }

    private String extractAttribute(String tag, String attrName) {
        String search = attrName + "=\"";
        int idx = tag.indexOf(search);
        if (idx >= 0) {
            int start = idx + search.length();
            int end = tag.indexOf('"', start);
            if (end > start) {
                return tag.substring(start, end);
            }
        }
        search = attrName + "='";
        idx = tag.indexOf(search);
        if (idx >= 0) {
            int start = idx + search.length();
            int end = tag.indexOf('\'', start);
            if (end > start) {
                return tag.substring(start, end);
            }
        }
        return null;
    }

    /**
     * 解析相对路径（基于 XHTML 文件路径）。
     */
    private String resolveRelativePath(String relativeTo, String basePath) {
        if (relativeTo.startsWith("http://") || relativeTo.startsWith("https://")) {
            return relativeTo;
        }
        String decoded = urlDecode(relativeTo);
        String baseDir = basePath.contains("/") ? basePath.substring(0, basePath.lastIndexOf('/') + 1) : "";
        return normalizePath(baseDir + decoded);
    }

    /**
     * 解析 manifest href（基于 OPF 目录）。
     */
    private String resolvePath(String href, String opfDir) {
        if (href.startsWith("http://") || href.startsWith("https://")) {
            return href;
        }
        String decoded = urlDecode(href);
        if (decoded.startsWith("/")) {
            return decoded.substring(1);
        }
        return normalizePath(opfDir + decoded);
    }

    /**
     * 规范化路径：处理 ../、./、重复斜杠。
     */
    private String normalizePath(String path) {
        if (path == null) {
            return "";
        }
        String decodedPath = urlDecode(path).replace('\\', '/');
        Deque<String> segments = new ArrayDeque<>();
        for (String segment : decodedPath.split("/+")) {
            if (segment.isEmpty() || ".".equals(segment)) {
                continue;
            }
            if ("..".equals(segment)) {
                if (!segments.isEmpty()) {
                    segments.removeLast();
                }
                continue;
            }
            segments.addLast(segment);
        }
        return String.join("/", segments);
    }

    private String urlDecode(String s) {
        if (s == null) {
            return "";
        }
        try {
            return URLDecoder.decode(s, StandardCharsets.UTF_8.name());
        } catch (Exception e) {
            return s;
        }
    }

    private String stripFragment(String href) {
        if (href == null) {
            return "";
        }
        int hashIndex = href.indexOf('#');
        return hashIndex >= 0 ? href.substring(0, hashIndex) : href;
    }

    private String getParentDir(String path) {
        if (path == null) {
            return "";
        }
        int slashIndex = path.lastIndexOf('/');
        return slashIndex >= 0 ? path.substring(0, slashIndex + 1) : "";
    }

    private Document parseXml(String xml) {
        return ReaderXmlSafety.parse(xml);
    }

    private int[] readImageDimensions(byte[] data) {
        if (data == null || data.length < 24) {
            return new int[]{0, 0};
        }

        // PNG
        if (data[0] == (byte) 0x89 && data[1] == (byte) 0x50 && data.length >= 24) {
            int w = ((data[16] & 0xFF) << 24) | ((data[17] & 0xFF) << 16)
                    | ((data[18] & 0xFF) << 8) | (data[19] & 0xFF);
            int h = ((data[20] & 0xFF) << 24) | ((data[21] & 0xFF) << 16)
                    | ((data[22] & 0xFF) << 8) | (data[23] & 0xFF);
            return new int[]{w, h};
        }

        // GIF
        if (data[0] == 'G' && data[1] == 'I' && data[2] == 'F' && data.length >= 10) {
            int w = (data[6] & 0xFF) | ((data[7] & 0xFF) << 8);
            int h = (data[8] & 0xFF) | ((data[9] & 0xFF) << 8);
            return new int[]{w, h};
        }

        // JPEG: scan for SOF
        if (data[0] == (byte) 0xFF && data[1] == (byte) 0xD8) {
            int limit = Math.min(data.length, 65536);
            int i = 2;
            while (i < limit - 9) {
                if (data[i] != (byte) 0xFF) {
                    i++;
                    continue;
                }
                int marker = data[i + 1] & 0xFF;
                if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
                    int h = ((data[i + 5] & 0xFF) << 8) | (data[i + 6] & 0xFF);
                    int w = ((data[i + 7] & 0xFF) << 8) | (data[i + 8] & 0xFF);
                    return new int[]{w, h};
                }
                if (marker >= 0xD0 && marker <= 0xD9) {
                    i += 2;
                    continue;
                }
                if (i + 3 >= limit) {
                    break;
                }
                int len = ((data[i + 2] & 0xFF) << 8) | (data[i + 3] & 0xFF);
                i += 2 + len;
            }
        }

        // WebP
        if (data.length >= 30 && data[0] == 'R' && data[8] == 'W'
                && data[12] == 'V' && data[13] == 'P') {
            if (data[15] == ' ') {
                int w = ((data[26] & 0xFF) | ((data[27] & 0xFF) << 8)) & 0x3FFF;
                int h = ((data[28] & 0xFF) | ((data[29] & 0xFF) << 8)) & 0x3FFF;
                return new int[]{w, h};
            }
        }

        return new int[]{0, 0};
    }

    /**
     * 从 OPF manifest 中查找 nav 文档路径（properties 含 "nav"）。
     */
    private String findNavPath(Map<String, EpubManifestItem> manifest) {
        for (EpubManifestItem item : manifest.values()) {
            if (item.properties() != null && item.properties().contains("nav")) {
                return item.href();
            }
        }
        return null;
    }

    /**
     * 从 OPF manifest 中查找 NCX 路径（media-type 为 application/x-dtbncx+xml）。
     */
    private String findNcxPath(Map<String, EpubManifestItem> manifest) {
        for (EpubManifestItem item : manifest.values()) {
            if ("application/x-dtbncx+xml".equals(item.mediaType())) {
                return item.href();
            }
        }
        return null;
    }

    private String detectMimeType(String path) {
        if (path == null) {
            return "application/octet-stream";
        }
        String lower = path.toLowerCase(Locale.ROOT);
        if (lower.endsWith(".png")) return "image/png";
        if (lower.endsWith(".gif")) return "image/gif";
        if (lower.endsWith(".webp")) return "image/webp";
        if (lower.endsWith(".svg")) return "image/svg+xml";
        if (lower.endsWith(".bmp")) return "image/bmp";
        if (lower.endsWith(".avif")) return "image/avif";
        return "image/jpeg";
    }
}
