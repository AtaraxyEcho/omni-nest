package com.omninest.modules.user.service;

import java.util.Collection;
import java.util.Set;

/**
 * 用户头像对象引用查询端口。
 *
 * @author OmniNest
 */
public interface UserAvatarObjectReferenceQuery {

    /**
     * 查询候选对象键中仍被用户头像引用的键。
     *
     * @param objectKeys 候选对象键
     * @return 已引用对象键
     */
    Set<String> findReferencedObjectKeys(Collection<String> objectKeys);
}
