package com.omninest.modules.video.event;

import java.util.UUID;

public record MediaScrapeRequestedEvent(
        UUID taskId,
        UUID ownerUserId,
        UUID fileNodeId,
        String title,
        Integer year,
        Integer seasonNumber,
        Integer episodeNumber,
        boolean force
) {
}
