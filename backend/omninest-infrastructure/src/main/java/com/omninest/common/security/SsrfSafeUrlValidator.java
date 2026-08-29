package com.omninest.common.security;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import java.net.Inet4Address;
import java.net.Inet6Address;
import java.net.InetAddress;
import java.net.URI;
import java.net.UnknownHostException;
import java.util.Locale;
import org.springframework.stereotype.Component;

/**
 * SSRF 防护：验证 URL 是否指向安全的外部地址。
 * 阻止指向本地、内网、元数据服务的请求。
 *
 * @author OmniNest
 */
@Component
public final class SsrfSafeUrlValidator implements SafeUrlValidator {

    /**
     * 验证 URL 的主机名和解析后的 IP 地址是否安全。
     *
     * @param uri 待验证的 URI
     * @throws BusinessException 如果地址指向本地或内网
     */
    @Override
    public void requireSafeHost(URI uri) {
        String host = uri.getHost();
        if (host == null || host.isBlank()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "URL 缺少主机名");
        }
        if (isReservedHostName(host)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "URL 不能指向本地或内网地址");
        }
        try {
            InetAddress[] addresses = InetAddress.getAllByName(host);
            if (addresses.length == 0) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "URL 无法解析");
            }
            for (InetAddress address : addresses) {
                if (isBlockedAddress(address)) {
                    throw new BusinessException(ErrorCode.BAD_REQUEST, "URL 不能指向本地或内网地址");
                }
            }
        } catch (UnknownHostException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "URL 无法解析");
        }
    }

    /**
     * 验证 URL 字符串是否安全（含 scheme 检查）。
     *
     * @param url 待验证的 URL 字符串
     * @throws BusinessException 如果 URL 不安全或格式不正确
     */
    @Override
    public void requireSafeHttpUrl(String url) {
        if (url == null || url.isBlank()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "URL 不能为空");
        }
        URI uri;
        try {
            uri = URI.create(url.trim());
        } catch (IllegalArgumentException exception) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "URL 格式不正确");
        }
        String scheme = uri.getScheme() == null ? "" : uri.getScheme().toLowerCase(Locale.ROOT);
        if (!"http".equals(scheme) && !"https".equals(scheme)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "仅支持 HTTP 和 HTTPS 协议");
        }
        if (uri.getUserInfo() != null && !uri.getUserInfo().isBlank()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "URL 不允许携带用户信息");
        }
        requireSafeHost(uri);
    }

    private static boolean isReservedHostName(String host) {
        String normalized = host.toLowerCase(Locale.ROOT);
        return "localhost".equals(normalized)
                || normalized.endsWith(".localhost")
                || "metadata.google.internal".equals(normalized)
                || "metadata".equals(normalized);
    }

    private static boolean isBlockedAddress(InetAddress address) {
        if (address.isAnyLocalAddress()
                || address.isLoopbackAddress()
                || address.isLinkLocalAddress()
                || address.isSiteLocalAddress()
                || address.isMulticastAddress()) {
            return true;
        }
        if (address instanceof Inet4Address inet4Address) {
            byte[] bytes = inet4Address.getAddress();
            int first = bytes[0] & 0xFF;
            int second = bytes[1] & 0xFF;
            return first == 0
                    || first == 10
                    || first == 127
                    || (first == 100 && second >= 64 && second <= 127)
                    || (first == 169 && second == 254)
                    || (first == 172 && second >= 16 && second <= 31)
                    || (first == 198 && (second == 18 || second == 19))
                    || (first == 192 && second == 168);
        }
        if (address instanceof Inet6Address inet6Address) {
            byte[] bytes = inet6Address.getAddress();
            int first = bytes[0] & 0xFF;
            return (first & 0xFE) == 0xFC;
        }
        return false;
    }
}
