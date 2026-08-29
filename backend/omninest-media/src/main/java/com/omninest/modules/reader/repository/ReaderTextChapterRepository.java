package com.omninest.modules.reader.repository;

import com.omninest.modules.reader.domain.ReaderTextChapter;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 文本书籍章节清单仓储。
 *
 * @author OmniNest
 */
public interface ReaderTextChapterRepository extends JpaRepository<ReaderTextChapter, UUID> {

    /**
     * 按稳定章节顺序读取清单。
     *
     * @param readerItemId 阅读条目 ID
     * @return 章节清单
     */
    List<ReaderTextChapter> findByReaderItemIdOrderByChapterIndex(UUID readerItemId);

    /**
     * 删除条目的旧章节清单。
     *
     * @param readerItemId 阅读条目 ID
     */
    void deleteByReaderItemId(UUID readerItemId);

    /**
     * 批量删除条目的章节清单。
     *
     * @param readerItemIds 阅读条目 ID 集合
     */
    void deleteByReaderItemIdIn(Collection<UUID> readerItemIds);
}
