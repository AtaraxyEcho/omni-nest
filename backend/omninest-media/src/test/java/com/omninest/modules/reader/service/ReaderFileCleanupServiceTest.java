package com.omninest.modules.reader.service;

import com.omninest.common.sync.SyncScope;
import com.omninest.modules.file.event.FileNodesSoftDeletedEvent;
import com.omninest.modules.file.service.PurgeContext;
import com.omninest.modules.media.service.MediaSyncEventService;
import com.omninest.modules.reader.domain.ReaderItem;
import com.omninest.modules.reader.domain.ReaderItemSource;
import com.omninest.modules.reader.repository.ReaderAnnotationRepository;
import com.omninest.modules.reader.repository.ReaderBookmarkRepository;
import com.omninest.modules.reader.repository.ReaderBookshelfRepository;
import com.omninest.modules.reader.repository.ReaderCatalogNodeRepository;
import com.omninest.modules.reader.repository.ReaderItemRepository;
import com.omninest.modules.reader.repository.ReaderItemSourceRepository;
import com.omninest.modules.reader.repository.ReaderNoteRepository;
import com.omninest.modules.reader.repository.ReaderPageAssetRepository;
import com.omninest.modules.reader.repository.ReaderPageRepository;
import com.omninest.modules.reader.repository.ReaderProgressRepository;
import com.omninest.modules.reader.repository.ReaderReadingSessionRepository;
import com.omninest.modules.reader.repository.ReaderTextChapterRepository;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

/**
 * 阅读文件关联数据清理服务测试。
 *
 * @author OmniNest
 */
class ReaderFileCleanupServiceTest {
    private static final UUID OWNER_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");
    private static final UUID FILE_NODE_ID = UUID.fromString("20000000-0000-0000-0000-000000000001");
    private static final UUID ITEM_ID = UUID.fromString("30000000-0000-0000-0000-000000000001");
    private static final UUID OTHER_OWNER_ID = UUID.fromString("10000000-0000-0000-0000-000000000002");

    private final ReaderItemRepository itemRepository = Mockito.mock(ReaderItemRepository.class);
    private final ReaderProgressRepository progressRepository = Mockito.mock(ReaderProgressRepository.class);
    private final ReaderItemSourceRepository itemSourceRepository = Mockito.mock(ReaderItemSourceRepository.class);
    private final ReaderPageAssetRepository pageAssetRepository = Mockito.mock(ReaderPageAssetRepository.class);
    private final ReaderPageRepository pageRepository = Mockito.mock(ReaderPageRepository.class);
    private final ReaderCatalogNodeRepository catalogRepository = Mockito.mock(ReaderCatalogNodeRepository.class);
    private final ReaderTextChapterRepository textChapterRepository = Mockito.mock(ReaderTextChapterRepository.class);
    private final ReaderBookmarkRepository bookmarkRepository = Mockito.mock(ReaderBookmarkRepository.class);
    private final ReaderAnnotationRepository annotationRepository = Mockito.mock(ReaderAnnotationRepository.class);
    private final ReaderNoteRepository noteRepository = Mockito.mock(ReaderNoteRepository.class);
    private final ReaderBookshelfRepository bookshelfRepository = Mockito.mock(ReaderBookshelfRepository.class);
    private final ReaderReadingSessionRepository readingSessionRepository =
            Mockito.mock(ReaderReadingSessionRepository.class);
    private final MediaSyncEventService syncEventService = Mockito.mock(MediaSyncEventService.class);
    private final ReaderFileCleanupService service = new ReaderFileCleanupService(
            itemRepository,
            itemSourceRepository,
            pageAssetRepository,
            pageRepository,
            catalogRepository,
            textChapterRepository,
            progressRepository,
            bookmarkRepository,
            annotationRepository,
            noteRepository,
            bookshelfRepository,
            readingSessionRepository,
            syncEventService
    );

