package com.omninest.modules.reader.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.omninest.modules.reader.config.ReaderArchiveLimitsProperties;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.junit.jupiter.api.io.TempDir;

/**
 * 固定布局 EPUB 漫画解析器测试。
 *
 * @author OmniNest
 */
class ComicEpubParserTest {

    private static final UUID SOURCE_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");
    private static final UUID SECOND_SOURCE_ID = UUID.fromString("10000000-0000-0000-0000-000000000002");

    @TempDir
    private Path tempDirectory;

    @Test
    void parsesFixedLayoutEpubWithRelativeImagePaths() throws IOException {
        Path epubPath = tempDirectory.resolve("fixed-layout.epub");
        createFixedLayoutEpub(epubPath);
        ReaderArchiveSafetyPolicy safetyPolicy = new ReaderArchiveSafetyPolicy(
                new ReaderArchiveLimitsProperties()
        );
        ComicEpubParser parser = new ComicEpubParser();

        try (EpubArchive archive = new EpubArchive(epubPath, safetyPolicy)) {
            ComicEpubParser.EpubParseResult metadata = parser.parseMetadata(archive);

            assertThat(metadata).isNotNull();
            assertThat(metadata.title()).isEqualTo("测试漫画");
            assertThat(metadata.author()).isEqualTo("OmniNest");
            assertThat(metadata.readingDirection()).isEqualTo("rtl");
            assertThat(metadata.cover()).isNotNull();
            assertThat(metadata.cover().path()).isEqualTo("image/page001.png");
            assertThat(parser.extractCover(archive, metadata)).satisfies(cover -> {
                assertThat(cover.mimeType()).isEqualTo("image/png");
                assertThat(cover.content()).isNotEmpty();
            });

            var pages = parser.extractPageDrafts(archive, metadata, SOURCE_ID);
            assertThat(pages).hasSize(2);
            assertThat(pages).extracting("sourcePath")
                    .containsExactly("image/page001.png", "image/page002.png");
            assertThat(pages).extracting("width").containsOnly(1200);
            assertThat(pages).extracting("height").containsOnly(1800);

            var firstCatalog = parser.extractCatalogDrafts(metadata, SOURCE_ID);
            var secondCatalog = parser.extractCatalogDrafts(metadata, SECOND_SOURCE_ID);
            assertThat(firstCatalog.getFirst().catalogKey()).isEqualTo("source:" + SOURCE_ID);
            assertThat(secondCatalog.getFirst().catalogKey()).isEqualTo("source:" + SECOND_SOURCE_ID);
            assertThat(firstCatalog.getFirst().catalogKey())
                    .isNotEqualTo(secondCatalog.getFirst().catalogKey());
        }
    }

    @Test
    @EnabledIfSystemProperty(named = "comic.fixture", matches = ".+")
    void parsesConfiguredComicFixture() throws IOException {
        Path fixturePath = Path.of(System.getProperty("comic.fixture"));
        ReaderArchiveSafetyPolicy safetyPolicy = new ReaderArchiveSafetyPolicy(
                new ReaderArchiveLimitsProperties()
        );
        ComicEpubParser parser = new ComicEpubParser();

        try (EpubArchive archive = new EpubArchive(fixturePath, safetyPolicy)) {
            ComicEpubParser.EpubParseResult metadata = parser.parseMetadata(archive);
            assertThat(metadata).isNotNull();

            var pages = parser.extractPageDrafts(archive, metadata, SOURCE_ID);
            assertThat(pages).isNotEmpty();
            assertThat(pages).allSatisfy(page ->
                    assertThat(archive.getEntrySize(page.sourcePath())).isPositive());
        }
    }

    private void createFixedLayoutEpub(Path epubPath) throws IOException {
        try (OutputStream output = Files.newOutputStream(epubPath);
             ZipOutputStream zip = new ZipOutputStream(output)) {
            writeEntry(zip, "mimetype", "application/epub+zip".getBytes(StandardCharsets.UTF_8));
            writeEntry(zip, "META-INF/container.xml", containerXml().getBytes(StandardCharsets.UTF_8));
            writeEntry(zip, "vol.opf", opfXml().getBytes(StandardCharsets.UTF_8));
            writeEntry(zip, "text/page001.xhtml", pageXhtml("page001.png").getBytes(StandardCharsets.UTF_8));
            writeEntry(zip, "text/page002.xhtml", pageXhtml("page002.png").getBytes(StandardCharsets.UTF_8));
            writeEntry(zip, "image/page001.png", pngHeader(1200, 1800));
            writeEntry(zip, "image/page002.png", pngHeader(1200, 1800));
        }
    }

    private void writeEntry(ZipOutputStream zip, String name, byte[] bytes) throws IOException {
        zip.putNextEntry(new ZipEntry(name));
        zip.write(bytes);
        zip.closeEntry();
    }

    private String containerXml() {
        return """
                <?xml version="1.0" encoding="UTF-8"?>
                <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
                  <rootfiles>
                    <rootfile full-path="vol.opf" media-type="application/oebps-package+xml"/>
                  </rootfiles>
                </container>
                """;
    }

    private String opfXml() {
        return """
                <?xml version="1.0" encoding="UTF-8"?>
                <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
                  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                    <dc:title>测试漫画</dc:title>
                    <dc:creator>OmniNest</dc:creator>
                    <meta property="rendition:layout">pre-paginated</meta>
                  </metadata>
                  <manifest>
                    <item id="p1" href="text/page001.xhtml" media-type="application/xhtml+xml"/>
                    <item id="p2" href="text/page002.xhtml" media-type="application/xhtml+xml"/>
                    <item id="i1" href="image/page001.png" media-type="image/png" properties="cover-image"/>
                    <item id="i2" href="image/page002.png" media-type="image/png"/>
                  </manifest>
                  <spine page-progression-direction="rtl">
                    <itemref idref="p1"/>
                    <itemref idref="p2"/>
                  </spine>
                </package>
                """;
    }

    private String pageXhtml(String imageName) {
        return """
                <?xml version="1.0" encoding="UTF-8"?>
                <html xmlns="http://www.w3.org/1999/xhtml">
                  <body><img src="../image/%s" alt=""/></body>
                </html>
                """.formatted(imageName);
    }

    private byte[] pngHeader(int width, int height) {
        byte[] header = new byte[32];
        header[0] = (byte) 0x89;
        header[1] = 0x50;
        header[2] = 0x4E;
        header[3] = 0x47;
        header[4] = 0x0D;
        header[5] = 0x0A;
        header[6] = 0x1A;
        header[7] = 0x0A;
        writeInt(header, 16, width);
        writeInt(header, 20, height);
        return header;
    }

    private void writeInt(byte[] target, int offset, int value) {
        target[offset] = (byte) (value >>> 24);
        target[offset + 1] = (byte) (value >>> 16);
        target[offset + 2] = (byte) (value >>> 8);
        target[offset + 3] = (byte) value;
    }
}
