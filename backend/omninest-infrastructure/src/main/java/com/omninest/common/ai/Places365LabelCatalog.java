package com.omninest.common.ai;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 读取 Places365 类别清单，并将侧车标签规范化为可读名称。
 *
 * @author OmniNest
 */
@Slf4j
@Component
public class Places365LabelCatalog {

    private static final String RESOURCE_PATH = "/ai/places365-categories.txt";

    private final Map<Integer, String> labels;

    /**
     * 从类路径加载 Places365 类别清单。
     */
    public Places365LabelCatalog() {
        this.labels = loadLabels();
    }

    /**
     * 将数字索引或 Places365 路径转换为可读标签。
     *
     * @param rawLabel 侧车返回的原始标签
     * @return 可读标签，无法映射时保留规范化后的原始值
     */
    public String normalize(String rawLabel) {
        if (rawLabel == null || rawLabel.isBlank()) {
            return rawLabel;
        }
        String trimmed = rawLabel.trim();
        try {
            int index = Integer.parseInt(trimmed);
            String mapped = labels.get(index);
            return mapped == null ? trimmed : mapped;
        } catch (NumberFormatException exception) {
            return displayName(trimmed);
        }
    }

    private Map<Integer, String> loadLabels() {
        InputStream inputStream = Places365LabelCatalog.class.getResourceAsStream(RESOURCE_PATH);
        if (inputStream == null) {
            log.warn("Places365 类别清单不存在: resource={}", RESOURCE_PATH);
            return Map.of();
        }
        Map<Integer, String> loaded = new LinkedHashMap<>();
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(inputStream, StandardCharsets.UTF_8)
        )) {
            String line;
            while ((line = reader.readLine()) != null) {
                parseLine(line, loaded);
            }
        } catch (IOException exception) {
            log.warn("读取 Places365 类别清单失败", exception);
            return Map.of();
        }
        log.info("Places365 类别清单加载完成: count={}", loaded.size());
        return Map.copyOf(loaded);
    }

    private void parseLine(String line, Map<Integer, String> target) {
        String trimmed = line.trim();
        int separator = trimmed.lastIndexOf(' ');
        if (separator <= 0 || separator >= trimmed.length() - 1) {
            return;
        }
        try {
            int index = Integer.parseInt(trimmed.substring(separator + 1));
            target.put(index, displayName(trimmed.substring(0, separator)));
        } catch (NumberFormatException exception) {
            log.debug("忽略无法解析的 Places365 类别行: {}", trimmed);
        }
    }

    private String displayName(String label) {
        String normalized = label.replaceFirst("^/[a-z]/", "")
                .replace('_', ' ')
                .replace("/", " / ")
                .replaceAll("\\s+", " ")
                .trim();
        if (normalized.isEmpty()) {
            return label;
        }
        return Character.toUpperCase(normalized.charAt(0)) + normalized.substring(1);
    }
}
