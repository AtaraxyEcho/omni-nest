package com.omninest.modules.video.service;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.util.Arrays;
import org.junit.jupiter.api.Test;

/**
 * 视频探测服务边界行为测试。
 *
 * @author OmniNest
 */
class VideoProbeServiceTest {

    @Test
    void shouldStopCopyingAtConfiguredByteLimit() throws Exception {
        byte[] source = new byte[32];
        Arrays.fill(source, (byte) 7);
        ByteArrayOutputStream output = new ByteArrayOutputStream();

        long copied = VideoProbeService.copyAtMost(
                new ByteArrayInputStream(source),
                output,
                12
        );

        assertEquals(12, copied);
        assertArrayEquals(Arrays.copyOf(source, 12), output.toByteArray());
    }
}
