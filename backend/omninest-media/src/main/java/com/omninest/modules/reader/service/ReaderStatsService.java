package com.omninest.modules.reader.service;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.modules.reader.domain.ReaderReadingSession;
import com.omninest.modules.reader.dto.ReaderDtos.ReaderReadingStatsDto;
import com.omninest.modules.reader.dto.ReaderDtos.RecordSessionRequest;
import com.omninest.modules.reader.repository.ReaderItemRepository;
import com.omninest.modules.reader.repository.ReaderReadingSessionRepository;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.TemporalAdjusters;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 阅读统计服务：记录阅读会话并计算统计数据。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ReaderStatsService {

    private final ReaderReadingSessionRepository sessionRepository;
    private final ReaderItemRepository itemRepository;

    /**
     * 记录一次阅读会话。
     *
     * @param ownerUserId  所有者用户 ID
     * @param readerItemId 阅读条目 ID
     * @param request      会话记录请求
     */
    public void recordSession(UUID ownerUserId, UUID readerItemId, RecordSessionRequest request) {
        if (request == null) {
            throw new BusinessException(ErrorCode.PARAM_ERROR, "会话记录请求参数不能为空");
        }
        if (request.durationSeconds() <= 0) {
            throw new BusinessException(ErrorCode.PARAM_ERROR, "会话时长必须大于 0");
        }
        itemRepository.findByIdAndOwnerUserId(readerItemId, ownerUserId)
                .orElseThrow(() -> new BusinessException(ErrorCode.BOOK_NOT_FOUND, "阅读条目不存在"));

        String clientSessionId = normalizeClientSessionId(request.clientSessionId());
        if (clientSessionId != null
                && sessionRepository.existsByOwnerUserIdAndClientSessionId(ownerUserId, clientSessionId)) {
            log.debug("忽略重复阅读会话: userId={}, itemId={}, clientSessionId={}", ownerUserId, readerItemId, clientSessionId);
            return;
        }

        ReaderReadingSession session = new ReaderReadingSession();
        session.setOwnerUserId(ownerUserId);
        session.setReaderItemId(readerItemId);
        session.setClientSessionId(clientSessionId);
        session.setStartedAt(request.startedAt() != null ? request.startedAt() : Instant.now());
        session.setEndedAt(request.endedAt());
        session.setDurationSeconds(request.durationSeconds());
        try {
            sessionRepository.saveAndFlush(session);
        } catch (DataIntegrityViolationException ex) {
            if (clientSessionId != null
                    && sessionRepository.existsByOwnerUserIdAndClientSessionId(ownerUserId, clientSessionId)) {
                log.debug("忽略并发重复阅读会话: userId={}, itemId={}, clientSessionId={}",
                        ownerUserId, readerItemId, clientSessionId);
                return;
            }
            throw ex;
        }
        log.debug("记录阅读会话: userId={}, itemId={}, duration={}s", ownerUserId, readerItemId, request.durationSeconds());
    }

    private String normalizeClientSessionId(String clientSessionId) {
        if (clientSessionId == null) {
            return null;
        }
        String trimmed = clientSessionId.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    /**
     * 获取用户的阅读统计数据。
     *
     * @param ownerUserId 所有者用户 ID
     * @return 阅读统计 DTO
     */
    @Transactional(readOnly = true)
    public ReaderReadingStatsDto getStats(UUID ownerUserId) {
        // 使用服务器本地时区（自托管场景下即用户时区）
        ZoneId zone = ZoneId.systemDefault();
        // 今日起始时间
        Instant todayStart = LocalDate.now(zone).atStartOfDay(zone).toInstant();
        // 本周起始时间（周一）
        Instant weekStart = LocalDate.now(zone)
                .with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
                .atStartOfDay(zone)
                .toInstant();

        long totalSecondsToday = sessionRepository.sumDurationSecondsSince(ownerUserId, todayStart);
        long totalSecondsThisWeek = sessionRepository.sumDurationSecondsSince(ownerUserId, weekStart);

        // 计算连续阅读天数
        int currentStreak = calculateStreak(ownerUserId);

        return new ReaderReadingStatsDto(
                (int) (totalSecondsToday / 60),
                (int) (totalSecondsThisWeek / 60),
                currentStreak,
                (int) itemRepository.countByOwnerUserId(ownerUserId)
        );
    }

    /**
     * 计算连续阅读天数（从今天往回数，连续有阅读记录的天数）。
     */
    private int calculateStreak(UUID ownerUserId) {
        Instant ninetyDaysAgo = Instant.now().minusSeconds(90L * 24 * 3600);
        // 计算服务器本地时区的 UTC 偏移量（如 "+08:00"）
        ZoneId zone = ZoneId.systemDefault();
        String utcOffset = zone.getRules().getOffset(Instant.now()).getId();
        List<LocalDate> readingDays = sessionRepository.distinctReadingDaysSince(ownerUserId, ninetyDaysAgo, utcOffset);
        if (readingDays.isEmpty()) {
            return 0;
        }
        LocalDate today = LocalDate.now(zone);
        int streak = 0;
        LocalDate expected = today;
        for (LocalDate day : readingDays) {
            if (day.equals(expected)) {
                streak++;
                expected = expected.minusDays(1);
            } else if (day.isBefore(expected)) {
                break;
            }
        }
        return streak;
    }
}
