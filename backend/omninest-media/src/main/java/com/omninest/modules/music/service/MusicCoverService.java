package com.omninest.modules.music.service;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.modules.file.service.DerivedAssetStorageService;
import com.omninest.modules.file.service.FileQueryService;
import com.omninest.modules.music.dto.MusicDtos.MusicCoverUploadDto;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

/**
 * 负责音乐封面的校验、存储和所有权检查。
 *
 * @author OmniNest
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MusicCoverService {
    private static final long MAX_COVER_SIZE_BYTES = 8L * 1024 * 1024;

    private final DerivedAssetStorageService derivedAssetStorageService;
    private final FileQueryService fileQueryService;

    /**
     * 将用户上传的图片保存为音乐封面资产。
     *
     * @param ownerUserId 所属用户标识
     * @param file 上传文件
     * @return 封面文件标识
     */
    public MusicCoverUploadDto upload(UUID ownerUserId, MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException(ErrorCode.PARAM_ERROR, "封面文件不能为空");
        }
        if (file.getSize() > MAX_COVER_SIZE_BYTES) {
            throw new BusinessException(ErrorCode.PARAM_ERROR, "封面文件不能超过 8MB");
        }
        try {
            byte[] bytes = file.getBytes();
            ImageType imageType = detectImageType(bytes);
            UUID resourceId = UUID.randomUUID();
            try (InputStream input = new ByteArrayInputStream(bytes)) {
                UUID fileId = derivedAssetStorageService.store(
                        ownerUserId,
                        "MUSIC_COVER",
                        resourceId,
                        "COVER",
                        "cover_" + resourceId + imageType.extension(),
                        imageType.mimeType(),
                        input
                );
                log.info("音乐封面已上传: userId={}, fileId={}", ownerUserId, fileId);
                return new MusicCoverUploadDto(fileId);
            }
        } catch (IOException ex) {
            throw new BusinessException(ErrorCode.FILE_UPLOAD_FAILED, "封面文件读取失败");
        }
    }

    /**
     * 校验封面文件属于当前用户且为图片。
     *
     * @param ownerUserId 所属用户标识
     * @param fileId 封面文件标识
     */
    public void validateOwnedCover(UUID ownerUserId, UUID fileId) {
        if (fileId != null) {
            fileQueryService.validateOwnedImage(ownerUserId, fileId);
        }
    }

    private ImageType detectImageType(byte[] bytes) {
        if (isJpeg(bytes)) {
            return new ImageType("image/jpeg", ".jpg");
        }
        if (startsWith(bytes, new byte[]{(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A})) {
            return new ImageType("image/png", ".png");
        }
        if (startsWith(bytes, "GIF87a".getBytes(StandardCharsets.US_ASCII))
                || startsWith(bytes, "GIF89a".getBytes(StandardCharsets.US_ASCII))) {
            return new ImageType("image/gif", ".gif");
        }
        if (bytes.length >= 12
                && startsWith(bytes, "RIFF".getBytes(StandardCharsets.US_ASCII))
                && matchesAt(bytes, 8, "WEBP".getBytes(StandardCharsets.US_ASCII))) {
            return new ImageType("image/webp", ".webp");
        }
        throw new BusinessException(ErrorCode.PARAM_ERROR, "仅支持 JPEG、PNG、GIF 或 WebP 封面");
    }

    private boolean isJpeg(byte[] bytes) {
        return bytes.length >= 3
                && bytes[0] == (byte) 0xFF
                && bytes[1] == (byte) 0xD8
                && bytes[2] == (byte) 0xFF;
    }

    private boolean startsWith(byte[] bytes, byte[] prefix) {
        return matchesAt(bytes, 0, prefix);
    }

    private boolean matchesAt(byte[] bytes, int offset, byte[] expected) {
        if (bytes.length < offset + expected.length) {
            return false;
        }
        for (int index = 0; index < expected.length; index++) {
            if (bytes[offset + index] != expected[index]) {
                return false;
            }
        }
        return true;
    }

    private record ImageType(String mimeType, String extension) {
    }
}
