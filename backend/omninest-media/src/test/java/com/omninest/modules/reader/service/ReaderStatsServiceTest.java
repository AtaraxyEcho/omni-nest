package com.omninest.modules.reader.service;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.omninest.modules.reader.domain.ReaderItem;
import com.omninest.modules.reader.domain.ReaderReadingSession;
import com.omninest.modules.reader.dto.ReaderDtos.RecordSessionRequest;
import com.omninest.modules.reader.repository.ReaderItemRepository;
import com.omninest.modules.reader.repository.ReaderReadingSessionRepository;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;

class ReaderStatsServiceTest {
    private static final UUID OWNER_ID = UUID.fromString("10000000-0000-0000-0000-000000000001");
    private static final UUID ITEM_ID = UUID.fromString("20000000-0000-0000-0000-000000000001");

    private final ReaderReadingSessionRepository sessionRepository = mock(ReaderReadingSessionRepository.class);
    private final ReaderItemRepository itemRepository = mock(ReaderItemRepository.class);
    private final ReaderStatsService readerStatsService = new ReaderStatsService(sessionRepository, itemRepository);

    @Test
    void recordSessionIgnoresConcurrentClientSessionDuplicate() {
        ReaderItem item = new ReaderItem();
        item.setId(ITEM_ID);
        item.setOwnerUserId(OWNER_ID);
        item.setTitle("测试书籍");
        item.setItemType("EPUB");
        when(itemRepository.findByIdAndOwnerUserId(ITEM_ID, OWNER_ID)).thenReturn(Optional.of(item));
        when(sessionRepository.existsByOwnerUserIdAndClientSessionId(OWNER_ID, "session-1"))
                .thenReturn(false, true);
        when(sessionRepository.saveAndFlush(any(ReaderReadingSession.class)))
                .thenThrow(new DataIntegrityViolationException("duplicate client session"));

        RecordSessionRequest request = new RecordSessionRequest(
                " session-1 ",
                Instant.parse("2026-06-01T10:00:00Z"),
                Instant.parse("2026-06-01T10:05:00Z"),
                300
        );

        assertThatCode(() -> readerStatsService.recordSession(OWNER_ID, ITEM_ID, request)).doesNotThrowAnyException();
        verify(sessionRepository).saveAndFlush(any(ReaderReadingSession.class));
    }

    @Test
    void recordSessionRethrowsNonDuplicateIntegrityViolation() {
        ReaderItem item = new ReaderItem();
        item.setId(ITEM_ID);
        item.setOwnerUserId(OWNER_ID);
        item.setTitle("测试书籍");
        item.setItemType("EPUB");
        when(itemRepository.findByIdAndOwnerUserId(ITEM_ID, OWNER_ID)).thenReturn(Optional.of(item));
        when(sessionRepository.existsByOwnerUserIdAndClientSessionId(OWNER_ID, "session-1")).thenReturn(false);
        when(sessionRepository.saveAndFlush(any(ReaderReadingSession.class)))
                .thenThrow(new DataIntegrityViolationException("other constraint"));

        RecordSessionRequest request = new RecordSessionRequest(
                "session-1",
                Instant.parse("2026-06-01T10:00:00Z"),
                Instant.parse("2026-06-01T10:05:00Z"),
                300
        );

        assertThatThrownBy(() -> readerStatsService.recordSession(OWNER_ID, ITEM_ID, request))
                .isInstanceOf(DataIntegrityViolationException.class);
    }
}
