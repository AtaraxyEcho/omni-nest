package com.omninest.common.download;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.common.security.SafeUrlValidator;
import java.net.URI;
import java.util.Locale;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 基于安全 URL 校验器解析离线下载源。
 *
 * @author OmniNest
 */
@Component
@RequiredArgsConstructor
public class SafeOfflineDownloadSourceResolver implements OfflineDownloadSourceResolver {
    private final SafeUrlValidator safeUrlValidator;

    /**
     * 将用户输入解析为受支持的下载源。
     *
     * @param sourceUri 下载源地址
     * @return 规范化后的下载源
     */
    @Override
    public ResolvedSource resolve(String sourceUri) {
        if (sourceUri == null || sourceUri.isBlank()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "离线下载地址不能为空");
        }
        String normalized = sourceUri.trim();
        if (normalized.regionMatches(true, 0, "magnet:", 0, "magnet:".length())) {
            return new ResolvedSource(SourceKind.MAGNET, URI.create(normalized));
        }
        if (normalized.regionMatches(true, 0, "bt://", 0, "bt://".length())) {
            return resolveNested(normalized.substring("bt://".length()));
        }
        if (normalized.regionMatches(true, 0, "bt:", 0, "bt:".length())) {
            return resolveNested(normalized.substring("bt:".length()));
        }

        URI uri;
        try {
            uri = URI.create(normalized);
        } catch (IllegalArgumentException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "离线下载地址格式不正确");
        }
        String scheme = uri.getScheme() == null ? "" : uri.getScheme().toLowerCase(Locale.ROOT);
        if (!"http".equals(scheme) && !"https".equals(scheme)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "暂只支持 HTTP、HTTPS、BT 和磁力链");
        }
        safeUrlValidator.requireSafeHttpUrl(normalized);
        if (looksLikeTorrent(uri)) {
            return new ResolvedSource(SourceKind.TORRENT_FILE, uri);
        }
        return new ResolvedSource(SourceKind.HTTP, uri);
    }

    private ResolvedSource resolveNested(String rawValue) {
        String nested = rawValue == null ? "" : rawValue.trim();
        if (nested.startsWith("//")) {
            nested = nested.substring(2);
        }
        return resolve(nested);
    }

    private boolean looksLikeTorrent(URI uri) {
        String path = uri.getPath();
        return path != null && path.toLowerCase(Locale.ROOT).endsWith(".torrent");
    }
}
