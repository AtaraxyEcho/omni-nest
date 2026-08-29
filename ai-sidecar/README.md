# OmniNest AI Sidecar

该容器为照片模块提供人脸检测、人脸聚类和场景分类接口。

## 模型缓存

Compose 将 `/app/models` 挂载到 `omninest-ai-models` 命名卷。首次启动会下载模型，后续重建容器继续使用缓存：

- InsightFace `buffalo_l`：由 InsightFace 下载到 `/app/models/insightface`。
- Places365 ResNet50：从 CSAIL 官方地址下载到 `/app/models/places365`，写入缓存前校验固定 SHA-256。官方模型端点仅提供 HTTP，摘要校验用于阻止传输损坏或内容替换进入缓存。
- ImageNet ResNet50：仅在 Places365 不可用时下载到 `/app/models/torch` 作为降级能力。

首次启动需要下载数百 MB 模型，Compose 就绪检查为此保留 15 分钟启动窗口。`/health` 只报告进程和模型状态，`/ready` 只有在人脸检测与场景分类模型均可用时返回 HTTP 200。

Places365 下载单次等待时间默认 30 秒，最多重试三次，可通过 `AI_MODEL_DOWNLOAD_TIMEOUT_SECONDS` 调整。下载失败时会回退到 ImageNet，避免外部模型站点不可用时阻塞整个环境启动。

## 环境变量

Compose 会注入 `OMNINEST_AI_SIDECAR_SECRET`；未设置时本地 Compose 使用开发默认值，生产环境必须替换。以下变量为可选调优项，未设置时使用程序默认值：

| 变量 | 默认值 | 作用 |
| --- | --- | --- |
| `MODEL_DOWNLOAD_TIMEOUT_SECONDS` | `30` | 模型单次下载等待时间 |
| `AI_MAX_IMAGE_BYTES` | `33554432` | 单张图片最大字节数 |
| `AI_MAX_IMAGE_WIDTH` | `30000` | 图片最大宽度 |
| `AI_MAX_IMAGE_HEIGHT` | `30000` | 图片最大高度 |
| `AI_MAX_IMAGE_PIXELS` | `100000000` | 图片最大像素数 |
| `AI_MAX_CONCURRENT_INFERENCES` | `2` | 并行推理数量 |
| `IMAGE_ANALYSIS_SCENE_MIN_CONFIDENCE` | `0.35` | 场景候选最低置信度 |
| `IMAGE_ANALYSIS_SUBJECT_MIN_CONFIDENCE` | `0.65` | 主体候选最低置信度 |
| `IMAGE_ANALYSIS_SUBJECT_MIN_AREA_RATIO` | `0.01` | 主体最小面积比例 |

模型目录由容器固定为 `/app/models`，不要将宿主机绝对路径写入业务配置。

## 模型许可

Places365 模型采用 Creative Commons Attribution 许可。InsightFace 预训练模型的使用受其官方模型许可约束，部署前需要根据实际用途确认授权范围。
