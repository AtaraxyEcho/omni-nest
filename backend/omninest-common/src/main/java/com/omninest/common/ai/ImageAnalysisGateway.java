package com.omninest.common.ai;

import java.nio.file.Path;
import java.util.List;

/**
 * 提供图片内容分析、人脸检测和人脸聚类能力。
 *
 * @author OmniNest
 */
public interface ImageAnalysisGateway {

    /**
     * 返回允许处理的最大图片字节数。
     *
     * @return 最大图片字节数
     */
    long maxImageBytes();

    /**
     * 检测图片中的人脸。
     *
     * @param imagePath 图片文件路径
     * @param endpoint 分析服务端点
     * @param timeoutSeconds 请求超时秒数
     * @return 人脸检测结果
     */
    List<FaceDetection> detectFaces(Path imagePath, String endpoint, int timeoutSeconds);

    /**
     * 对图片执行结构化内容分析。
     *
     * @param imagePath 图片文件路径
     * @param endpoint 分析服务端点
     * @param timeoutSeconds 请求超时秒数
     * @return 结构化分析结果
     */
    ContentAnalysis analyzeContent(Path imagePath, String endpoint, int timeoutSeconds);

    /**
     * 对图片进行场景分类。
     *
     * @param imagePath 图片文件路径
     * @param endpoint 分析服务端点
     * @param timeoutSeconds 请求超时秒数
     * @return 场景分类结果
     */
    SceneClassification classifyScene(Path imagePath, String endpoint, int timeoutSeconds);

    /**
     * 对人脸嵌入向量进行聚类。
     *
     * @param embeddings 人脸嵌入向量
     * @param endpoint 分析服务端点
     * @param timeoutSeconds 请求超时秒数
     * @return 每个向量对应的聚类 ID
     */
    List<Integer> clusterFaces(List<float[]> embeddings, String endpoint, int timeoutSeconds);

    /**
     * 人脸检测结果。
     *
     * @param bboxX 边界框横坐标
     * @param bboxY 边界框纵坐标
     * @param bboxW 边界框宽度
     * @param bboxH 边界框高度
     * @param embedding 人脸嵌入向量
     */
    record FaceDetection(int bboxX, int bboxY, int bboxW, int bboxH, float[] embedding) {
    }

    /**
     * 结构化图像分析结果。
     *
     * @param schemaVersion 响应契约版本
     * @param pipelineVersion 分析流水线版本
     * @param observations 分析观察项
     */
    record ContentAnalysis(int schemaVersion, String pipelineVersion,
                           List<ContentObservation> observations) {
    }

    /**
     * 图像内容观察项。不同命名空间之间禁止通过字符串规则相互推导。
     *
     * @param namespace 命名空间，例如 SUBJECT、SCENE、STYLE
     * @param code 稳定标签编码
     * @param confidence 置信度
     * @param source 产生观察项的模型或检测器
     * @param boxes 归一化边界框
     */
    record ContentObservation(String namespace, String code, float confidence,
                              String source, List<BoundingBox> boxes) {
    }

    /**
     * 归一化图像边界框。
     *
     * @param x 左上角横坐标比例
     * @param y 左上角纵坐标比例
     * @param width 宽度比例
     * @param height 高度比例
     */
    record BoundingBox(float x, float y, float width, float height) {
    }

    /**
     * 旧版场景分类结果，供已有兼容调用使用。
     *
     * @param labels 场景标签
     */
    record SceneClassification(List<SceneLabel> labels) {
    }

    /**
     * 场景标签。
     *
     * @param name 标签名称
     * @param confidence 置信度
     */
    record SceneLabel(String name, float confidence) {
    }
}
