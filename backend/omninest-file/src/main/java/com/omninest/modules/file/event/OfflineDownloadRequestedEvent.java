package com.omninest.modules.file.event;

import java.util.UUID;

public record OfflineDownloadRequestedEvent(UUID taskId) {
}
