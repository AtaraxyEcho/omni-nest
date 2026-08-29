package com.omninest.common.download;

import java.nio.file.Path;
import java.time.Duration;
import java.util.List;
import java.util.Map;

/**
 * 定义文件业务使用的离线下载运行能力。
 *
 * @author OmniNest
 */
public interface OfflineDownloadGateway {

    /**
     * 获取离线下载文件根目录。
     *
     * @return 规范化前的下载根目录
     */
    Path downloadRoot();

    /**
     * 获取任务状态轮询间隔。
     *
     * @return 轮询间隔秒数
     */
    int pollIntervalSeconds();

    /**
     * 获取无进度空闲超时阈值，超过该时长无进度变化判定失败。
     *
     * @return 空闲超时时长
     */
    Duration idleTimeout();

    /**
     * 提交 URI 下载任务。
     *
     * @param uri     下载地址
     * @param options 下载选项
     * @return 下载任务标识
     */
    String submitUri(String uri, Map<String, Object> options);

    /**
     * 提交种子文件下载任务。
     *
     * @param torrentBytes 种子文件内容
     * @param options      下载选项
     * @return 下载任务标识
     */
    String submitTorrent(byte[] torrentBytes, Map<String, Object> options);

    /**
     * 查询下载任务状态。
     *
     * @param taskId 下载任务标识
     * @return 下载任务快照
     */
    TaskSnapshot queryStatus(String taskId);

    /**
     * 强制移除下载任务。
     *
     * @param taskId 下载任务标识
     */
    void remove(String taskId);

    /**
     * 下载结果文件。
     *
     * @param path     文件绝对路径
     * @param selected 是否选中下载
     * @author OmniNest
     */
    record DownloadedFile(String path, boolean selected) {
    }

    /**
     * 下载任务快照。
     *
     * @param state          任务状态
     * @param totalBytes     总字节数
     * @param completedBytes 已完成字节数
     * @param speedBytes     每秒下载字节数
     * @param files          下载结果文件
     * @param displayName    下载内容显示名称
     * @param errorMessage   错误摘要
     * @author OmniNest
     */
    record TaskSnapshot(
            String state,
            long totalBytes,
            long completedBytes,
            long speedBytes,
            List<DownloadedFile> files,
            String displayName,
            String errorMessage
    ) {

        /**
         * 创建不可变下载任务快照。
         */
        public TaskSnapshot {
            files = files == null ? List.of() : List.copyOf(files);
        }
    }
}
