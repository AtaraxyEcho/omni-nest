package com.omninest.modules.file.service;

import com.omninest.modules.file.domain.FileNode;
import com.omninest.modules.file.domain.ShareLink;
import com.omninest.modules.file.event.FileNodesDeletedEvent;
import com.omninest.modules.file.repository.FileAccessRecordRepository;
import com.omninest.modules.file.repository.FileContentRefRepository;
import com.omninest.modules.file.repository.FileFavoriteRepository;
import com.omninest.modules.file.repository.FileNodeRepository;
import com.omninest.modules.file.repository.FileShareRecipientRepository;
import com.omninest.modules.file.repository.ShareLinkRepository;
import com.omninest.modules.file.domain.SpaceType;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class FileNodeRelationCleanupService {
    private final FileAccessRecordRepository accessRecordRepository;
    private final FileFavoriteRepository favoriteRepository;
    private final ShareLinkRepository shareLinkRepository;
    private final FileShareRecipientRepository shareRecipientRepository;
    private final FileNodeRepository fileNodeRepository;
    private final FileContentRefRepository contentRefRepository;

    @EventListener
    @Transactional(rollbackFor = Exception.class)
    public void handleFileNodesDeleted(FileNodesDeletedEvent event) {
        if (event.fileNodeIds() == null || event.fileNodeIds().isEmpty()) {
            return;
        }
        List<UUID> fileNodeIds = List.copyOf(event.fileNodeIds());
        contentRefRepository.deleteByFileNodeIdIn(fileNodeIds);

        // 判断是否包含共享空间文件
        boolean hasSharedFiles = fileNodeRepository.findAllById(fileNodeIds).stream()
                .anyMatch(node -> node.getSpaceType() == SpaceType.SHARED);

        if (hasSharedFiles) {
            // 共享空间文件：清理所有用户的访问记录和收藏
            accessRecordRepository.deleteByFileNode_IdIn(fileNodeIds);
            favoriteRepository.deleteByFileNode_IdIn(fileNodeIds);
        } else {
            // 个人空间文件：只清理所有者的记录
            accessRecordRepository.deleteByOwnerUserIdAndFileNode_IdIn(event.ownerUserId(), fileNodeIds);
            favoriteRepository.deleteByOwnerUserIdAndFileNode_IdIn(event.ownerUserId(), fileNodeIds);
        }

        // 分享链接始终按 ownerUserId 清理
        List<ShareLink> shares =
                shareLinkRepository.findByOwnerUserIdAndResourceIdIn(event.ownerUserId(), fileNodeIds);
        if (!shares.isEmpty()) {
            List<UUID> shareLinkIds = shares.stream().map(ShareLink::getId).toList();
            shareRecipientRepository.deleteByShareLink_IdIn(shareLinkIds);
            shareLinkRepository.deleteAll(shares);
        }
    }
}