    @Test
    void hardDeleteRemovesOwnedReaderRows() {
        ReaderItem item = item();
        Mockito.when(itemRepository.findByFileNodeIdIn(List.of(FILE_NODE_ID)))
                .thenReturn(List.of(item));
        Mockito.when(itemRepository.findAllById(Set.of(ITEM_ID)))
                .thenReturn(List.of(item));

        service.finalizePurge(purgeContext());

        Mockito.verify(progressRepository).deleteByOwnerUserIdAndReaderItemIdIn(OWNER_ID, List.of(ITEM_ID));
        Mockito.verify(bookshelfRepository).deleteByOwnerUserIdAndReaderItemIdIn(OWNER_ID, List.of(ITEM_ID));
        Mockito.verify(bookmarkRepository).deleteByOwnerUserIdAndReaderItemIdIn(OWNER_ID, List.of(ITEM_ID));
        Mockito.verify(annotationRepository).deleteByOwnerUserIdAndReaderItemIdIn(OWNER_ID, List.of(ITEM_ID));
        Mockito.verify(noteRepository).deleteByOwnerUserIdAndReaderItemIdIn(OWNER_ID, List.of(ITEM_ID));
        Mockito.verify(readingSessionRepository).deleteByReaderItemIdIn(List.of(ITEM_ID));
        Mockito.verify(pageAssetRepository).deleteByReaderItemIdIn(List.of(ITEM_ID));
        Mockito.verify(pageRepository).deleteByReaderItemIdIn(List.of(ITEM_ID));
        Mockito.verify(catalogRepository).deleteByReaderItemIdIn(List.of(ITEM_ID));
        Mockito.verify(itemSourceRepository).deleteByReaderItemIdIn(List.of(ITEM_ID));
        Mockito.verify(textChapterRepository).deleteByReaderItemIdIn(List.of(ITEM_ID));
        Mockito.verify(itemRepository).deleteAllInBatch(List.of(item));
    }

    @Test
    void softDeletePreservesReaderRows() {
        service.handleFileNodesSoftDeleted(new FileNodesSoftDeletedEvent(
                OWNER_ID,
                List.of(FILE_NODE_ID),
                Instant.now()
        ));

        Mockito.verifyNoInteractions(progressRepository, bookshelfRepository, bookmarkRepository);
        Mockito.verifyNoInteractions(annotationRepository, noteRepository, readingSessionRepository);
    }

    @Test
    void visibilityChangeInvalidatesAffectedReaderOwner() {
        ReaderItem item = item();
        Mockito.when(itemRepository.findByFileNodeIdIn(List.of(FILE_NODE_ID)))
                .thenReturn(List.of(item));
        Mockito.when(itemRepository.findAllById(Set.of(ITEM_ID)))
                .thenReturn(List.of(item));

        service.invalidateFileVisibility(List.of(FILE_NODE_ID));

        Mockito.verify(syncEventService).invalidate(
                OWNER_ID,
                SyncScope.READER,
                "READER_LIBRARY",
                Map.of("reason", "FILE_VISIBILITY_CHANGED")
        );
    }

    @Test
    void hardDeleteRemovesCrossOwnerItemReferencedThroughAdditionalSource() {
        ReaderItem item = item();
        item.setOwnerUserId(OTHER_OWNER_ID);
        item.setFileNodeId(UUID.fromString("20000000-0000-0000-0000-000000000002"));
        ReaderItemSource source = new ReaderItemSource();
        source.setReaderItemId(ITEM_ID);
        source.setFileNodeId(FILE_NODE_ID);
        Mockito.when(itemSourceRepository.findByFileNodeIdIn(List.of(FILE_NODE_ID)))
                .thenReturn(List.of(source));
        Mockito.when(itemRepository.findAllById(Set.of(ITEM_ID)))
                .thenReturn(List.of(item));

        service.finalizePurge(purgeContext());

        Mockito.verify(progressRepository).deleteByOwnerUserIdAndReaderItemIdIn(
                OTHER_OWNER_ID,
                List.of(ITEM_ID)
        );
        Mockito.verify(pageAssetRepository).deleteByReaderItemIdIn(List.of(ITEM_ID));
        Mockito.verify(pageRepository).deleteByReaderItemIdIn(List.of(ITEM_ID));
        Mockito.verify(catalogRepository).deleteByReaderItemIdIn(List.of(ITEM_ID));
        Mockito.verify(itemSourceRepository).deleteByReaderItemIdIn(List.of(ITEM_ID));
        Mockito.verify(textChapterRepository).deleteByReaderItemIdIn(List.of(ITEM_ID));
        Mockito.verify(itemRepository).deleteAllInBatch(List.of(item));
    }

    private ReaderItem item() {
        ReaderItem item = new ReaderItem();
        item.setId(ITEM_ID);
        item.setOwnerUserId(OWNER_ID);
        item.setFileNodeId(FILE_NODE_ID);
        return item;
    }

    private PurgeContext purgeContext() {
        return new PurgeContext(UUID.randomUUID(), OWNER_ID, FILE_NODE_ID, List.of(FILE_NODE_ID));
    }
}
