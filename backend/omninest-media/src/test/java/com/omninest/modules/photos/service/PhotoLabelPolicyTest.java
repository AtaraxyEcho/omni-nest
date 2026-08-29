package com.omninest.modules.photos.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.omninest.common.ai.ImageAnalysisGateway.BoundingBox;
import com.omninest.common.ai.ImageAnalysisGateway.ContentAnalysis;
import com.omninest.common.ai.ImageAnalysisGateway.ContentObservation;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import org.junit.jupiter.api.Test;

/**
 * 图像分析标签策略测试。
 *
 * @author OmniNest
 */
class PhotoLabelPolicyTest {

    private final PhotoLabelPolicy policy = new PhotoLabelPolicy();

    @Test
    void shouldKeepSubjectAndSceneNamespacesIndependent() {
        ContentAnalysis analysis = new ContentAnalysis(
                2,
                "content-analysis-v2",
                List.of(
                        new ContentObservation(
                                "SUBJECT",
                                "cat",
                                0.91F,
                                "coco",
                                List.of(new BoundingBox(0.1F, 0.1F, 0.4F, 0.4F))
                        ),
                        new ContentObservation(
                                "SCENE",
                                "office",
                                0.88F,
                                "places365",
                                List.of()
                        )
                )
        );

        Set<String> labels = policy.classify(analysis, false).stream()
                .map(label -> label.namespace() + ":" + label.code())
                .collect(Collectors.toSet());

        assertEquals(Set.of("SUBJECT:cat", "SCENE:office"), labels);
        assertFalse(labels.contains("SUBJECT:indoor"));
        assertFalse(labels.contains("SUBJECT:animal"));
    }

    @Test
    void shouldNotInferIndoorOrAnimalFromUncontrolledSceneText() {
        ContentAnalysis analysis = new ContentAnalysis(
                2,
                "content-analysis-v2",
                List.of(new ContentObservation(
                        "SCENE",
                        "veterinarians office",
                        0.99F,
                        "places365",
                        List.of()
                ))
        );

        List<PhotoLabelPolicy.PhotoLabel> labels = policy.classify(analysis, false);

        assertTrue(labels.isEmpty());
    }

    @Test
    void shouldKeepOnlyTheMostConfidentSceneLabel() {
        ContentAnalysis analysis = new ContentAnalysis(
                2,
                "content-analysis-v2",
                List.of(
                        new ContentObservation("SCENE", "indoor", 0.91F, "places365", List.of()),
                        new ContentObservation("SCENE", "office", 0.74F, "places365", List.of()),
                        new ContentObservation("SUBJECT", "cat", 0.89F, "coco", List.of())
                )
        );

        Set<String> labels = policy.classify(analysis, false).stream()
                .map(label -> label.namespace() + ":" + label.code())
                .collect(Collectors.toSet());

        assertEquals(Set.of("SCENE:indoor", "SUBJECT:cat"), labels);
    }

    @Test
    void shouldAddPersonOnlyWhenFaceDetectorConfirmsIt() {
        ContentAnalysis analysis = new ContentAnalysis(
                2,
                "content-analysis-v2",
                List.of(new ContentObservation(
                        "STYLE",
                        "illustration",
                        0.93F,
                        "style-policy",
                        List.of()
                ))
        );

        Set<String> labels = policy.classify(analysis, true).stream()
                .map(label -> label.namespace() + ":" + label.code())
                .collect(Collectors.toSet());

        assertEquals(Set.of("SUBJECT:person", "STYLE:illustration"), labels);
    }
}
