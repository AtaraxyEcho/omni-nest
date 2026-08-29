package com.omninest.modules.reader.service;

import com.omninest.common.sync.SyncAction;
import com.omninest.common.sync.SyncScope;
import com.omninest.modules.media.service.MediaSyncEventService;
import com.omninest.modules.reader.domain.ReaderBookshelf;
import com.omninest.modules.reader.repository.ReaderBookshelfRepository;
import java.util.Map;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 阅读书架服务：管理书架的添加与移除。
 *
 * @author OmniNest
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ReaderBookshelfService {

    private final ReaderBookshelfRepository bookshelfRepository;
    private final MediaSyncEventService syncEventService;

    /**
     * 切换书架状态：已存在则移除，不存在则添加。
     *
     * @param ownerUserId  所有者用户 ID
     * @param readerItemId 阅读条目 ID
     * @return true 表示已添加到书架，false 表示已从书架移除
     */
    @Transactional(rollbackFor = Exception.class)
    public boolean toggleBookshelf(UUID ownerUserId, UUID readerItemId) {
        boolean exists = bookshelfRepository.existsByOwnerUserIdAndReaderItemId(ownerUserId, readerItemId);
        if (exists) {
            bookshelfRepository.deleteByOwnerUserIdAndReaderItemId(ownerUserId, readerItemId);
            recordBookshelfEvent(ownerUserId, readerItemId, false);
            log.info("从书架移除: userId={}, itemId={}", ownerUserId, readerItemId);
            return false;
        }
        ReaderBookshelf entry = new ReaderBookshelf();
        entry.setOwnerUserId(ownerUserId);
        entry.setReaderItemId(readerItemId);
        bookshelfRepository.save(entry);
        recordBookshelfEvent(ownerUserId, readerItemId, true);
        log.info("添加到书架: userId={}, itemId={}", ownerUserId, readerItemId);
        return true;
    }

    /**
     * 判断阅读条目是否在当前用户书架中。
     *
     * @param ownerUserId  所有者用户 ID
     * @param readerItemId 阅读条目 ID
     * @return true 表示已加入书架
     */
    @Transactional(readOnly = true)
    public boolean isOnBookshelf(UUID ownerUserId, UUID readerItemId) {
        return bookshelfRepository.existsByOwnerUserIdAndReaderItemId(ownerUserId, readerItemId);
    }

    private void recordBookshelfEvent(UUID ownerUserId, UUID readerItemId, boolean onBookshelf) {
        syncEventService.record(
                ownerUserId,
                SyncScope.READER,
                "READER_BOOKSHELF",
                readerItemId.toString(),
                SyncAction.UPDATED,
                null,
                Map.of("onBookshelf", onBookshelf)
        );
    }
}
