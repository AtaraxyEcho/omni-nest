package com.omninest.modules.music.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.omninest.common.error.BusinessException;
import com.omninest.modules.file.service.DerivedAssetStorageService;
import com.omninest.modules.file.service.FileQueryService;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

class MusicCoverServiceTest {
    private static final UUID OWNER_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");
    private static final UUID FILE_ID = UUID.fromString("70000000-0000-0000-0000-000000000001");

    private final DerivedAssetStorageService storageService = mock(DerivedAssetStorageService.class);
    private final FileQueryService fileQueryService = mock(FileQueryService.class);
    private final MusicCoverService coverService = new MusicCoverService(storageService, fileQueryService);

    @Test
    void uploadDetectsPngFromFileHeader() {
        byte[] png = new byte[]{
                (byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00
        };
        MockMultipartFile file = new MockMultipartFile("file", "cover.bin", "application/octet-stream", png);
        when(storageService.store(
                eq(OWNER_ID),
                eq("MUSIC_COVER"),
                any(UUID.class),
                eq("COVER"),
                any(String.class),
                eq("image/png"),
                any(InputStream.class)
        )).thenReturn(FILE_ID);

        var result = coverService.upload(OWNER_ID, file);

        assertThat(result.fileId()).isEqualTo(FILE_ID);
    }

    @Test
    void uploadRejectsContentWithoutSupportedImageSignature() {
        MockMultipartFile file = new MockMultipartFile(
                "file",
                "cover.jpg",
                "image/jpeg",
                "not-an-image".getBytes(StandardCharsets.US_ASCII)
        );

        assertThatThrownBy(() -> coverService.upload(OWNER_ID, file))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("仅支持");
    }

    @Test
    void validateOwnedCoverDelegatesToFileOwnershipCheck() {
        coverService.validateOwnedCover(OWNER_ID, FILE_ID);

        verify(fileQueryService).validateOwnedImage(OWNER_ID, FILE_ID);
    }
}
