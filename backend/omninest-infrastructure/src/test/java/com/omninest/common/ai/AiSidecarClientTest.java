package com.omninest.common.ai;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.omninest.common.ai.ImageAnalysisGateway.ContentAnalysis;
import com.omninest.common.config.AiSidecarProperties;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.channels.FileChannel;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * 图像分析侧车客户端流式请求和容量限制测试。
 *
 * @author OmniNest
 */
class AiSidecarClientTest {

    @TempDir
    Path tempDirectory;

    private HttpServer server;
    private String endpoint;
    private AiSidecarProperties properties;

    @BeforeEach
    void setUp() throws IOException {
        server = HttpServer.create(new InetSocketAddress(InetAddress.getLoopbackAddress(), 0), 0);
        server.start();
        endpoint = "http://127.0.0.1:" + server.getAddress().getPort();
        properties = new AiSidecarProperties();
        properties.setSecret("test-sidecar-secret");
        properties.setMaxImageBytes(1024);
        properties.setMaxResponseBytes(1024);
    }

    @AfterEach
    void tearDown() {
        server.stop(0);
    }

    @Test
    void shouldStreamImageFileInMultipartRequest() throws IOException {
        byte[] imageBytes = new byte[]{1, 2, 3, 4, 5};
        Path imageFile = tempDirectory.resolve("photo.jpg");
        Files.write(imageFile, imageBytes);
        AtomicReference<byte[]> requestBody = new AtomicReference<>();
        AtomicReference<String> requestContentType = new AtomicReference<>();
        AtomicReference<String> requestProtocol = new AtomicReference<>();
        AtomicReference<String> requestToken = new AtomicReference<>();
        server.createContext("/detect-faces", exchange -> {
            requestProtocol.set(exchange.getProtocol());
            requestContentType.set(exchange.getRequestHeaders().getFirst("Content-Type"));
            requestToken.set(exchange.getRequestHeaders().getFirst("X-OmniNest-Sidecar-Token"));
            requestBody.set(exchange.getRequestBody().readAllBytes());
            respond(exchange, "[{\"bbox_x\":1,\"bbox_y\":2,\"bbox_w\":3,\"bbox_h\":4,\"embedding\":[0.5]}]");
        });

        AiSidecarClient client = new AiSidecarClient(properties, new Places365LabelCatalog());
        var result = client.detectFaces(imageFile, endpoint, 5);

        assertEquals(1, result.size());
        assertEquals(1, result.getFirst().bboxX());
        assertEquals("HTTP/1.1", requestProtocol.get());
        assertTrue(requestContentType.get().startsWith("multipart/form-data;boundary="));
        assertEquals("test-sidecar-secret", requestToken.get());
        assertTrue(new String(requestBody.get(), StandardCharsets.ISO_8859_1)
                .contains("name=\"image\""));
        assertTrue(containsSequence(requestBody.get(), imageBytes));
    }

    @Test
    void shouldRejectRequestWhenSidecarSecretIsMissing() throws IOException {
        properties.setSecret(" ");
        Path imageFile = tempDirectory.resolve("photo.jpg");
        Files.write(imageFile, new byte[]{1, 2, 3});
        AiSidecarClient client = new AiSidecarClient(properties, new Places365LabelCatalog());

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                () -> client.detectFaces(imageFile, endpoint, 5)
        );

