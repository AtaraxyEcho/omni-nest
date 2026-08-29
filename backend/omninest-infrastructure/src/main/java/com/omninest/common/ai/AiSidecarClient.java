package com.omninest.common.ai;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import com.omninest.common.ai.ImageAnalysisGateway.FaceDetection;
import com.omninest.common.ai.ImageAnalysisGateway.BoundingBox;
import com.omninest.common.ai.ImageAnalysisGateway.ContentAnalysis;
import com.omninest.common.ai.ImageAnalysisGateway.ContentObservation;
import com.omninest.common.ai.ImageAnalysisGateway.SceneClassification;
import com.omninest.common.ai.ImageAnalysisGateway.SceneLabel;
import com.omninest.common.config.AiSidecarProperties;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.FileSystemResource;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;

/**
 * 图像分析侧车服务 HTTP 客户端。
 *
 * <p>图片请求通过标准 multipart 编码器流式发送，响应按配置限制最大字节数。
 *
 * @author OmniNest
 */
@Slf4j
@Component
public class AiSidecarClient implements ImageAnalysisGateway {

    private static final int BUFFER_SIZE = 8192;
    private static final int MAX_ERROR_SUMMARY_CHARS = 512;
    private static final String SIDECAR_TOKEN_HEADER = "X-OmniNest-Sidecar-Token";

    private final AiSidecarProperties properties;
    private final Places365LabelCatalog places365LabelCatalog;
    private final HttpClient httpClient;

    /**
     * 创建图像分析侧车客户端。
     *
     * @param properties 图像分析侧车配置
     * @param places365LabelCatalog Places365 标签目录
     */
    public AiSidecarClient(
            AiSidecarProperties properties,
            Places365LabelCatalog places365LabelCatalog
    ) {
        this.properties = properties;
        this.places365LabelCatalog = places365LabelCatalog;
        this.httpClient = HttpClient.newBuilder()
                .version(HttpClient.Version.HTTP_1_1)
                .connectTimeout(Duration.ofSeconds(properties.getTimeoutSeconds()))
                .followRedirects(HttpClient.Redirect.NEVER)
                .build();
        log.info("AiSidecarClient 初始化: endpoint={}", properties.getEndpoint());
    }

    /**
     * 返回允许发送到图像分析侧车的最大图片字节数。
     *
     * @return 最大图片字节数
     */
    @Override
    public long maxImageBytes() {
        return properties.getMaxImageBytes();
    }

    /**
     * 检测图片中的人脸。
     *
     * @param imagePath 图片文件路径
     * @return 人脸检测结果
     */
    public List<FaceDetection> detectFaces(Path imagePath) {
        return detectFaces(imagePath, properties.getEndpoint(), properties.getTimeoutSeconds());
    }

    /**
     * 使用动态端点和超时检测图片中的人脸。
     *
     * @param imagePath 图片文件路径
     * @param endpoint 侧车服务端点
     * @param timeoutSeconds 请求超时秒数
     * @return 人脸检测结果
     */
    @Override
    public List<FaceDetection> detectFaces(Path imagePath, String endpoint, int timeoutSeconds) {
        JSONArray array = JSON.parseArray(sendImageRequest(
                imagePath,
                endpoint + "/detect-faces",
                timeoutSeconds
        ));
        List<FaceDetection> result = new ArrayList<>();
        if (array == null) {
            return result;
        }
        for (int index = 0; index < array.size(); index++) {
            JSONObject object = array.getJSONObject(index);
            result.add(new FaceDetection(
                    object.getIntValue("bbox_x"),
                    object.getIntValue("bbox_y"),
                    object.getIntValue("bbox_w"),
                    object.getIntValue("bbox_h"),
                    parseFloatArray(object.getJSONArray("embedding"))
            ));
        }
        return result;
    }

    /**
     * 执行结构化图像内容分析。
     *
     * @param imagePath 图片文件路径
     * @param endpoint 侧车服务端点
     * @param timeoutSeconds 请求超时秒数
     * @return 结构化内容分析结果
     */
    @Override
    public ContentAnalysis analyzeContent(Path imagePath, String endpoint, int timeoutSeconds) {
        JSONObject object = JSON.parseObject(sendImageRequest(
                imagePath,
                endpoint + "/analyze-content",
                timeoutSeconds
        ));
        JSONArray observationsArray = object.getJSONArray("observations");
        List<ContentObservation> observations = new ArrayList<>();
        if (observationsArray != null) {
            for (int index = 0; index < observationsArray.size(); index++) {
                JSONObject observation = observationsArray.getJSONObject(index);
                String namespace = observation.getString("namespace");
                String code = normalizeObservationCode(namespace, observation.getString("code"));
                float confidence = observation.getFloatValue("confidence");
                if (namespace == null || namespace.isBlank()
                        || code == null || code.isBlank()
                        || !Float.isFinite(confidence)) {
                    continue;
                }
                observations.add(new ContentObservation(
                        namespace,
                        code,
                        confidence,
                        observation.getString("source"),
                        parseBoundingBoxes(observation.getJSONArray("boxes"))
                ));
            }
        }
        return new ContentAnalysis(
                Math.max(1, object.getIntValue("schemaVersion")),
                object.getString("pipelineVersion"),
                observations
        );
    }

