package com.omninest.modules.file.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.omninest.common.messaging.DomainEventPublisher;
import com.omninest.common.messaging.QueueNames;
import com.omninest.modules.file.domain.FileNode;
import com.omninest.modules.file.domain.NodeType;
import com.omninest.modules.file.event.FileNodesRestoredEvent;
import com.omninest.modules.file.event.FileRestoredEvent;
import com.omninest.modules.file.repository.FileNodeRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;

/**
 * 文件恢复任务发布服务测试。
 *
 * @author OmniNest
 */
@ExtendWith(MockitoExtension.class)
class FileRestoreTaskPublisherTest {
    @Mock
    private FileNodeRepository fileNodeRepository;
    @Mock
    private DomainEventPublisher domainEventPublisher;
    @InjectMocks
    private FileRestoreTaskPublisher publisher;

    @Test
    void transactionalEventListenerIsAcceptedDuringContextInitialization() {
        try (AnnotationConfigApplicationContext context = new AnnotationConfigApplicationContext()) {
            context.registerBean(FileNodeRepository.class, () -> fileNodeRepository);
            context.registerBean(DomainEventPublisher.class, () -> domainEventPublisher);
            context.register(FileRestoreTaskPublisher.class);

            context.refresh();

            assertThat(context.getBean(FileRestoreTaskPublisher.class)).isNotNull();
        }
    }

    @Test
    void restoredImagePublishesOnlyRestoreIndexTask() {
        UUID ownerUserId = UUID.randomUUID();
        UUID fileNodeId = UUID.randomUUID();
        UUID fileObjectId = UUID.randomUUID();
        FileNode node = new FileNode();
        node.setId(fileNodeId);
        node.setOwnerUserId(ownerUserId);
        node.setNodeType(NodeType.FILE.getValue());
        node.setName("photo.jpg");
        node.setMimeType("image/jpeg");
        node.setSizeBytes(2048);
        node.setCurrentObjectId(fileObjectId);
        when(fileNodeRepository.findAllById(List.of(fileNodeId))).thenReturn(List.of(node));

        publisher.publishRestoredFiles(
                new FileNodesRestoredEvent(ownerUserId, List.of(fileNodeId), Instant.now())
        );

        verify(domainEventPublisher).publishTask(
                eq(QueueNames.FILE_RESTORE_INDEX_ROUTING_KEY),
                argThat(event -> matchesFileEvent(event, fileNodeId, ownerUserId))
        );
    }

    private boolean matchesFileEvent(Object event, UUID fileNodeId, UUID ownerUserId) {
        return event instanceof FileRestoredEvent restoredEvent
                && fileNodeId.equals(restoredEvent.fileNodeId())
                && ownerUserId.equals(restoredEvent.ownerUserId());
    }
}
