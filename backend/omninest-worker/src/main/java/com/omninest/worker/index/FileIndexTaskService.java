package com.omninest.worker.index;

import com.omninest.worker.runtime.ConditionalOnWorkerRuntime;

import com.omninest.modules.file.domain.SpaceType;
import com.omninest.modules.file.dto.FileDescriptor;
import com.omninest.modules.file.event.FileUploadedEvent;
import com.omninest.modules.file.event.FileRestoredEvent;
import com.omninest.modules.file.service.FileLifecycleGuard;
import com.omninest.modules.search.service.FileSearchIndexService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * 文件索引任务服务。
 *
 * @author OmniNest
 */
@Service
@RequiredArgsConstructor
@ConditionalOnWorkerRuntime
public class FileIndexTaskService {
    private final FileSearchIndexService fileSearchIndexService;
    private final FileLifecycleGuard fileLifecycleGuard;

    /**
     * 写入文件索引。
     *
     * @param event 文件上传事件
     */
    public void process(FileUploadedEvent event) {
        FileDescriptor fileDescriptor = fileLifecycleGuard.requireOwnedWritable(
                event.ownerUserId(),
                event.fileNodeId()
        );
        SpaceType spaceType = fileDescriptor.spaceType();
        fileSearchIndexService.indexFile(
                event.fileNodeId(),
                event.ownerUserId(),
                event.fileName(),
                null,
                spaceType.getValue()
        );
    }

    /**
     * 恢复文件的 Lucene 索引，不重复触发媒体自动导入和派生任务。
     *
     * @param event 文件恢复事件
     */
    public void processRestored(FileRestoredEvent event) {
        FileDescriptor fileDescriptor = fileLifecycleGuard.requireOwnedWritable(
                event.ownerUserId(),
                event.fileNodeId()
        );
        fileSearchIndexService.indexFile(
                event.fileNodeId(),
                event.ownerUserId(),
                event.fileName(),
                null,
                fileDescriptor.spaceType().getValue()
        );
    }

}
