package com.omninest.modules.file.service;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.modules.file.domain.FileNode;
import com.omninest.modules.file.domain.MediaContentPurpose;
import com.omninest.modules.file.dto.FileContentResource;
import com.omninest.modules.file.dto.FileContentStream;
import com.omninest.modules.file.dto.FileDownloadUrlDto;
import com.omninest.modules.file.dto.FileProcessInput;
import com.omninest.modules.file.repository.FileNodeRepository;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * 文件内容提供者解析与统一访问服务。
 *
 * @author OmniNest
 */
@Service
@RequiredArgsConstructor
public class FileContentAccessService {

    private final List<FileContentProvider> providers;
    private final FileNodeRepository fileNodeRepository;
    private final LocalContentAccessTokenService tokenService;

    /**
     * 打开文件内容流。
     *
     * @param node 已完成权限校验的文件节点
     * @return 文件内容流
     */
    public FileContentStream open(FileNode node) {
        return requireProvider(node).open(node);
    }

    /**
     * 创建文件短期下载地址。
     *
     * @param node 已完成权限校验的文件节点
     * @return 下载地址
     */
    public FileDownloadUrlDto createDownloadUrl(FileNode node) {
        return requireProvider(node).createDownloadUrl(node);
    }

    /**
     * 创建媒体进程输入。
     *
     * @param node 已完成权限校验的文件节点
     * @return 进程输入
     */
    public FileProcessInput createProcessInput(FileNode node) {
        return requireProvider(node).createProcessInput(node);
    }

    /**
     * 通过短期令牌打开本地 Range 资源。
     *
     * @param token 短期令牌
     * @return 本地文件资源
     */
    public FileContentResource openPublicLocalResource(String token) {
        LocalContentAccessTokenService.AccessGrant grant = tokenService.requireGrant(token);
        FileNode node = fileNodeRepository.findByIdAndOwnerUserIdAndDeletedFalse(
                        grant.fileId(),
                        grant.ownerUserId()
                )
                .orElseThrow(() -> new BusinessException(ErrorCode.FILE_NOT_FOUND, "文件不存在"));
        FileContentProvider provider = requireProvider(node);
        if (!"LOCAL_FILESYSTEM".equals(provider.providerType())) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "访问令牌不适用于当前内容提供者");
        }
        return provider.findRangeResource(node)
                .orElseThrow(() -> new BusinessException(ErrorCode.FILE_NOT_FOUND, "文件资源不存在"));
    }

    /**
     * 为已在业务模块完成授权的媒体请求打开 Range 资源。
     *
     * <p>该方法不暴露为 File Controller，调用方必须先校验媒体业务权限。File 模块仍负责节点状态、Provider
     * 和真实路径安全。</p>
     *
     * @param fileId 文件节点 ID
     * @param purpose 媒体读取用途
     * @return Range 资源
     */
    public FileContentResource openAuthorizedMediaResource(UUID fileId, MediaContentPurpose purpose) {
        if (purpose != MediaContentPurpose.MEDIA_PLAYBACK) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "媒体 Range 读取用途无效");
        }
        FileNode node = fileNodeRepository.findByIdAndDeletedFalse(fileId)
                .orElseThrow(() -> new BusinessException(ErrorCode.FILE_NOT_FOUND, "文件不存在"));
        return requireProvider(node).findRangeResource(node)
                .orElseThrow(() -> new BusinessException(ErrorCode.FILE_NOT_FOUND, "当前内容提供者不支持 Range 读取"));
    }

    /**
     * 为已在业务模块完成授权的媒体请求打开顺序内容流。
     *
     * <p>该内部能力主要用于 MinIO 派生海报、背景图和字幕；它不接受路径或对象键，也不暴露为
     * File Controller。</p>
     *
     * @param fileId 文件节点 ID
     * @param purpose 媒体读取用途
     * @return 受控内容流
     */
    public FileContentStream openAuthorizedMediaStream(UUID fileId, MediaContentPurpose purpose) {
        if (purpose == null || purpose == MediaContentPurpose.MEDIA_PLAYBACK) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "媒体顺序读取用途无效");
        }
        FileNode node = fileNodeRepository.findByIdAndDeletedFalse(fileId)
                .orElseThrow(() -> new BusinessException(ErrorCode.FILE_NOT_FOUND, "文件不存在"));
        return requireProvider(node).open(node);
    }

    private FileContentProvider requireProvider(FileNode node) {
        return providers.stream()
                .filter(provider -> provider.supports(node))
                .findFirst()
                .orElseThrow(() -> new BusinessException(ErrorCode.FILE_NOT_FOUND, "文件节点没有可读取内容"));
    }
}
