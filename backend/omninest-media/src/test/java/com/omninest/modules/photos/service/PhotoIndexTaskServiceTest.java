package com.omninest.modules.photos.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.omninest.modules.photos.domain.PhotoItem;
import com.omninest.modules.file.service.FileLifecycleGuard;
import com.omninest.modules.photos.domain.PhotoTag;
import com.omninest.modules.photos.repository.PhotoItemRepository;
import com.omninest.modules.photos.repository.PhotoTagRepository;
import com.omninest.modules.photos.search.PhotoSearchIndexService;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

/**
 * 照片搜索索引任务服务测试。
 *
 * @author OmniNest
 */
class PhotoIndexTaskServiceTest {
    private final PhotoItemRepository photoItemRepository = Mockito.mock(PhotoItemRepository.class);
    private final PhotoTagRepository photoTagRepository = Mockito.mock(PhotoTagRepository.class);
    private final PhotoSearchIndexService photoSearchIndexService = Mockito.mock(PhotoSearchIndexService.class);
    private final FileLifecycleGuard fileLifecycleGuard = Mockito.mock(FileLifecycleGuard.class);
    private final PhotoIndexTaskService service = new PhotoIndexTaskService(
            photoItemRepository,
            photoTagRepository,
            photoSearchIndexService,
            fileLifecycleGuard
    );

    @Test
    void indexLoadsOwnedPhotoAndTags() {
        UUID ownerUserId = UUID.randomUUID();
        UUID photoId = UUID.randomUUID();
        UUID fileNodeId = UUID.randomUUID();
        PhotoItem photo = new PhotoItem();
        photo.setId(photoId);
        photo.setOwnerUserId(ownerUserId);
        photo.setFileNodeId(fileNodeId);
        photo.setTitle("Mountain");
        photo.setDescription("Sunrise");
        PhotoTag firstTag = new PhotoTag();
        firstTag.setTag("travel");
        PhotoTag secondTag = new PhotoTag();
        secondTag.setTag("sunrise");
        Mockito.when(photoItemRepository.findByOwnerUserIdAndId(ownerUserId, photoId))
                .thenReturn(Optional.of(photo));
        Mockito.when(photoTagRepository.findByOwnerUserIdAndPhotoId(ownerUserId, photoId))
                .thenReturn(List.of(firstTag, secondTag));
        Mockito.when(fileLifecycleGuard.isOwnedProcessable(ownerUserId, fileNodeId)).thenReturn(true);

        boolean indexed = service.index(ownerUserId, photoId);

        assertThat(indexed).isTrue();
        Mockito.verify(photoSearchIndexService).indexPhoto(
                photoId,
                ownerUserId,
                "Mountain",
                "Sunrise",
                List.of("travel", "sunrise")
        );
    }

    @Test
    void indexReturnsFalseWhenSourceFileIsPurging() {
        UUID ownerUserId = UUID.randomUUID();
        UUID photoId = UUID.randomUUID();
        UUID fileNodeId = UUID.randomUUID();
        PhotoItem photo = new PhotoItem();
        photo.setId(photoId);
        photo.setOwnerUserId(ownerUserId);
        photo.setFileNodeId(fileNodeId);
        Mockito.when(photoItemRepository.findByOwnerUserIdAndId(ownerUserId, photoId))
                .thenReturn(Optional.of(photo));
        Mockito.when(fileLifecycleGuard.isOwnedProcessable(ownerUserId, fileNodeId)).thenReturn(false);

        boolean indexed = service.index(ownerUserId, photoId);

        assertThat(indexed).isFalse();
        Mockito.verifyNoInteractions(photoTagRepository, photoSearchIndexService);
    }

    @Test
    void indexReturnsFalseWhenOwnedPhotoDoesNotExist() {
        UUID ownerUserId = UUID.randomUUID();
        UUID photoId = UUID.randomUUID();
        Mockito.when(photoItemRepository.findByOwnerUserIdAndId(ownerUserId, photoId))
                .thenReturn(Optional.empty());

        boolean indexed = service.index(ownerUserId, photoId);

        assertThat(indexed).isFalse();
        Mockito.verifyNoInteractions(photoTagRepository, photoSearchIndexService);
    }
}
