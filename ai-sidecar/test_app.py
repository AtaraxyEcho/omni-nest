"""AI 侧车人脸识别与边界逻辑测试。"""

import asyncio
import unittest
from unittest.mock import patch

import app
from fastapi import HTTPException
from pydantic import Field, ValidationError, create_model


class FaceOnlyAnalysisTest(unittest.TestCase):
    """验证人脸专用镜像的结构化兼容行为。"""

    def test_content_analysis_keeps_contract_without_scene_or_subject_models(self):
        """精简模式保留响应结构，但不生成场景或主体观察项。"""
        result = app._analyze_content_sync(b"unused")

        self.assertEqual(2, result.schema_version)
        self.assertEqual("face-recognition-v1", result.pipeline_version)
        self.assertEqual([], result.observations)

    def test_legacy_scene_labels_are_empty_for_face_only_analysis(self):
        """旧场景接口转换精简模式响应时返回空标签。"""
        result = app.ContentAnalysis(
            schemaVersion=2,
            pipelineVersion="face-recognition-v1",
            observations=[],
        )

        self.assertEqual([], app._legacy_scene_labels(result))

    def test_ready_requires_only_face_recognition_model(self):
        """就绪检查只依赖人脸模型，不要求已移除的内容模型。"""
        with patch.object(app, "face_app", object()):
            response = asyncio.run(app.ready())
        self.assertEqual("ready", response["status"])
        self.assertFalse(response["content_analysis"])

        with patch.object(app, "face_app", None):
            with self.assertRaises(HTTPException) as not_ready:
                asyncio.run(app.ready())
        self.assertEqual(503, not_ready.exception.status_code)

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
                    code="scene_test",
                    confidence=0.8,
                    source="test-classifier",
                ),
            ],
        )

        self.assertEqual(2, len(result.observations))
        self.assertEqual("SUBJECT", result.observations[0].namespace)
        self.assertEqual("SCENE", result.observations[1].namespace)


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
