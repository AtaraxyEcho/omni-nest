package com.omninest.modules.file.service;

import com.omninest.modules.file.domain.FileNode;
import com.omninest.modules.file.event.FileNodesRestoredEvent;
import com.omninest.modules.file.repository.FileNodeRepository;
import com.omninest.modules.search.service.FileSearchIndexService;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class FileIndexEventListener {
    private final FileSearchIndexService fileSearchIndexService;
    private final FileNodeRepository fileNodeRepository;

    @EventListener
    @Transactional(readOnly = true)
    public void handleFileNodesRestored(FileNodesRestoredEvent event) {
        if (event.fileNodeIds() == null || event.fileNodeIds().isEmpty()) {
            return;
        }
        List<FileNode> nodes = fileNodeRepository.findAllById(event.fileNodeIds());
        List<FileSearchIndexService.IndexDocumentInput> inputs = nodes.stream()
                .filter(node -> !node.isDeleted())
                .map(node -> new FileSearchIndexService.IndexDocumentInput(
                        node.getId(),
                        node.getName(),
                        null,
                        "PERSONAL"
                ))
                .toList();
        if (!inputs.isEmpty()) {
            fileSearchIndexService.indexFiles(event.ownerUserId(), inputs);
        }
        log.info("文件恢复后批量重新索引: count={}", inputs.size());
    }
}
