"""AI 侧车模型缓存辅助逻辑测试。"""

import io
import unittest
from unittest.mock import patch

import app
from fastapi import HTTPException
from pydantic import Field, ValidationError, create_model


class ModelDownloadTest(unittest.TestCase):
    """验证模型下载的总耗时边界。"""

    def test_copy_with_deadline_stops_continuous_slow_response(self):
        """持续返回数据的响应也必须受到总耗时限制。"""
        source = io.BytesIO(b"first-chunk" + b"second-chunk")
        output = io.BytesIO()

        with patch.object(app, "MODEL_DOWNLOAD_CHUNK_SIZE", 11):
            with patch.object(app.time, "monotonic", side_effect=[0.0, 31.0]):
                with self.assertRaises(TimeoutError):
                    app._copy_with_deadline(source, output, 30.0)

        self.assertEqual(b"first-chunk", output.getvalue())

    def test_copy_with_deadline_copies_complete_response(self):
        """截止时间内的完整响应必须全部写入目标。"""
        source = io.BytesIO(b"complete-model")
        output = io.BytesIO()

        with patch.object(app.time, "monotonic", return_value=0.0):
            app._copy_with_deadline(source, output, 30.0)

        self.assertEqual(b"complete-model", output.getvalue())

    def test_subject_mapping_does_not_create_generic_animal_label(self):
        """主体映射只返回受控的具体编码，不通过概率区间生成动物标签。"""
        self.assertEqual("cat", app.COCO_SUBJECT_CODES["cat"])
        self.assertEqual("dog", app.COCO_SUBJECT_CODES["dog"])
        self.assertNotIn("animal", app.COCO_SUBJECT_CODES.values())

    def test_content_observation_keeps_namespaces_separate(self):
        """结构化观察项必须分别表达主体和场景。"""
        result = app.ContentAnalysis(
            schemaVersion=2,
            pipelineVersion="test",
            observations=[
                app.ContentObservation(
                    namespace="SUBJECT",
                    code="person",
                    confidence=0.9,
                    source="test-detector",
                ),
                app.ContentObservation(
                    namespace="SCENE",
                    code="places365_12",
                    confidence=0.8,
                    source="places365",
                ),
            ],
        )

        self.assertEqual(2, len(result.observations))
        self.assertEqual("SUBJECT", result.observations[0].namespace)
        self.assertEqual("SCENE", result.observations[1].namespace)

    def test_scene_classifier_default_is_conservative(self):
        """场景分类默认阈值应过滤低置信度候选。"""
        self.assertGreaterEqual(app.SCENE_MIN_CONFIDENCE, 0.35)


class SidecarBoundaryTest(unittest.TestCase):
    """验证推理接口认证和聚类输入边界。"""

    def test_sidecar_token_is_required(self):
        """缺少或错误的共享密钥必须被拒绝。"""
        with patch.object(app, "SIDECAR_SECRET", "expected-secret"):
            with self.assertRaises(HTTPException) as missing:
                app._require_sidecar_token(None)
            with self.assertRaises(HTTPException) as invalid:
                app._require_sidecar_token("wrong-secret")

        self.assertEqual(401, missing.exception.status_code)
        self.assertEqual(401, invalid.exception.status_code)

    def test_sidecar_token_accepts_exact_secret(self):
        """正确共享密钥通过常量时间比较。"""
        with patch.object(app, "SIDECAR_SECRET", "expected-secret"):
            self.assertIsNone(app._require_sidecar_token("expected-secret"))

    def test_cluster_request_rejects_excessive_face_count(self):
        """聚类请求不能超过服务端硬上限。"""
        with patch.object(app, "MAX_CLUSTER_FACES", 1):
            constrained_model = create_model(
                "ConstrainedClusterRequest",
                embeddings=(list[list[float]], Field(max_length=1)),
            )
            with self.assertRaises(ValidationError):
                constrained_model(embeddings=[[0.0], [1.0]])


if __name__ == "__main__":
    unittest.main()
