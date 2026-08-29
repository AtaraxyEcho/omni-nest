package com.omninest.modules.music.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.Test;

class MusicMetadataExtractorTest {
    private final MusicMetadataExtractor extractor = new MusicMetadataExtractor();

    @Test
    void extractsId3v23TextLyricsAndCover() throws Exception {
        byte[] cover = new byte[] {1, 2, 3, 4};
        byte[] audio = id3Tag(
                textFrame("TIT2", "Night Drive"),
                textFrame("TPE1", "Omni Band"),
                textFrame("TALB", "City Lights"),
                textFrame("TCON", "Synthwave"),
                unsynchronizedLyricsFrame("eng", "", "[00:01.00]Rolling"),
                attachedPictureFrame("image/png", cover)
        );

        MusicMetadataExtractor.Metadata metadata =
                extractor.extract(new ByteArrayInputStream(audio), "Night Drive.mp3", "audio/mpeg");

        assertThat(metadata.title()).isEqualTo("Night Drive");
        assertThat(metadata.artistName()).isEqualTo("Omni Band");
        assertThat(metadata.albumTitle()).isEqualTo("City Lights");
        assertThat(metadata.genre()).isEqualTo("Synthwave");
        assertThat(metadata.lyricsRaw()).isEqualTo("[00:01.00]Rolling");
        assertThat(metadata.coverDataUrl()).isEqualTo("data:image/png;base64,AQIDBA==");
    }

    @Test
    void handlesRealFlacFileWithoutMetadata() throws Exception {
        // 验证解析器能正确处理无元数据的真实 FLAC 文件（不崩溃，返回空值）
        String fixturePath = System.getenv("OMNINEST_TEST_FLAC_PATH");
        Assumptions.assumeTrue(
                fixturePath != null && !fixturePath.isBlank(),
                "未设置可选真实 FLAC 测试文件路径"
        );
        Path flacPath = Path.of(fixturePath);
        Assumptions.assumeTrue(Files.isRegularFile(flacPath), "可选真实 FLAC 测试文件不存在");

        MusicMetadataExtractor.Metadata metadata;
        try (InputStream stream = Files.newInputStream(flacPath)) {
            metadata = extractor.extract(stream, "偏爱 - 张芸京[破天荒].flac", "audio/flac");
        }
        // 此文件只有 encoder=Lavf58.45.100，无曲目元数据
        assertThat(metadata.title()).isNull();
        assertThat(metadata.artistName()).isNull();
        assertThat(metadata.hasAnyValue()).isFalse();
    }

    @Test
    void extractsFlacVorbisCommentsFromSyntheticFile() throws Exception {
        // 构造最小 FLAC 文件：fLaC + STREAMINFO(last) + VORBIS_COMMENT(last)
        byte[] flac = buildMinimalFlac(
                vorbisCommentBlock(
                        "reference libFLAC 1.3.3 20190804",
                        "TITLE=偏爱", "ARTIST=张芸京", "ALBUM=破天荒",
                        "TRACKNUMBER=5", "DISCNUMBER=1", "GENRE=Pop"
                )
        );

        MusicMetadataExtractor.Metadata metadata =
                extractor.extract(new ByteArrayInputStream(flac), "test.flac", "audio/flac");

        assertThat(metadata.title()).isEqualTo("偏爱");
        assertThat(metadata.artistName()).isEqualTo("张芸京");
        assertThat(metadata.albumTitle()).isEqualTo("破天荒");
        assertThat(metadata.trackNumber()).isEqualTo("5");
        assertThat(metadata.discNumber()).isEqualTo("1");
        assertThat(metadata.genre()).isEqualTo("Pop");
    }

