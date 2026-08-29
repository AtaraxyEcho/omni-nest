package com.omninest.common.download;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.omninest.common.error.BusinessException;
import com.omninest.common.security.SsrfSafeUrlValidator;
import org.junit.jupiter.api.Test;

/**
 * 安全离线下载源解析器测试。
 *
 * @author OmniNest
 */
class SafeOfflineDownloadSourceResolverTest {
    private final OfflineDownloadSourceResolver resolver = new SafeOfflineDownloadSourceResolver(
            new SsrfSafeUrlValidator()
    );

    @Test
    void resolveAcceptsMagnetLinksWithoutDnsLookup() {
        OfflineDownloadSourceResolver.ResolvedSource result =
                resolver.resolve("magnet:?xt=urn:btih:0123456789abcdef");

        assertThat(result.kind()).isEqualTo(OfflineDownloadSourceResolver.SourceKind.MAGNET);
    }

    @Test
    void resolveBlocksLoopbackHttpTargets() {
        assertThatThrownBy(() -> resolver.resolve("http://127.0.0.1:8080/private"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("内网地址");
    }
}