    /**
     * 对图片进行场景分类。
     *
     * @param imagePath 图片文件路径
     * @return 场景分类结果
     */
    public SceneClassification classifyScene(Path imagePath) {
        return classifyScene(imagePath, properties.getEndpoint(), properties.getTimeoutSeconds());
    }

    /**
     * 使用动态端点和超时对图片进行场景分类。
     *
     * @param imagePath 图片文件路径
     * @param endpoint 侧车服务端点
     * @param timeoutSeconds 请求超时秒数
     * @return 场景分类结果
     */
    @Override
    public SceneClassification classifyScene(Path imagePath, String endpoint, int timeoutSeconds) {
        JSONObject object = JSON.parseObject(sendImageRequest(
                imagePath,
                endpoint + "/classify-scene",
                timeoutSeconds
        ));
        JSONArray labelsArray = object.getJSONArray("labels");
        List<SceneLabel> labels = new ArrayList<>();
        if (labelsArray != null) {
            for (int index = 0; index < labelsArray.size(); index++) {
                JSONObject labelObject = labelsArray.getJSONObject(index);
                labels.add(new SceneLabel(
                        places365LabelCatalog.normalize(labelObject.getString("name")),
                        labelObject.getFloatValue("confidence")
                ));
            }
        }
        return new SceneClassification(labels);
    }

    private String normalizeObservationCode(String namespace, String code) {
        if (!"SCENE".equalsIgnoreCase(namespace) || code == null || code.isBlank()) {
            return code;
        }
        if (code.startsWith("places365_")) {
            String index = code.substring("places365_".length());
            return places365LabelCatalog.normalize(index);
        }
        return places365LabelCatalog.normalize(code);
    }

    private List<BoundingBox> parseBoundingBoxes(JSONArray boxesArray) {
        if (boxesArray == null || boxesArray.isEmpty()) {
            return List.of();
        }
        List<BoundingBox> boxes = new ArrayList<>();
        for (int index = 0; index < boxesArray.size(); index++) {
            JSONObject box = boxesArray.getJSONObject(index);
            float x = box.getFloatValue("x");
            float y = box.getFloatValue("y");
            float width = box.getFloatValue("width");
            float height = box.getFloatValue("height");
            if (Float.isFinite(x) && Float.isFinite(y)
                    && Float.isFinite(width) && Float.isFinite(height)
                    && width > 0 && height > 0) {
                boxes.add(new BoundingBox(x, y, width, height));
            }
        }
        return List.copyOf(boxes);
    }

    /**
     * 对人脸嵌入向量进行聚类。
     *
     * @param embeddings 人脸嵌入向量
     * @return 每个向量对应的聚类 ID
     */
    public List<Integer> clusterFaces(List<float[]> embeddings) {
        return clusterFaces(embeddings, properties.getEndpoint(), properties.getTimeoutSeconds());
    }

    /**
     * 使用动态端点和超时对人脸嵌入向量进行聚类。
     *
     * @param embeddings 人脸嵌入向量
     * @param endpoint 侧车服务端点
     * @param timeoutSeconds 请求超时秒数
     * @return 每个向量对应的聚类 ID
     */
    @Override
    public List<Integer> clusterFaces(List<float[]> embeddings, String endpoint, int timeoutSeconds) {
        JSONArray embeddingsArray = new JSONArray();
        for (float[] embedding : embeddings) {
            JSONArray embeddingArray = new JSONArray();
            for (float value : embedding) {
                embeddingArray.add(value);
            }
            embeddingsArray.add(embeddingArray);
        }

        JSONObject requestBody = new JSONObject();
        requestBody.put("embeddings", embeddingsArray);
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(endpoint + "/cluster-faces"))
                .timeout(Duration.ofSeconds(timeoutSeconds))
                .header("Content-Type", "application/json")
                .header(SIDECAR_TOKEN_HEADER, requireSecret())
                .POST(HttpRequest.BodyPublishers.ofString(requestBody.toJSONString(), StandardCharsets.UTF_8))
                .build();

