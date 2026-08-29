package com.omninest.modules.user.service;

import com.omninest.modules.user.repository.AuthUserRepository;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.assertj.core.api.Assertions;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.Mockito;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 用户头像对象引用查询测试。
 *
 * @author OmniNest
 */
@ExtendWith(MockitoExtension.class)
class UserAvatarObjectReferenceQueryServiceTest {

    @Mock
    private AuthUserRepository authUserRepository;

    @Test
    void returnsOnlyAvatarObjectsReferencedByUserProfiles() {
        String referencedAvatar = "avatars/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/avatar.webp";
        String orphanAvatar = "avatars/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb/avatar.jpg";
        String derivedAsset = "derived/photo/thumbnail.webp";
        UUID referencedAvatarId = avatarFileId(referencedAvatar);
        UUID orphanAvatarId = avatarFileId(orphanAvatar);
        Mockito.when(authUserRepository.findExistingAvatarFileIds(Set.of(referencedAvatarId, orphanAvatarId)))
                .thenReturn(List.of(referencedAvatarId));
        UserAvatarObjectReferenceQueryService service = new UserAvatarObjectReferenceQueryService(
                authUserRepository
        );

        Set<String> result = service.findReferencedObjectKeys(Set.of(
                referencedAvatar,
                orphanAvatar,
                derivedAsset
        ));

        Assertions.assertThat(result).containsExactly(referencedAvatar);
    }

    @Test
    void ignoresCandidatesOutsideAvatarPrefix() {
        UserAvatarObjectReferenceQueryService service = new UserAvatarObjectReferenceQueryService(
                authUserRepository
        );

        Set<String> result = service.findReferencedObjectKeys(Set.of("derived/photo/thumbnail.webp"));

        Assertions.assertThat(result).isEmpty();
        Mockito.verifyNoInteractions(authUserRepository);
    }

    private UUID avatarFileId(String objectKey) {
        return UUID.nameUUIDFromBytes(objectKey.getBytes(StandardCharsets.UTF_8));
    }
}
