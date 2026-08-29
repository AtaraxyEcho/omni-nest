package com.omninest.common.download;

import java.net.URI;

/**
 * 解析并校验用户提供的离线下载源。
 *
 * @author OmniNest
 */
public interface OfflineDownloadSourceResolver {

    /**
     * 将用户输入解析为受支持的下载源。
     *
     * @param sourceUri 下载源地址
     * @return 规范化后的下载源
     */
    ResolvedSource resolve(String sourceUri);

    /**
     * 离线下载源类型。
     *
     * @author OmniNest
     */
    enum SourceKind {
        HTTP,
        TORRENT_FILE,
        MAGNET
    }

    /**
     * 已解析的离线下载源。
     *
     * @param kind 下载源类型
     * @param uri  规范化地址
     * @author OmniNest
     */
    record ResolvedSource(SourceKind kind, URI uri) {
    }
}