        JSONArray array = JSON.parseArray(sendRequest(request));
        List<Integer> result = new ArrayList<>();
        if (array != null) {
            for (int index = 0; index < array.size(); index++) {
                result.add(array.getIntValue(index));
            }
        }
        return result;
    }

    private String sendImageRequest(Path imagePath, String endpoint, int timeoutSeconds) {
        Path normalizedPath = requireImageFile(imagePath);
        JdkClientHttpRequestFactory requestFactory = new JdkClientHttpRequestFactory(httpClient);
        requestFactory.setReadTimeout(Duration.ofSeconds(timeoutSeconds));
        MultiValueMap<String, Object> multipartBody = new LinkedMultiValueMap<>();
        multipartBody.add("image", new FileSystemResource(normalizedPath));
        try {
            return RestClient.builder()
                    .requestFactory(requestFactory)
                    .build()
                    .post()
                    .uri(URI.create(endpoint))
                    .header(SIDECAR_TOKEN_HEADER, requireSecret())
                    .contentType(MediaType.MULTIPART_FORM_DATA)
                    .body(multipartBody)
                    .exchange((request, response) -> {
                        String responseBody;
                        try (InputStream body = response.getBody()) {
                            responseBody = readBoundedUtf8(body, properties.getMaxResponseBytes());
                        }
                        requireSuccessfulResponse(response.getStatusCode().value(), responseBody);
                        return responseBody;
                    });
        } catch (IllegalStateException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new IllegalStateException("图像分析侧车调用失败", exception);
        }
    }

    private Path requireImageFile(Path imagePath) {
        if (imagePath == null) {
            throw new IllegalArgumentException("图像分析输入文件不能为空");
        }
        Path normalizedPath = imagePath.toAbsolutePath().normalize();
        try {
            if (!Files.isRegularFile(normalizedPath)) {
            throw new IllegalArgumentException("图像分析输入文件不存在");
            }
            long sizeBytes = Files.size(normalizedPath);
            if (sizeBytes <= 0 || sizeBytes > properties.getMaxImageBytes()) {
            throw new IllegalArgumentException("图像分析输入文件大小超出限制");
            }
            return normalizedPath;
        } catch (IOException exception) {
            throw new IllegalStateException("图像分析输入文件检查失败", exception);
        }
    }

    private String requireSecret() {
        String secret = properties.getSecret();
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException("图像分析侧车认证密钥未配置");
        }
        return secret;
    }

    private String sendRequest(HttpRequest request) {
        try {
            HttpResponse<InputStream> response = httpClient.send(
                    request,
                    HttpResponse.BodyHandlers.ofInputStream()
            );
            String responseBody;
            try (InputStream body = response.body()) {
                responseBody = readBoundedUtf8(body, properties.getMaxResponseBytes());
            }
            requireSuccessfulResponse(response.statusCode(), responseBody);
            return responseBody;
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("图像分析侧车调用被中断", exception);
        } catch (IllegalStateException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new IllegalStateException("图像分析侧车调用失败", exception);
        }
    }

    private void requireSuccessfulResponse(int statusCode, String responseBody) {
        if (statusCode < 400) {
            return;
        }
        String responseSummary = summarizeErrorResponse(responseBody);
        throw new IllegalStateException(
                "图像分析侧车调用失败，状态码=" + statusCode
                        + (responseSummary.isEmpty() ? "" : "，响应摘要=" + responseSummary)
        );
    }

    private String readBoundedUtf8(InputStream input, int maxBytes) throws IOException {
        if (maxBytes <= 0) {
                throw new IllegalStateException("图像分析响应大小限制无效");
        }
        ByteArrayOutputStream output = new ByteArrayOutputStream(Math.min(maxBytes, BUFFER_SIZE));
        byte[] buffer = new byte[BUFFER_SIZE];
        int totalRead = 0;
        int read;
        while ((read = input.read(buffer)) != -1) {
            totalRead += read;
            if (totalRead > maxBytes) {
            throw new IllegalStateException("图像分析侧车响应超过大小限制");
            }
            output.write(buffer, 0, read);
        }
        return output.toString(StandardCharsets.UTF_8);
    }

    private String summarizeErrorResponse(String responseBody) {
        if (responseBody == null || responseBody.isBlank()) {
            return "";
        }
        String normalized = responseBody.replaceAll("\\s+", " ").trim();
        if (normalized.length() <= MAX_ERROR_SUMMARY_CHARS) {
            return normalized;
        }
        return normalized.substring(0, MAX_ERROR_SUMMARY_CHARS);
    }

    private float[] parseFloatArray(JSONArray array) {
        if (array == null) {
            return new float[0];
        }
        float[] result = new float[array.size()];
        for (int index = 0; index < array.size(); index++) {
            result[index] = array.getFloatValue(index);
        }
        return result;
    }

}
