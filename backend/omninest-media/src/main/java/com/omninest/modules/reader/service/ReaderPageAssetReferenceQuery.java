package com.omninest.modules.reader.service;

import java.util.Collection;
import java.util.Set;

/**
 * 查询 Reader 模块持有的漫画页面对象引用。
 *
 * @author OmniNest
 */
public interface ReaderPageAssetReferenceQuery {

    /**
     * 查询候选对象键中已有漫画页面元数据引用的键。
     *
     * @param bucketName 存储桶名称
     * @param objectKeys 候选对象键
     * @return 已引用对象键
     */
    Set<String> findReferencedObjectKeys(String bucketName, Collection<String> objectKeys);
}
