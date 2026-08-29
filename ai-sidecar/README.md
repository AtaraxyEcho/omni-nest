# OmniNest AI Sidecar

该容器为照片模块提供人脸检测、人脸嵌入和人脸聚类能力。当前镜像是人脸识别专用构建，仅使用 InsightFace `buffalo_l` 和 CPU 版 ONNX Runtime，不包含 PyTorch、torchvision、Places365 或 COCO 主体检测模型。

## API

除健康检查外的接口都需要 `X-OmniNest-Sidecar-Token` 请求头。

| 接口 | 用途 |
| --- | --- |
| `POST /detect-faces` | 检测人脸并返回边界框与 512 维嵌入向量 |
| `POST /cluster-faces` | 使用人脸嵌入进行聚类，返回逐向量聚类 ID |
| `POST /analyze-content` | 保留后端结构化分析契约；当前返回空 `observations`，不再生成场景或主体标签 |
| `POST /classify-scene` | 兼容旧客户端；当前校验图片后返回空 `labels` |
| `GET /health` | 返回进程和人脸识别能力状态 |
| `GET /ready` | 仅在人脸识别模型加载完成后返回 HTTP 200 |

`/detect-faces`、`/analyze-content` 和 `/classify-scene` 会限制上传字节数、尺寸和像素数。具体上限通过环境变量调整。

## 模型缓存

Compose 将 `/app/models` 挂载到 `omninest-ai-models` 卷。首次启动时 InsightFace 将 `buffalo_l` 模型写入 `/app/models/insightface`，后续重建容器复用该卷。镜像本身不再下载或缓存其他推理模型，因此不会产生 Places365、Torch 或 torchvision 的体积和启动开销。

模型首次加载可能需要一段时间，健康检查为此保留 10 分钟启动窗口。若模型下载或加载失败，`/ready` 返回 HTTP 503，容器不会被误报为可用。

## 环境变量

| 变量 | 默认值 | 作用 |
| --- | --- | --- |
| `OMNINEST_AI_SIDECAR_SECRET` | 空 | 侧车接口共享密钥；生产环境必须显式设置 |
| `INSIGHTFACE_ROOT` | `/app/models/insightface` | InsightFace 模型目录 |
| `AI_MAX_IMAGE_BYTES` | `33554432` | 单张图片最大字节数 |
| `AI_MAX_IMAGE_WIDTH` | `30000` | 图片最大宽度 |
| `AI_MAX_IMAGE_HEIGHT` | `30000` | 图片最大高度 |
| `AI_MAX_IMAGE_PIXELS` | `100000000` | 图片最大像素数 |
| `AI_MAX_CLUSTER_FACES` | `10000` | 单次聚类允许的人脸向量数 |
| `AI_FACE_EMBEDDING_DIMENSION` | `512` | 人脸嵌入维度校验值 |
| `AI_MAX_CONCURRENT_INFERENCES` | `2` | 并行推理槽位数 |
| `OMP_NUM_THREADS` | `2`（Compose） | ONNX Runtime CPU 线程数 |
| `IMAGE_ANALYSIS_PIPELINE_VERSION` | `face-recognition-v1` | 结构化兼容响应中的流水线版本 |

## 模型许可

InsightFace 代码和预训练模型分别受其上游项目及模型许可约束。部署前请根据实际用途核对 InsightFace、ONNX Runtime、OpenCV、NumPy、scikit-learn 等依赖的许可和再分发条件。
