package com.omninest.modules.file.service;

import java.util.Collection;
import java.util.Set;

/**
 * 查询文件模块持有的对象存储引用。
 *
 * @author OmniNest
 */
public interface FileObjectReferenceQuery {

    /**
     * 查询候选对象键中已有文件元数据引用的键。
     *
     * @param bucketName 存储桶名称
     * @param objectKeys 候选对象键
     * @return 已引用对象键
     */
    Set<String> findReferencedObjectKeys(String bucketName, Collection<String> objectKeys);
}
