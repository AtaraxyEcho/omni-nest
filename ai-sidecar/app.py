"""
OmniNest 图像分析侧车服务。
提供主体检测、场景分类、人脸检测和人脸聚类功能。
"""

import hashlib
import hmac
import io
import logging
import os
import time
import urllib.request
from asyncio import Semaphore, to_thread
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Annotated

import numpy as np
from fastapi import Depends, FastAPI, File, Header, HTTPException, UploadFile
from pydantic import BaseModel, Field

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 全局模型引用（延迟加载）
face_app = None
scene_model = None
scene_labels = None
object_detector = None
object_detector_labels = None

PLACES365_MODEL_URL = os.environ.get(
    "PLACES365_MODEL_URL",
    "http://places2.csail.mit.edu/models_places365/resnet50_places365.pth.tar",
)
PLACES365_MODEL_SHA256 = (
    "46529c86902bd0cfb0ea562a30b2850c28d2620d96282b3db9c318e1d774f6c5"
)
MODEL_DOWNLOAD_ATTEMPTS = 3
MODEL_DOWNLOAD_TIMEOUT_SECONDS = int(
    os.environ.get("MODEL_DOWNLOAD_TIMEOUT_SECONDS", "30")
)
MODEL_DOWNLOAD_CHUNK_SIZE = 1024 * 1024
SIDECAR_TOKEN_HEADER = "X-OmniNest-Sidecar-Token"
SIDECAR_SECRET = os.environ.get("OMNINEST_AI_SIDECAR_SECRET", "")
MAX_IMAGE_BYTES = int(os.environ.get("AI_MAX_IMAGE_BYTES", str(32 * 1024 * 1024)))
MAX_IMAGE_WIDTH = int(os.environ.get("AI_MAX_IMAGE_WIDTH", "30000"))
MAX_IMAGE_HEIGHT = int(os.environ.get("AI_MAX_IMAGE_HEIGHT", "30000"))
MAX_IMAGE_PIXELS = int(os.environ.get("AI_MAX_IMAGE_PIXELS", "100000000"))
MAX_CLUSTER_FACES = int(os.environ.get("AI_MAX_CLUSTER_FACES", "10000"))
FACE_EMBEDDING_DIMENSION = int(os.environ.get("AI_FACE_EMBEDDING_DIMENSION", "512"))
MAX_CONCURRENT_INFERENCES = int(os.environ.get("AI_MAX_CONCURRENT_INFERENCES", "2"))
CONTENT_ANALYSIS_SCHEMA_VERSION = 2
CONTENT_ANALYSIS_PIPELINE_VERSION = os.environ.get(
    "IMAGE_ANALYSIS_PIPELINE_VERSION",
    "content-analysis-v2",
)
SCENE_MIN_CONFIDENCE = float(os.environ.get("IMAGE_ANALYSIS_SCENE_MIN_CONFIDENCE", "0.35"))
SUBJECT_MIN_CONFIDENCE = float(
    os.environ.get("IMAGE_ANALYSIS_SUBJECT_MIN_CONFIDENCE", "0.65")
)
SUBJECT_MIN_AREA_RATIO = float(
    os.environ.get("IMAGE_ANALYSIS_SUBJECT_MIN_AREA_RATIO", "0.01")
)
UPLOAD_READ_CHUNK_SIZE = 1024 * 1024
inference_slots = Semaphore(MAX_CONCURRENT_INFERENCES)

COCO_SUBJECT_CODES = {
    "person": "person",
    "bird": "bird",
    "cat": "cat",
    "dog": "dog",
    "horse": "horse",
    "sheep": "sheep",
    "cow": "cow",
    "elephant": "elephant",
    "bear": "bear",
    "zebra": "zebra",
    "giraffe": "giraffe",
    "backpack": "bag",
    "umbrella": "umbrella",
    "handbag": "bag",
    "suitcase": "luggage",
    "bottle": "bottle",
    "wine glass": "drinkware",
    "cup": "drinkware",
    "fork": "cutlery",
    "knife": "cutlery",
    "spoon": "cutlery",
    "bowl": "food",
    "banana": "food",
    "apple": "food",
    "sandwich": "food",
    "orange": "food",
    "broccoli": "food",
    "carrot": "food",
    "hot dog": "food",
    "pizza": "food",
    "donut": "food",
    "cake": "food",
    "car": "vehicle",
    "motorcycle": "vehicle",
    "airplane": "vehicle",
    "bus": "vehicle",
    "train": "vehicle",
    "truck": "vehicle",
    "boat": "vehicle",
    "bicycle": "vehicle",
    "traffic light": "traffic",
    "stop sign": "traffic",
    "parking meter": "traffic",
    "bench": "furniture",
    "chair": "furniture",
    "couch": "furniture",
    "bed": "furniture",
    "dining table": "furniture",
    "tv": "screen",
    "laptop": "computer",
    "mouse": "computer",
    "keyboard": "computer",
    "cell phone": "phone",
    "book": "book",
    "clock": "clock",
    "vase": "decoration",
    "scissors": "tool",
    "teddy bear": "toy",
    "toothbrush": "personal-item",
}


