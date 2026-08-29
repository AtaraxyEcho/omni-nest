package com.omninest.modules.photos.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.omninest.common.error.BusinessException;
import com.omninest.modules.photos.config.PhotoMediaLimitsProperties;
import java.awt.image.BufferedImage;
import java.nio.file.Files;
import java.nio.file.Path;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.Test;

/**
 * 照片输入格式和解码容量限制测试。
 *
 * @author OmniNest
 */
class PhotoInputGuardTest {

    private final PhotoMediaLimitsProperties properties = new PhotoMediaLimitsProperties();
    private final PhotoInputGuard guard = new PhotoInputGuard(properties, new PhotoFileDetector());

    @Test
    void inspectForDecodeReturnsDimensionsForValidImage() throws Exception {
        Path image = createImage(12, 8, "png");
        try {
            PhotoInputGuard.ImageDimensions dimensions = guard.inspectForDecode(image, "photo.png");

            assertThat(dimensions.width()).isEqualTo(12);
            assertThat(dimensions.height()).isEqualTo(8);
        } finally {
            Files.deleteIfExists(image);
        }
    }

    @Test
    void inspectForDecodeRejectsExtensionAndMagicMismatch() throws Exception {
        Path image = createImage(4, 4, "png");
        try {
            assertThatThrownBy(() -> guard.inspectForDecode(image, "photo.jpg"))
                    .isInstanceOf(BusinessException.class)
                    .hasMessage("图片扩展名与文件内容不一致");
        } finally {
            Files.deleteIfExists(image);
        }
    }

    @Test
    void inspectForDecodeRejectsPixelCountBeforeFullDecode() throws Exception {
        properties.setMaxPixels(15);
        properties.setMaxDecodedBytes(60);
        Path image = createImage(4, 4, "png");
        try {
            assertThatThrownBy(() -> guard.inspectForDecode(image, "photo.png"))
                    .isInstanceOf(BusinessException.class)
                    .hasMessage("图片解码内存超出限制");
        } finally {
            Files.deleteIfExists(image);
        }
    }

    private Path createImage(int width, int height, String format) throws Exception {
        Path image = Files.createTempFile("omninest-photo-guard-test-", "." + format);
        BufferedImage bufferedImage = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        ImageIO.write(bufferedImage, format, image.toFile());
        return image;
    }
}
