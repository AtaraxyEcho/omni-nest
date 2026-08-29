package com.omninest.modules.reader.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.omninest.modules.media.service.MediaSyncEventService;
import com.omninest.modules.reader.domain.ReaderBookshelf;
import com.omninest.modules.reader.repository.ReaderBookshelfRepository;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 阅读书架服务单元测试。
 *
 * @author OmniNest
 */
@ExtendWith(MockitoExtension.class)
class ReaderBookshelfServiceTest {

    private static final UUID OWNER_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");
    private static final UUID ITEM_ID = UUID.fromString("20000000-0000-0000-0000-000000000001");

    @Mock
    private ReaderBookshelfRepository bookshelfRepository;
    @Mock
    private MediaSyncEventService syncEventService;

    @InjectMocks
    private ReaderBookshelfService bookshelfService;

    @Test
    void toggleAddsToBookshelf() {
        when(bookshelfRepository.existsByOwnerUserIdAndReaderItemId(OWNER_ID, ITEM_ID)).thenReturn(false);
        when(bookshelfRepository.save(any(ReaderBookshelf.class))).thenAnswer(invocation -> invocation.getArgument(0));

        boolean result = bookshelfService.toggleBookshelf(OWNER_ID, ITEM_ID);

        assertThat(result).isTrue();
        ArgumentCaptor<ReaderBookshelf> captor = ArgumentCaptor.forClass(ReaderBookshelf.class);
        verify(bookshelfRepository).save(captor.capture());
        assertThat(captor.getValue().getOwnerUserId()).isEqualTo(OWNER_ID);
        assertThat(captor.getValue().getReaderItemId()).isEqualTo(ITEM_ID);
    }

    @Test
    void toggleRemovesFromBookshelf() {
        when(bookshelfRepository.existsByOwnerUserIdAndReaderItemId(OWNER_ID, ITEM_ID)).thenReturn(true);

        boolean result = bookshelfService.toggleBookshelf(OWNER_ID, ITEM_ID);

        assertThat(result).isFalse();
        verify(bookshelfRepository).deleteByOwnerUserIdAndReaderItemId(OWNER_ID, ITEM_ID);
        verify(bookshelfRepository, never()).save(any());
    }
}