def _require_sidecar_token(
    token: Annotated[str | None, Header(alias=SIDECAR_TOKEN_HEADER)] = None,
) -> None:
    """只接受后端持有的侧车共享密钥。"""
    if not SIDECAR_SECRET:
        raise HTTPException(status_code=503, detail="AI sidecar authentication is not configured")
    if token is None or not hmac.compare_digest(token, SIDECAR_SECRET):
        raise HTTPException(status_code=401, detail="Unauthorized")


async def _read_bounded_image(image: UploadFile) -> bytes:
    """分块读取上传图片，并同时限制编码尺寸与解码像素。"""
    content_length = image.headers.get("content-length")
    if content_length is not None:
        try:
            if int(content_length) > MAX_IMAGE_BYTES:
                raise HTTPException(status_code=413, detail="Image exceeds size limit")
        except ValueError as exception:
            raise HTTPException(status_code=400, detail="Invalid content length") from exception

    chunks = bytearray()
    while True:
        chunk = await image.read(UPLOAD_READ_CHUNK_SIZE)
        if not chunk:
            break
        if len(chunks) + len(chunk) > MAX_IMAGE_BYTES:
            raise HTTPException(status_code=413, detail="Image exceeds size limit")
        chunks.extend(chunk)
    if not chunks:
        raise HTTPException(status_code=400, detail="Image is empty")

    try:
        from PIL import Image

        with Image.open(io.BytesIO(chunks)) as decoded:
            width, height = decoded.size
            if (
                width <= 0
                or height <= 0
                or width > MAX_IMAGE_WIDTH
                or height > MAX_IMAGE_HEIGHT
                or width * height > MAX_IMAGE_PIXELS
            ):
                raise HTTPException(status_code=413, detail="Image dimensions exceed limit")
            decoded.verify()
    except HTTPException:
        raise
    except Exception as exception:
        raise HTTPException(status_code=400, detail="Unable to decode image") from exception
    return bytes(chunks)


def _sha256(path: Path) -> str:
    """计算模型文件的 SHA-256 摘要。"""
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _copy_with_deadline(source, output, deadline: float) -> None:
    """在总耗时截止时间内分块复制模型响应。"""
    while True:
        if time.monotonic() >= deadline:
            raise TimeoutError("场景分类模型下载超过总耗时限制")
        chunk = source.read(MODEL_DOWNLOAD_CHUNK_SIZE)
        if not chunk:
            return
        output.write(chunk)


def _ensure_model_file(url: str, target: Path, expected_sha256: str) -> None:
    """下载并校验模型文件，完整文件通过原子替换进入缓存。"""
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.is_file() and _sha256(target) == expected_sha256:
        return

    temporary = target.with_suffix(f"{target.suffix}.part")
    temporary.unlink(missing_ok=True)
    logger.info("正在下载场景分类模型: target=%s", target)
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "OmniNest-AI-Sidecar/1.0"},
    )
    last_error = None
    for attempt in range(1, MODEL_DOWNLOAD_ATTEMPTS + 1):
        try:
            deadline = time.monotonic() + MODEL_DOWNLOAD_TIMEOUT_SECONDS
            with urllib.request.urlopen(
                request,
                timeout=MODEL_DOWNLOAD_TIMEOUT_SECONDS,
            ) as response:
                with temporary.open("wb") as output:
                    _copy_with_deadline(response, output, deadline)
            actual_sha256 = _sha256(temporary)
            if actual_sha256 != expected_sha256:
                raise RuntimeError(
                    "Places365 模型摘要不匹配: "
                    f"expected={expected_sha256}, actual={actual_sha256}"
                )
            temporary.replace(target)
            return
        except Exception as exception:
            last_error = exception
            temporary.unlink(missing_ok=True)
            logger.warning(
                "场景分类模型下载失败: attempt=%s/%s, error=%s",
                attempt,
                MODEL_DOWNLOAD_ATTEMPTS,
                exception,
            )
            if attempt < MODEL_DOWNLOAD_ATTEMPTS:
                time.sleep(2**attempt)
    raise RuntimeError("Places365 模型下载重试耗尽") from last_error


