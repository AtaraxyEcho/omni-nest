package com.omninest.modules.reader.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

/**
 * Reader XML 安全解析测试。
 *
 * @author OmniNest
 */
class ReaderXmlSafetyTest {

    @Test
    void acceptsExternalDoctypeWithoutLoadingRemoteResource() {
        String xml = """
                <?xml version="1.0"?>
                <!DOCTYPE html SYSTEM "https://example.invalid/xhtml.dtd">
                <html xmlns="http://www.w3.org/1999/xhtml"><body>正文</body></html>
                """;

        assertThat(ReaderXmlSafety.parse(xml).getDocumentElement().getTextContent()).isEqualTo("正文");
    }

    @Test
    void rejectsInternalEntityDeclarations() {
        String xml = """
                <?xml version="1.0"?>
                <!DOCTYPE root [<!ENTITY payload "expanded">]>
                <root>&payload;</root>
                """;

        assertThatThrownBy(() -> ReaderXmlSafety.parse(xml))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("内部实体");
    }
}
