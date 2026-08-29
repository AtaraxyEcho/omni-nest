package com.omninest.modules.reader.service;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import lombok.extern.slf4j.Slf4j;
import org.w3c.dom.Document;
import org.xml.sax.ErrorHandler;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;
import org.xml.sax.SAXParseException;

/**
 * Reader 模块 XML 安全解析入口，统一限制外部资源和实体展开。
 *
 * @author OmniNest
 */
@Slf4j
final class ReaderXmlSafety {

    private static final int MAX_XML_CHARACTERS = 5 * 1024 * 1024;
    private static final String ENTITY_EXPANSION_LIMIT =
            "http://www.oracle.com/xml/jaxp/properties/entityExpansionLimit";
    private static final String TOTAL_ENTITY_SIZE_LIMIT =
            "http://www.oracle.com/xml/jaxp/properties/totalEntitySizeLimit";
    private static final String MAX_GENERAL_ENTITY_SIZE_LIMIT =
            "http://www.oracle.com/xml/jaxp/properties/maxGeneralEntitySizeLimit";

    private ReaderXmlSafety() {
    }

    /**
     * 在禁止外部资源和内部实体声明的条件下解析 XML。
     *
     * @param xml XML 内容
     * @return DOM 文档
     */
    static Document parse(String xml) {
        validateInput(xml);
        try {
            DocumentBuilderFactory factory = createFactory();
            DocumentBuilder builder = factory.newDocumentBuilder();
            builder.setEntityResolver((publicId, systemId) -> new InputSource(new ByteArrayInputStream(new byte[0])));
            builder.setErrorHandler(new StrictErrorHandler());
            return builder.parse(new InputSource(
                    new ByteArrayInputStream(xml.getBytes(StandardCharsets.UTF_8))
            ));
        } catch (Exception exception) {
            throw new IllegalArgumentException("XML 解析失败: " + exception.getMessage(), exception);
        }
    }

    private static DocumentBuilderFactory createFactory() throws Exception {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setNamespaceAware(true);
        factory.setXIncludeAware(false);
        factory.setExpandEntityReferences(false);
        factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
        // EPUB 章节常带外部 DOCTYPE 声明，只允许声明存在，不读取其外部资源。
        factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", false);
        factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
        factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
        factory.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false);
        setAttributeIfSupported(factory, XMLConstants.ACCESS_EXTERNAL_DTD, "");
        setAttributeIfSupported(factory, XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");
        setAttributeIfSupported(factory, ENTITY_EXPANSION_LIMIT, "64");
        setAttributeIfSupported(factory, TOTAL_ENTITY_SIZE_LIMIT, "65536");
        setAttributeIfSupported(factory, MAX_GENERAL_ENTITY_SIZE_LIMIT, "16384");
        return factory;
    }

    private static void validateInput(String xml) {
        if (xml == null || xml.isBlank()) {
            throw new IllegalArgumentException("XML 内容为空");
        }
        if (xml.length() > MAX_XML_CHARACTERS) {
            throw new IllegalArgumentException("XML 内容超过安全上限");
        }
        if (xml.contains("<!ENTITY") || hasInternalDoctypeSubset(xml)) {
            throw new IllegalArgumentException("XML 不允许包含内部实体声明");
        }
    }

    private static boolean hasInternalDoctypeSubset(String xml) {
        int start = xml.indexOf("<!DOCTYPE");
        if (start < 0) {
            return false;
        }
        boolean quoted = false;
        char quote = 0;
        for (int index = start + 9; index < xml.length(); index++) {
            char current = xml.charAt(index);
            if (quoted) {
                if (current == quote) {
                    quoted = false;
                }
                continue;
            }
            if (current == '\'' || current == '"') {
                quoted = true;
                quote = current;
            } else if (current == '[') {
                return true;
            } else if (current == '>') {
                return false;
            }
        }
        return false;
    }

    private static void setAttributeIfSupported(DocumentBuilderFactory factory, String name, String value) {
        try {
            factory.setAttribute(name, value);
        } catch (IllegalArgumentException exception) {
            log.debug("当前 XML 实现不支持属性 {}，跳过: {}", name, exception.getMessage());
        }
    }

    /**
     * 将 XML 语法错误转换为异常，避免解析器向标准错误流输出内容。
     *
     * @author OmniNest
     */
    private static final class StrictErrorHandler implements ErrorHandler {

        @Override
        public void warning(SAXParseException exception) throws SAXException {
            throw exception;
        }

        @Override
        public void error(SAXParseException exception) throws SAXException {
            throw exception;
        }

        @Override
        public void fatalError(SAXParseException exception) throws SAXException {
            throw exception;
        }
    }
}
