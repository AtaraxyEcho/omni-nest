package com.omninest.modules.user.service;

import com.omninest.modules.user.repository.AuthUserRepository;
import java.nio.charset.StandardCharsets;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 基于用户资料中的头像文件标识实现对象引用查询。
 *
 * @author OmniNest
 */
@Service
@RequiredArgsConstructor
public class UserAvatarObjectReferenceQueryService implements UserAvatarObjectReferenceQuery {
    private static final String AVATAR_PREFIX = "avatars/";

    private final AuthUserRepository authUserRepository;

    /**
     * 查询候选对象键中仍被用户头像引用的键。
     *
     * @param objectKeys 候选对象键
     * @return 已引用对象键
     */
    @Override
    @Transactional(readOnly = true)
    public Set<String> findReferencedObjectKeys(Collection<String> objectKeys) {
        if (objectKeys == null || objectKeys.isEmpty()) {
            return Set.of();
        }
        Map<UUID, String> objectKeysByAvatarId = new HashMap<>();
        for (String objectKey : objectKeys) {
            if (objectKey == null || !objectKey.startsWith(AVATAR_PREFIX)) {
                continue;
            }
            UUID avatarFileId = UUID.nameUUIDFromBytes(objectKey.getBytes(StandardCharsets.UTF_8));
            objectKeysByAvatarId.put(avatarFileId, objectKey);
        }
        if (objectKeysByAvatarId.isEmpty()) {
            return Set.of();
        }
        Set<String> referencedObjectKeys = new HashSet<>();
        for (UUID avatarFileId : authUserRepository.findExistingAvatarFileIds(objectKeysByAvatarId.keySet())) {
            String objectKey = objectKeysByAvatarId.get(avatarFileId);
            if (objectKey != null) {
                referencedObjectKeys.add(objectKey);
            }
        }
        return Set.copyOf(referencedObjectKeys);
    }
}