        assertTrue(exception.getMessage().contains("认证密钥未配置"));
    }

    @Test
    void shouldStreamLargeImageWithinBoundedHeap() throws IOException {
        long imageBytes = 64L * 1024 * 1024;
        properties.setMaxImageBytes(imageBytes + 1);
        Path imageFile = tempDirectory.resolve("large-photo.jpg");
        try (FileChannel channel = FileChannel.open(
                imageFile,
                StandardOpenOption.CREATE,
                StandardOpenOption.WRITE
        )) {
            channel.position(imageBytes - 1);
            channel.write(ByteBuffer.wrap(new byte[]{1}));
        }
        AtomicLong receivedBytes = new AtomicLong();
        AtomicInteger maxReadBytes = new AtomicInteger();
        server.createContext("/detect-faces", exchange -> {
            byte[] buffer = new byte[8192];
            try (InputStream input = exchange.getRequestBody()) {
                int readBytes;
                while ((readBytes = input.read(buffer)) != -1) {
                    receivedBytes.addAndGet(readBytes);
                    maxReadBytes.accumulateAndGet(readBytes, Math::max);
                }
            }
            respond(exchange, "[]");
        });
        AiSidecarClient client = new AiSidecarClient(properties, new Places365LabelCatalog());

        var result = client.detectFaces(imageFile, endpoint, 30);

        assertTrue(result.isEmpty());
        assertTrue(receivedBytes.get() > imageBytes);
        assertTrue(maxReadBytes.get() <= 8192);
    }

    @Test
    void shouldRejectImageBeforeSendingWhenFileExceedsLimit() throws IOException {
        properties.setMaxImageBytes(4);
        Path imageFile = tempDirectory.resolve("oversized.jpg");
        Files.write(imageFile, new byte[]{1, 2, 3, 4, 5});
        AiSidecarClient client = new AiSidecarClient(properties, new Places365LabelCatalog());

        assertThrows(
                IllegalArgumentException.class,
                () -> client.detectFaces(imageFile, endpoint, 5)
        );
    }

    @Test
    void shouldRejectOversizedSidecarResponse() throws IOException {
        properties.setMaxResponseBytes(8);
        Path imageFile = tempDirectory.resolve("photo.jpg");
        Files.write(imageFile, new byte[]{1, 2, 3});
        server.createContext("/classify-scene", exchange -> respond(exchange, "{\"labels\":[]}"));
        AiSidecarClient client = new AiSidecarClient(properties, new Places365LabelCatalog());

        assertThrows(
                IllegalStateException.class,
                () -> client.classifyScene(imageFile, endpoint, 5)
        );
    }

    @Test
    void shouldKeepBoundedSidecarErrorDetails() throws IOException {
        Path imageFile = tempDirectory.resolve("photo.jpg");
        Files.write(imageFile, new byte[]{1, 2, 3});
        server.createContext("/detect-faces", exchange -> respond(
                exchange,
                422,
                "{\"detail\":\"missing multipart boundary\"}"
        ));
        AiSidecarClient client = new AiSidecarClient(properties, new Places365LabelCatalog());

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                () -> client.detectFaces(imageFile, endpoint, 5)
        );

        assertTrue(exception.getMessage().contains("422"));
        assertTrue(exception.getMessage().contains("missing multipart boundary"));
    }

    @Test
    void shouldMapNumericPlaces365LabelsToReadableNames() throws IOException {
        Path imageFile = tempDirectory.resolve("photo.jpg");
        Files.write(imageFile, new byte[]{1, 2, 3});
        server.createContext("/classify-scene", exchange -> respond(
                exchange,
                "{\"labels\":["
                        + "{\"name\":\"0\",\"confidence\":0.7},"
                        + "{\"name\":\"8\",\"confidence\":0.2}]}"
        ));
        AiSidecarClient client = new AiSidecarClient(properties, new Places365LabelCatalog());

        var result = client.classifyScene(imageFile, endpoint, 5);

        assertEquals("Airfield", result.labels().get(0).name());
        assertEquals("Apartment building / outdoor", result.labels().get(1).name());
        assertEquals(0.7F, result.labels().get(0).confidence());
    }

    @Test
    void shouldParseStructuredContentAnalysisWithNamespacesAndBoxes() throws IOException {
        Path imageFile = tempDirectory.resolve("photo.jpg");
        Files.write(imageFile, new byte[]{1, 2, 3});
        server.createContext("/analyze-content", exchange -> respond(
                exchange,
                "{\"schemaVersion\":2,\"pipelineVersion\":\"content-analysis-v2\","
                        + "\"observations\":["
                        + "{\"namespace\":\"SUBJECT\",\"code\":\"cat\","
                        + "\"confidence\":0.91,\"source\":\"coco\","
                        + "\"boxes\":[{\"x\":0.1,\"y\":0.2,\"width\":0.3,\"height\":0.4}]},"
                        + "{\"namespace\":\"SCENE\",\"code\":\"places365_0\","
                        + "\"confidence\":0.8,\"source\":\"places365\",\"boxes\":[]}]"
                        + "}"
        ));
        AiSidecarClient client = new AiSidecarClient(properties, new Places365LabelCatalog());

        ContentAnalysis result = client.analyzeContent(
                imageFile,
                endpoint,
                5
        );

        assertEquals(2, result.schemaVersion());
        assertEquals("content-analysis-v2", result.pipelineVersion());
        assertEquals(2, result.observations().size());
        assertEquals("SUBJECT", result.observations().get(0).namespace());
        assertEquals("cat", result.observations().get(0).code());
        assertEquals(1, result.observations().get(0).boxes().size());
        assertEquals("SCENE", result.observations().get(1).namespace());
        assertEquals("Airfield", result.observations().get(1).code());
    }

    private void respond(HttpExchange exchange, String body) throws IOException {
        respond(exchange, 200, body);
    }

    private void respond(HttpExchange exchange, int status, String body) throws IOException {
        byte[] response = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(status, response.length);
        exchange.getResponseBody().write(response);
        exchange.close();
    }

    private boolean containsSequence(byte[] source, byte[] expected) {
        for (int offset = 0; offset <= source.length - expected.length; offset++) {
            boolean matches = true;
            for (int index = 0; index < expected.length; index++) {
                if (source[offset + index] != expected[index]) {
                    matches = false;
                    break;
                }
            }
            if (matches) {
                return true;
            }
        }
        return false;
    }
}