    /**
     * 构造最小合法 FLAC 字节流：fLaC magic + metadata blocks。
     * 每个 block 以 4 bytes header（isLast | type | length）+ data 形式传入。
     */
    private byte[] buildMinimalFlac(byte[]... blocks) throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.write("fLaC".getBytes(StandardCharsets.ISO_8859_1));
        // STREAMINFO block (type=0, 34 bytes, 最后一个 = false 除非只有它)
        byte[] streamInfo = new byte[34]; // 全零 STREAMINFO
        // 如果有其他 blocks，STREAMINFO 不是 last
        boolean streamInfoIsLast = blocks.length == 0;
        int header = (streamInfoIsLast ? 0x80000000 : 0) | (0 << 24) | streamInfo.length;
        out.write(int32BE(header));
        out.write(streamInfo);
        // 写入额外的 blocks
        for (int i = 0; i < blocks.length; i++) {
            out.write(blocks[i]);
        }
        return out.toByteArray();
    }

    /**
     * 构造 VORBIS_COMMENT FLAC metadata block (type=4)。
     * vendor 先写入，然后是 comment 数量和每个 comment。
     */
    private byte[] vorbisCommentBlock(String vendor, String... comments) throws Exception {
        ByteArrayOutputStream data = new ByteArrayOutputStream();
        byte[] vendorBytes = vendor.getBytes(StandardCharsets.UTF_8);
        data.write(int32LE(vendorBytes.length));
        data.write(vendorBytes);
        data.write(int32LE(comments.length));
        for (String comment : comments) {
            byte[] commentBytes = comment.getBytes(StandardCharsets.UTF_8);
            data.write(int32LE(commentBytes.length));
            data.write(commentBytes);
        }
        byte[] dataBytes = data.toByteArray();
        ByteArrayOutputStream block = new ByteArrayOutputStream();
        // isLast = true (0x80), type = 4
        int header = 0x80000000 | (4 << 24) | dataBytes.length;
        block.write(int32BE(header));
        block.write(dataBytes);
        return block.toByteArray();
    }

    private byte[] int32BE(int value) {
        return new byte[] {
                (byte) ((value >>> 24) & 0xFF),
                (byte) ((value >>> 16) & 0xFF),
                (byte) ((value >>> 8) & 0xFF),
                (byte) (value & 0xFF)
        };
    }

    private byte[] int32LE(int value) {
        return new byte[] {
                (byte) (value & 0xFF),
                (byte) ((value >>> 8) & 0xFF),
                (byte) ((value >>> 16) & 0xFF),
                (byte) ((value >>> 24) & 0xFF)
        };
    }

    private byte[] id3Tag(byte[]... frames) throws Exception {
        ByteArrayOutputStream body = new ByteArrayOutputStream();
        for (byte[] frame : frames) {
            body.write(frame);
        }
        byte[] bodyBytes = body.toByteArray();
        ByteArrayOutputStream tag = new ByteArrayOutputStream();
        tag.write("ID3".getBytes(StandardCharsets.ISO_8859_1));
        tag.write(new byte[] {3, 0, 0});
        tag.write(synchsafe(bodyBytes.length));
        tag.write(bodyBytes);
        tag.write(new byte[] {0, 0, 0, 0});
        return tag.toByteArray();
    }

    private byte[] textFrame(String id, String value) throws Exception {
        ByteArrayOutputStream body = new ByteArrayOutputStream();
        body.write(3);
        body.write(value.getBytes(StandardCharsets.UTF_8));
        return frame(id, body.toByteArray());
    }

    private byte[] unsynchronizedLyricsFrame(String language, String description, String text) throws Exception {
        ByteArrayOutputStream body = new ByteArrayOutputStream();
        body.write(3);
        body.write(language.getBytes(StandardCharsets.ISO_8859_1));
        body.write(description.getBytes(StandardCharsets.UTF_8));
        body.write(0);
        body.write(text.getBytes(StandardCharsets.UTF_8));
        return frame("USLT", body.toByteArray());
    }

    private byte[] attachedPictureFrame(String mimeType, byte[] imageBytes) throws Exception {
        ByteArrayOutputStream body = new ByteArrayOutputStream();
        body.write(3);
        body.write(mimeType.getBytes(StandardCharsets.ISO_8859_1));
        body.write(0);
        body.write(3);
        body.write(0);
        body.write(imageBytes);
        return frame("APIC", body.toByteArray());
    }

    private byte[] frame(String id, byte[] body) throws Exception {
        ByteArrayOutputStream frame = new ByteArrayOutputStream();
        frame.write(id.getBytes(StandardCharsets.ISO_8859_1));
        frame.write(new byte[] {
                (byte) ((body.length >>> 24) & 0xFF),
                (byte) ((body.length >>> 16) & 0xFF),
                (byte) ((body.length >>> 8) & 0xFF),
                (byte) (body.length & 0xFF)
        });
        frame.write(new byte[] {0, 0});
        frame.write(body);
        return frame.toByteArray();
    }

    private byte[] synchsafe(int value) {
        return new byte[] {
                (byte) ((value >>> 21) & 0x7F),
                (byte) ((value >>> 14) & 0x7F),
                (byte) ((value >>> 7) & 0x7F),
                (byte) (value & 0x7F)
        };
    }
}
