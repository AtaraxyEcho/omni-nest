package com.omninest.modules.photos.service;

import com.omninest.common.ai.ImageAnalysisGateway.BoundingBox;
import com.omninest.common.ai.ImageAnalysisGateway.ContentAnalysis;
import com.omninest.common.ai.ImageAnalysisGateway.ContentObservation;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.stereotype.Component;

/**
 * 将图像分析侧车结果映射为受控的照片标签。
 *
 * <p>该策略只做同一命名空间内的精确映射，不使用跨命名空间关键词推导。
 *
 * @author OmniNest
 */
@Component
public class PhotoLabelPolicy {

    public static final String SUBJECT = "SUBJECT";
    public static final String SCENE = "SCENE";
    public static final String STYLE = "STYLE";
    public static final String FACE = "FACE";

    private static final float SUBJECT_MIN_CONFIDENCE = 0.65F;
    private static final float SCENE_MIN_CONFIDENCE = 0.55F;
    private static final float STYLE_MIN_CONFIDENCE = 0.70F;
    private static final int MAX_LABELS = 24;
    private static final int MAX_SCENE_LABELS = 1;
    private static final int MAX_STYLE_LABELS = 1;

    private static final Map<String, String> SUBJECT_CODES = Map.ofEntries(
            Map.entry("person", "person"),
            Map.entry("cat", "cat"),
            Map.entry("dog", "dog"),
            Map.entry("bird", "bird"),
            Map.entry("horse", "horse"),
            Map.entry("sheep", "sheep"),
            Map.entry("cow", "cow"),
            Map.entry("elephant", "elephant"),
            Map.entry("bear", "bear"),
            Map.entry("zebra", "zebra"),
            Map.entry("giraffe", "giraffe"),
            Map.entry("vehicle", "vehicle"),
            Map.entry("food", "food"),
            Map.entry("plant", "plant"),
            Map.entry("book", "book")
    );

    private static final Map<String, String> SCENE_CODES = Map.ofEntries(
            Map.entry("indoor", "indoor"),
            Map.entry("outdoor", "outdoor"),
            Map.entry("nature", "nature"),
            Map.entry("urban", "urban"),
            Map.entry("beach", "beach"),
            Map.entry("mountain", "mountain"),
            Map.entry("forest", "forest"),
            Map.entry("lake", "lake"),
            Map.entry("ocean", "ocean"),
            Map.entry("river", "river"),
            Map.entry("office", "office"),
            Map.entry("restaurant", "restaurant"),
            Map.entry("kitchen", "kitchen"),
            Map.entry("bedroom", "bedroom"),
            Map.entry("classroom", "classroom"),
            Map.entry("city", "city"),
            Map.entry("street", "street"),
            Map.entry("park", "park"),
            Map.entry("stadium", "stadium"),
            Map.entry("night", "night")
    );

    private static final Map<String, String> STYLE_CODES = Map.ofEntries(
            Map.entry("photograph", "photograph"),
            Map.entry("illustration", "illustration"),
            Map.entry("anime", "anime"),
            Map.entry("3d_render", "3d_render"),
            Map.entry("screenshot", "screenshot"),
            Map.entry("document", "document"),
            Map.entry("artwork", "artwork")
    );

    /**
     * 生成稳定的自动标签。
     *
     * @param analysis 侧车结构化分析结果
     * @param containsPerson 是否检测到人脸
     * @return 受控标签列表
     */
    public List<PhotoLabel> classify(ContentAnalysis analysis, boolean containsPerson) {
        Map<String, PhotoLabel> labels = new LinkedHashMap<>();
        if (containsPerson) {
            labels.put(key(SUBJECT, "person"), new PhotoLabel(
                    SUBJECT, "person", 1.0F, "face-detector", List.of()
            ));
        }
        if (analysis == null || analysis.observations() == null) {
            return List.copyOf(labels.values());
        }
        for (ContentObservation observation : analysis.observations()) {
            if (observation == null || observation.namespace() == null
                    || observation.code() == null || !Float.isFinite(observation.confidence())) {
                continue;
            }
            String namespace = observation.namespace().trim().toUpperCase(Locale.ROOT);
            String code = normalize(observation.code());
            String mappedCode = switch (namespace) {
                case SUBJECT -> SUBJECT_CODES.get(code);
                case SCENE -> SCENE_CODES.get(code);
                case STYLE -> STYLE_CODES.get(code);
                default -> null;
            };
            if (mappedCode == null || observation.confidence() < minimumConfidence(namespace)) {
                continue;
            }
            String mapKey = key(namespace, mappedCode);
            PhotoLabel current = labels.get(mapKey);
            if (current == null || current.confidence() < observation.confidence()) {
                labels.put(mapKey, new PhotoLabel(
                        namespace,
                        mappedCode,
                        observation.confidence(),
                        observation.source(),
                        observation.boxes()
                ));
            }
        }
        List<PhotoLabel> candidates = labels.values().stream()
                .sorted(Comparator.comparing(PhotoLabel::confidence).reversed()
                        .thenComparing(PhotoLabel::namespace)
                        .thenComparing(PhotoLabel::code))
                .toList();
        List<PhotoLabel> result = new ArrayList<>();
        Map<String, Integer> namespaceCounts = new LinkedHashMap<>();
        for (PhotoLabel candidate : candidates) {
            int namespaceLimit = switch (candidate.namespace()) {
                case SCENE -> MAX_SCENE_LABELS;
                case STYLE -> MAX_STYLE_LABELS;
                default -> MAX_LABELS;
            };
            int count = namespaceCounts.getOrDefault(candidate.namespace(), 0);
            if (count >= namespaceLimit) {
                continue;
            }
            result.add(candidate);
            namespaceCounts.put(candidate.namespace(), count + 1);
            if (result.size() == MAX_LABELS) {
                break;
            }
        }
        return List.copyOf(result);
    }

    private float minimumConfidence(String namespace) {
        return switch (namespace) {
            case SUBJECT -> SUBJECT_MIN_CONFIDENCE;
            case SCENE -> SCENE_MIN_CONFIDENCE;
            case STYLE -> STYLE_MIN_CONFIDENCE;
            default -> 1.0F;
        };
    }

    private String normalize(String value) {
        return value.trim().toLowerCase(Locale.ROOT).replace('-', '_');
    }

    private String key(String namespace, String code) {
        return namespace + ":" + code;
    }

    /**
     * 结构化自动标签。
     *
     * @param namespace 命名空间
     * @param code 稳定编码
     * @param confidence 置信度
     * @param source 结果来源
     * @param boxes 边界框
     */
    public record PhotoLabel(
            String namespace,
            String code,
            float confidence,
            String source,
            List<BoundingBox> boxes
    ) {
        public PhotoLabel {
            boxes = boxes == null ? List.of() : List.copyOf(new ArrayList<>(boxes));
        }
    }
}
