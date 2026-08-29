package com.omninest.common.rclone;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import com.omninest.common.config.RcloneProperties;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * Rclone RC API 客户端。
 * <p>
 * 通过 HTTP POST 调用 Rclone Remote Control API，支持同步和异步操作。
 * 异步操作通过 {@code _async=true} 参数返回 jobid，可轮询 job/status 查询进度。
 *
 * @author OmniNest
 */
@Slf4j
@Component
public class RcloneRcClient implements RcloneGateway {
    private final RcloneProperties properties;
    private final HttpClient httpClient;
    private final String authHeader;

    /**
     * 根据 Rclone 运行配置创建 RC 客户端。
     *
     * @param properties Rclone 运行配置
     */
    public RcloneRcClient(RcloneProperties properties) {
        this.properties = properties;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(properties.getConnectTimeoutSeconds()))
                .followRedirects(HttpClient.Redirect.NEVER)
                .build();
        this.authHeader = buildAuthHeader(properties);
        log.debug("RcloneRcClient 初始化: endpoint={}, user={}, authHeader={}",
                properties.getEndpoint(), properties.getUsername(),
                authHeader != null ? "已设置" : "未设置");
    }

    // ========== 核心调用 ==========

    /**
     * 同步调用 Rclone RC API。
     */
    private JSONObject call(String endpoint, Map<String, Object> params) {
        HttpRequest request = buildRequest(endpoint, params);
        log.debug("Rclone RC 调用: {} {}", request.method(), request.uri());
        try {
            HttpResponse<String> response = httpClient.send(
                    request,
                    HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8)
            );
            if (response.statusCode() >= 400) {
                throw new IllegalStateException(
                        "Rclone RC 调用失败，状态码=" + response.statusCode() + "，响应=" + response.body()
                );
            }
            JSONObject body = JSON.parseObject(response.body());
            if (body == null) {
                throw new IllegalStateException("Rclone RC 响应为空");
            }
            String error = body.getString("error");
            if (error != null && !error.isBlank()) {
                throw new IllegalStateException("Rclone RC 错误: " + error);
            }
            return body;
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Rclone RC 调用被中断", exception);
        } catch (IllegalStateException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new IllegalStateException("Rclone RC 调用失败", exception);
        }
    }

    /**
     * 异步调用 Rclone RC API，返回 jobid。
     */
    private int callAsync(String endpoint, Map<String, Object> params) {
        Map<String, Object> asyncParams = new LinkedHashMap<>(params != null ? params : Map.of());
        asyncParams.put("_async", true);
        JSONObject result = call(endpoint, asyncParams);
        return result.getIntValue("jobid");
    }

    // ========== Config 管理 ==========

    /**
     * 创建 rclone remote。
     */
    @Override
    public void createRemote(String name, String type, Map<String, String> parameters) {
        Map<String, Object> params = new LinkedHashMap<>();
        params.put("name", name);
        params.put("type", type);
        params.put("parameters", parameters);
        call("config/create", params);
        log.info("Rclone remote 已创建: name={}, type={}", name, type);
    }

    /**
     * 删除 rclone remote。
     */
    @Override
    public void deleteRemote(String name) {
        call("config/delete", Map.of("name", name));
        log.info("Rclone remote 已删除: name={}", name);
    }

    /**
     * 列出所有已配置的 remote。
     */
    @Override
    public List<String> listRemoteNames() {
        JSONObject result = call("config/listremotes", Map.of());
        return result.getJSONArray("remotes").stream()
                .map(Object::toString)
                .collect(Collectors.toList());
    }

    // ========== 文件操作 ==========

    /**
     * 列出远程目录内容。
     */
    @Override
    public List<DirectoryEntry> listDirectory(String fs, String remote, boolean showHash) {
        Map<String, Object> params = new LinkedHashMap<>();
        params.put("fs", fs);
        params.put("remote", remote);
        if (showHash) {
            params.put("opt", Map.of("showHash", true));
        }
        return parseDirectoryEntries(call("operations/list", params));
    }

    /**
     * 获取 remote 空间使用情况。
     */
    @Override
    public SpaceUsage querySpaceUsage(String fs) {
        JSONObject result = call("operations/about", Map.of("fs", fs));
        return new SpaceUsage(
                result.getLongValue("total"),
                result.getLongValue("used"),
                result.getLongValue("free"),
                result.getLongValue("trashed")
        );
    }

    /**
     * 获取 remote 文件系统信息和能力。
     */
    @Override
    public Map<String, Object> queryFileSystemInfo(String fs) {
        return toPlainMap(call("operations/fsinfo", Map.of("fs", fs)));
    }

    /**
     * 创建远程目录。
     */
    @Override
    public void createDirectory(String fs, String remote) {
        call("operations/mkdir", Map.of("fs", fs, "remote", remote));
        log.info("Rclone 创建目录: fs={}, remote={}", fs, remote);
    }

    /**
     * 删除单个远程文件。
     */
    @Override
    public void deleteFile(String fs, String remote) {
        call("operations/deletefile", Map.of("fs", fs, "remote", remote));
        log.info("Rclone 删除文件: fs={}, remote={}", fs, remote);
    }

    /**
     * 移动单个文件。
     */
    @Override
    public void moveFile(String srcFs, String srcRemote, String dstFs, String dstRemote) {
        Map<String, Object> params = new LinkedHashMap<>();
        params.put("srcFs", srcFs);
        params.put("srcRemote", srcRemote);
        params.put("dstFs", dstFs);
        params.put("dstRemote", dstRemote);
        call("operations/movefile", params);
        log.info("Rclone 移动文件: {}:{} → {}:{}", srcFs, srcRemote, dstFs, dstRemote);
    }

    // ========== 同步操作（异步） ==========

    /**
     * 异步复制目录（不删除目标多余文件），返回 jobid。
     */
    @Override
    public int startDirectoryCopy(String srcFs, String dstFs, String group) {
        Map<String, Object> params = new LinkedHashMap<>();
        params.put("srcFs", srcFs);
        params.put("dstFs", dstFs);
        params.put("_group", group);
        return callAsync("sync/copy", params);
    }

    /**
     * 异步复制单个文件，返回作业编号。
     *
     * @param srcFs 源文件系统标识
     * @param srcRemote 源文件路径
     * @param dstFs 目标文件系统标识
     * @param dstRemote 目标文件路径
     * @param group 传输统计分组
     * @return Rclone 作业编号
     */
    @Override
    public int startFileCopy(String srcFs, String srcRemote, String dstFs, String dstRemote, String group) {
        Map<String, Object> params = new LinkedHashMap<>();
        params.put("srcFs", srcFs);
        params.put("srcRemote", srcRemote);
        params.put("dstFs", dstFs);
        params.put("dstRemote", dstRemote);
        params.put("_group", group);
        return callAsync("operations/copyfile", params);
    }

    // ========== Job 管理 ==========

    /**
     * 查询异步 job 状态。
     */
    @Override
    public JobStatus queryJobStatus(int jobId) {
        JSONObject result = call("job/status", Map.of("jobid", jobId));
        return new JobStatus(
                result.getBooleanValue("finished"),
                result.getBooleanValue("success"),
                result.getString("error")
        );
    }

    /**
     * 停止正在运行的 job。
     */
    @Override
    public void stopJob(int jobId) {
        call("job/stop", Map.of("jobid", jobId));
        log.info("Rclone job 已停止: jobId={}", jobId);
    }

    // ========== Core 操作 ==========

    /**
     * 获取当前传输统计信息。
     */
    @Override
    public TransferStats queryTransferStats(String group) {
        JSONObject result;
        if (group == null || group.isBlank()) {
            result = call("core/stats", Map.of());
        } else {
            result = call("core/stats", Map.of("_group", group));
        }
        return new TransferStats(
                result.getLongValue("totalBytes"),
                result.getLongValue("bytes"),
                result.getLongValue("speed")
        );
    }

    // ========== 内部方法 ==========

    private HttpRequest buildRequest(String endpoint, Map<String, Object> params) {
        String url = properties.getEndpoint().replaceAll("/+$", "") + "/" + endpoint;
        String jsonBody = JSON.toJSONString(params != null ? params : Map.of());

        HttpRequest.Builder builder = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(properties.getReadTimeoutSeconds()))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(jsonBody, StandardCharsets.UTF_8));

        if (authHeader != null) {
            builder.header("Authorization", authHeader);
        }

        return builder.build();
    }

    private String buildAuthHeader(RcloneProperties properties) {
        String user = properties.getUsername();
        String pass = properties.getPassword();
        if (user == null || user.isBlank()) {
            return null;
        }
        String credentials = user + ":" + (pass != null ? pass : "");
        return "Basic " + Base64.getEncoder().encodeToString(credentials.getBytes(StandardCharsets.UTF_8));
    }

    static List<DirectoryEntry> parseDirectoryEntries(JSONObject result) {
        JSONArray entries = result.getJSONArray("list");
        if (entries == null) {
            return List.of();
        }
        List<DirectoryEntry> mapped = new ArrayList<>();
        for (Object value : entries) {
            if (!(value instanceof JSONObject entry)) {
                continue;
            }
            mapped.add(new DirectoryEntry(
                    entry.getString("Name"),
                    entry.getString("Path"),
                    entry.getBooleanValue("IsDir"),
                    entry.getLongValue("Size"),
                    parseInstant(entry.getString("ModTime")),
                    entry.getString("MimeType"),
                    entry.getString("Hash"),
                    toPlainMap(entry)
            ));
        }
        return List.copyOf(mapped);
    }

    static Map<String, Object> toPlainMap(JSONObject source) {
        Map<String, Object> mapped = new LinkedHashMap<>();
        source.forEach((key, value) -> mapped.put(key, toPlainValue(value)));
        return mapped;
    }

    private static Object toPlainValue(Object value) {
        if (value instanceof JSONObject object) {
            return toPlainMap(object);
        }
        if (value instanceof JSONArray array) {
            List<Object> mapped = new ArrayList<>();
            for (Object item : array) {
                mapped.add(toPlainValue(item));
            }
            return mapped;
        }
        return value;
    }

    private static Instant parseInstant(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        try {
            return Instant.parse(value);
        } catch (DateTimeParseException exception) {
            return null;
        }
    }
}
