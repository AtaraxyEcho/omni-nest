package com.omninest.modules.reader.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

import com.omninest.modules.file.domain.SpaceType;
import com.omninest.modules.file.dto.FileContentStream;
import com.omninest.modules.file.dto.FileDescriptor;
import com.omninest.modules.file.service.FileMetadataQueryService;
import com.omninest.modules.file.service.FileQueryService;
import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 文本书籍解析器测试。
 *
 * @author OmniNest
 */
@ExtendWith(MockitoExtension.class)
class ReaderTextParserTest {

    private static final UUID FILE_NODE_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");
    private static final UUID FILE_OBJECT_ID = UUID.fromString("20000000-0000-0000-0000-000000000001");

    @Mock
    private FileMetadataQueryService fileMetadataQueryService;

    @Mock
    private FileQueryService fileQueryService;

    @Mock
    private ReaderEpubArchiveStager epubArchiveStager;

    @Mock
    private ReaderArchiveSafetyPolicy archiveSafetyPolicy;

    private ReaderTextParser parser;

    @BeforeEach
    void setUp() {
        parser = new ReaderTextParser(
                fileMetadataQueryService,
                fileQueryService,
                epubArchiveStager,
                archiveSafetyPolicy
        );
    }

    @Test
    void parsesUtf8TxtIntoStableChapterOffsets() {
        String text = "前言内容\r\n第一章 开始\r\n这是第一章正文\r\n第二章 继续\r\n这是第二章正文";
        byte[] bytes = text.getBytes(StandardCharsets.UTF_8);
        when(fileMetadataQueryService.findById(FILE_NODE_ID)).thenReturn(Optional.of(fileNode()));
        when(fileQueryService.openOwnedFileContent(any(), eq(FILE_NODE_ID)))
                .thenAnswer(invocation -> new FileContentStream(
                        new ByteArrayInputStream(bytes),
                        "book.txt",
                        bytes.length,
                        "text/plain"
                ));

        ReaderTextParser.ParsedTextBook result = parser.parse(FILE_NODE_ID, "TXT", progress -> {
        });

        assertThat(result.language()).isEqualTo("UTF-8");
        assertThat(result.chapters()).hasSize(3);
        assertThat(result.chapters()).extracting(ReaderTextParser.TextChapterDraft::chapterKey)
                .containsExactly("chapter_0", "chapter_1", "chapter_2");
        assertThat(result.chapters()).extracting(ReaderTextParser.TextChapterDraft::title)
                .containsExactly("正文", "第一章 开始", "第二章 继续");
        assertThat(result.chapters()).allSatisfy(chapter ->
                assertThat(chapter.sourceEndOffset()).isGreaterThanOrEqualTo(chapter.sourceStartOffset()));
    }

    private FileDescriptor fileNode() {
        Instant now = Instant.now();
        return new FileDescriptor(
                FILE_NODE_ID,
                UUID.randomUUID(),
                null,
                "FILE",
                "book.txt",
                "/book.txt",
                "text/plain",
                128L,
                FILE_OBJECT_ID,
                "UPLOAD",
                false,
                false,
                SpaceType.PERSONAL,
                UUID.randomUUID(),
                now,
                now
        );
    }

}