def _load_scene_model_places365():
    """从持久化缓存加载 Places365 场景分类模型。"""
    import torch
    from torchvision import models

    model_home = Path(os.environ.get("PLACES365_HOME", "/app/models/places365"))
    weights_path = model_home / "resnet50_places365.pth"
    _ensure_model_file(
        PLACES365_MODEL_URL,
        weights_path,
        PLACES365_MODEL_SHA256,
    )

    model = models.resnet50(num_classes=365)
    checkpoint = torch.load(weights_path, map_location="cpu", weights_only=False)
    state_dict = checkpoint.get("state_dict", checkpoint)
    normalized_state = {
        key.removeprefix("module."): value for key, value in state_dict.items()
    }
    model.load_state_dict(normalized_state)
    model.eval()

    # 后端持有类别目录，侧车只返回稳定的 Places365 索引。
    labels = [str(index) for index in range(365)]
    logger.info("Places365 场景分类模型加载完成")
    return model, labels


def _load_object_detector_coco():
    """加载轻量 COCO 主体检测模型。"""
    from torchvision import models

    weights = models.detection.SSDLite320_MobileNet_V3_Large_Weights.DEFAULT
    model = models.detection.ssdlite320_mobilenet_v3_large(weights=weights)
    model.eval()
    logger.info("COCO 主体检测模型加载完成")
    return model, weights.meta["categories"]


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理：启动时加载模型，关闭时释放资源。"""
    global face_app, scene_model, scene_labels
    global object_detector, object_detector_labels
    logger.info("正在加载图像分析模型...")

    # 人脸检测只加载检测和识别模块，避免占用无关模型内存。
    try:
        from insightface.app import FaceAnalysis

        insightface_root = os.environ.get(
            "INSIGHTFACE_ROOT",
            "/app/models/insightface",
        )
        face_app = FaceAnalysis(
            name="buffalo_l",
            root=insightface_root,
            allowed_modules=["detection", "recognition"],
            providers=["CPUExecutionProvider"],
        )
        face_app.prepare(ctx_id=-1, det_size=(640, 640))
        logger.info("InsightFace 人脸检测模型加载完成")
    except Exception as exception:
        logger.warning("InsightFace 加载失败，人脸检测功能不可用: %s", exception)

    # 场景和主体使用不同模型，禁止把场景分类结果当作主体标签。
    try:
        scene_model, scene_labels = _load_scene_model_places365()
    except Exception:
        logger.exception("Places365 场景分类模型加载失败")
    try:
        object_detector, object_detector_labels = _load_object_detector_coco()
    except Exception:
        logger.exception("COCO 主体检测模型加载失败")

    yield

    # 清理资源
    face_app = None
    scene_model = None
    scene_labels = None
    object_detector = None
    object_detector_labels = None
    logger.info("图像分析模型已释放")


app = FastAPI(
    title="OmniNest Image Analysis Sidecar",
    description="照片图像分析服务：主体检测、场景分类、人脸检测和人脸聚类",
    version="2.0.0",
    lifespan=lifespan,
)


# ─── 数据模型 ───


class FaceDetection(BaseModel):
    bbox_x: int
    bbox_y: int
    bbox_w: int
    bbox_h: int
    embedding: list[float]


class SceneLabel(BaseModel):
    name: str
    confidence: float


class SceneClassification(BaseModel):
    labels: list[SceneLabel]


class BoundingBox(BaseModel):
    x: float
    y: float
    width: float
    height: float


class ContentObservation(BaseModel):
    namespace: str
    code: str
    confidence: float
    source: str
    boxes: list[BoundingBox] = Field(default_factory=list)


class ContentAnalysis(BaseModel):
    schema_version: int = Field(alias="schemaVersion")
    pipeline_version: str = Field(alias="pipelineVersion")
    observations: list[ContentObservation]

    model_config = {"populate_by_name": True}


class ClusterRequest(BaseModel):
    embeddings: list[list[float]] = Field(max_length=MAX_CLUSTER_FACES)


def _analyze_content_sync(contents: bytes) -> ContentAnalysis:
    """在线程池内完成主体检测和场景分类，并保持命名空间隔离。"""
    import torch
    from PIL import Image
    from torchvision import transforms

    preprocess = transforms.Compose(
        [
            transforms.Resize(256),
            transforms.CenterCrop(224),
            transforms.ToTensor(),
            transforms.Normalize(
                mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]
            ),
        ]
    )
    img = Image.open(io.BytesIO(contents)).convert("RGB")
    input_tensor = preprocess(img).unsqueeze(0)
    observations: list[ContentObservation] = []

    if scene_model is not None and scene_labels is not None:
        with torch.no_grad():
            scene_output = scene_model(input_tensor)
            scene_probabilities = torch.nn.functional.softmax(scene_output[0], dim=0)
        # Places365 是单标签场景分类器，只保留最高置信度场景，避免把候选排序误当成多场景事实。
        top_probabilities, top_indexes = torch.topk(scene_probabilities, 1)
        for probability, index in zip(top_probabilities, top_indexes):
            confidence = float(probability.item())
            if confidence < SCENE_MIN_CONFIDENCE:
                continue
            observations.append(
                ContentObservation(
                    namespace="SCENE",
                    code=f"places365_{index.item()}",
                    confidence=round(confidence, 4),
                    source="places365",
                )
            )

    if object_detector is not None and object_detector_labels is not None:
        detector_input = transforms.ToTensor()(img)
        with torch.no_grad():
            detection = object_detector([detector_input])[0]
        image_width, image_height = img.size
        for class_index, score, box in zip(
                detection["labels"], detection["scores"], detection["boxes"]
        ):
            confidence = float(score.item())
            label_name = object_detector_labels[class_index.item()].lower()
            subject_code = COCO_SUBJECT_CODES.get(label_name)
            if subject_code is None:
                continue
            threshold = SUBJECT_MIN_CONFIDENCE
            if confidence < threshold:
                continue
            left, top, right, bottom = [float(value) for value in box.tolist()]
            box_width = max(0.0, right - left)
            box_height = max(0.0, bottom - top)
            area_ratio = box_width * box_height / (image_width * image_height)
            if area_ratio < SUBJECT_MIN_AREA_RATIO:
                continue
            observations.append(
                ContentObservation(
                    namespace="SUBJECT",
                    code=subject_code,
                    confidence=round(confidence, 4),
                    source="coco-ssdlite",
                    boxes=[
                        BoundingBox(
                            x=round(max(0.0, left / image_width), 6),
                            y=round(max(0.0, top / image_height), 6),
                            width=round(min(1.0, box_width / image_width), 6),
                            height=round(min(1.0, box_height / image_height), 6),
                        )
                    ],
                )
            )

    observations.sort(key=lambda observation: observation.confidence, reverse=True)
    return ContentAnalysis(
        schemaVersion=CONTENT_ANALYSIS_SCHEMA_VERSION,
        pipelineVersion=CONTENT_ANALYSIS_PIPELINE_VERSION,
        observations=observations,
    )


def _legacy_scene_labels(content: ContentAnalysis) -> list[SceneLabel]:
    """将结构化结果转换为旧场景接口，不返回主体检测结果。"""
    labels = [
        SceneLabel(name=observation.code, confidence=observation.confidence)
        for observation in content.observations
        if observation.namespace == "SCENE"
    ]
    labels.sort(key=lambda label: label.confidence, reverse=True)
    return labels


# ─── 人脸检测 ───


@app.post(
    "/detect-faces",
    response_model=list[FaceDetection],
    dependencies=[Depends(_require_sidecar_token)],
)
async def detect_faces(image: UploadFile = File(...)):
    """检测图片中的人脸，返回位置和 512 维嵌入向量。"""
    if face_app is None:
        raise HTTPException(status_code=503, detail="人脸检测模型未加载")

    try:
        import cv2

        contents = await _read_bounded_image(image)
        nparr = np.frombuffer(contents, np.uint8)
        async with inference_slots:
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

            if img is None:
                raise HTTPException(status_code=400, detail="Unable to decode image")

            faces = await to_thread(face_app.get, img)
        results = []

        for face in faces:
            bbox = face.bbox.astype(int)
            results.append(
                FaceDetection(
                    bbox_x=int(bbox[0]),
                    bbox_y=int(bbox[1]),
                    bbox_w=int(bbox[2] - bbox[0]),
                    bbox_h=int(bbox[3] - bbox[1]),
                    embedding=face.embedding.tolist(),
                )
            )

        logger.info(f"检测到 {len(results)} 张人脸")
        return results

    except HTTPException:
        raise
    except Exception:
        logger.exception("人脸检测失败")
        raise HTTPException(status_code=500, detail="Face detection failed") from None


# ─── 图像分析 ───


@app.post(
    "/analyze-content",
    response_model=ContentAnalysis,
    dependencies=[Depends(_require_sidecar_token)],
)
async def analyze_content(image: UploadFile = File(...)):
    """返回按主体和场景命名空间隔离的图像分析结果。"""
    if (scene_model is None or scene_labels is None) and (
        object_detector is None or object_detector_labels is None
    ):
        raise HTTPException(status_code=503, detail="图像分析模型未加载")

    try:
        contents = await _read_bounded_image(image)
        async with inference_slots:
            result = await to_thread(_analyze_content_sync, contents)
        logger.info(
            "图像分析完成: observationCount=%s, pipelineVersion=%s",
            len(result.observations),
            result.pipeline_version,
        )
        return result
    except HTTPException:
        raise
    except Exception:
        logger.exception("图像分析失败")
        raise HTTPException(status_code=500, detail="Image analysis failed") from None


# ─── 兼容接口 ───


@app.post(
    "/classify-scene",
    response_model=SceneClassification,
    dependencies=[Depends(_require_sidecar_token)],
)
async def classify_scene(image: UploadFile = File(...)):
    """兼容旧客户端，仅返回场景观察项，不返回主体检测结果。"""
    if scene_model is None or scene_labels is None:
        raise HTTPException(status_code=503, detail="场景分类模型未加载")

    try:
        contents = await _read_bounded_image(image)
        async with inference_slots:
            labels = _legacy_scene_labels(await to_thread(_analyze_content_sync, contents))
        if not labels:
            raise HTTPException(status_code=503, detail="No scene classification result")
        logger.info(
            "图片分类完成: top1=%s (%s)",
            labels[0].name,
            labels[0].confidence,
        )
        return SceneClassification(labels=labels)

    except HTTPException:
        raise
    except Exception:
        logger.exception("兼容场景分类失败")
        raise HTTPException(status_code=500, detail="Scene classification failed") from None


# ─── 人脸聚类 ───


@app.post(
    "/cluster-faces",
    response_model=list[int],
    dependencies=[Depends(_require_sidecar_token)],
)
async def cluster_faces(request: ClusterRequest):
    """对人脸嵌入向量进行聚类，返回每个向量的聚类 ID。"""
    try:
        from sklearn.cluster import DBSCAN
        from sklearn.preprocessing import normalize

        if any(len(embedding) != FACE_EMBEDDING_DIMENSION for embedding in request.embeddings):
            raise HTTPException(status_code=422, detail="Invalid face embedding dimension")

        embeddings = np.asarray(request.embeddings, dtype=np.float32)
        if not np.isfinite(embeddings).all():
            raise HTTPException(status_code=422, detail="Face embeddings must be finite")
        if len(embeddings) == 0:
            return []

        if len(embeddings) == 1:
            return [0]

        # L2 归一化（InsightFace 输出已归一化，但确保安全）
        embeddings = normalize(embeddings)

        # DBSCAN 聚类
        # eps=0.6 是人脸聚类的经验值，余弦距离阈值
        async with inference_slots:
            clusterer = DBSCAN(eps=0.6, min_samples=2, metric="cosine")
            clustering = await to_thread(clusterer.fit, embeddings)

        # 将 -1（噪声点）转为独立聚类 ID
        labels = clustering.labels_
        max_label = labels.max()
        result = []
        for label in labels:
            if label == -1:
                max_label += 1
                result.append(int(max_label))
            else:
                result.append(int(label))

        n_clusters = len(set(result))
        logger.info(f"人脸聚类完成: {len(embeddings)} 个向量 → {n_clusters} 个聚类")
        return result

    except HTTPException:
        raise
    except Exception:
        logger.exception("人脸聚类失败")
        raise HTTPException(status_code=500, detail="Face clustering failed") from None


# ─── 健康检查 ───


@app.get("/health")
async def health():
    """健康检查端点。"""
    content_analysis_ready = scene_model is not None or object_detector is not None
    return {
        "status": "ok",
        "face_detection": face_app is not None,
        "content_analysis": content_analysis_ready,
        "face_clustering": True,
    }


@app.get("/ready")
async def ready():
    """就绪检查端点，模型未完整加载时返回 503。"""
    content_analysis_ready = scene_model is not None or object_detector is not None
    readiness = {
        "face_detection": face_app is not None,
        "content_analysis": content_analysis_ready,
        "face_clustering": True,
    }
    if not all(readiness.values()):
        raise HTTPException(status_code=503, detail=readiness)
    return {"status": "ready", **readiness}
