package com.omninest.modules.file.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.omninest.common.enums.ErrorCode;
import com.omninest.common.error.BusinessException;
import com.omninest.modules.file.config.LocalMediaStorageProperties;
import com.omninest.modules.file.repository.FileContentRefRepository;
import com.omninest.modules.file.repository.StorageLocationRepository;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

/**
 * 存储位置运行时门禁测试。
 *
 * @author OmniNest
 */
class StorageLocationServiceTest {
    private final StorageLocationRepository locationRepository = Mockito.mock(StorageLocationRepository.class);
    private final FileContentRefRepository contentRefRepository = Mockito.mock(FileContentRefRepository.class);
    private final LocalMediaPathResolver pathResolver = Mockito.mock(LocalMediaPathResolver.class);
    private final LocalMediaRuntimeConfigService runtimeConfigService =
            Mockito.mock(LocalMediaRuntimeConfigService.class);
    private final StorageLocationService service = new StorageLocationService(
            locationRepository,
            contentRefRepository,
            pathResolver,
            new LocalMediaStorageProperties(),
            runtimeConfigService,
            List.of()
    );

    @Test
    void disabledRuntimeReturnsNoAccessibleLocations() {
        Mockito.when(runtimeConfigService.isEnabled()).thenReturn(false);

        assertThat(service.listAccessible(UUID.randomUUID())).isEmpty();
        Mockito.verifyNoInteractions(locationRepository);
    }

    @Test
    void disabledRuntimeRejectsLocationAccessBeforeRepositoryLookup() {
        Mockito.when(runtimeConfigService.isEnabled()).thenReturn(false);

        assertThatThrownBy(() -> service.requireAccessibleLocation(UUID.randomUUID(), UUID.randomUUID()))
                .isInstanceOf(BusinessException.class)
                .extracting(exception -> ((BusinessException) exception).errorCode())
                .isEqualTo(ErrorCode.DEPENDENCY_UNAVAILABLE);
        Mockito.verifyNoInteractions(locationRepository, pathResolver);
    }
}
