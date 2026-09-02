package com.omninest.modules.user.repository;

import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

/**
 * 后台任务管理仓库 — 跨模块无实体依赖，使用原生 SQL。
 *
 * @author OmniNest
 */
@Repository
@RequiredArgsConstructor
public class TaskRecordAdminRepository {
    private static final int MAX_RECENT_LIMIT = 500;
    private static final int MAX_PAGE_SIZE = 100;

    private final EntityManager entityManager;

    /**
     * 统计指定状态的任务数量。
     *
     * @param status 任务状态
     * @return 任务数量
     */
    public long countByStatus(String status) {
        return longValue(
                "select count(*) from omni.sys_tasks where status = :status",
                Map.of("status", status)
        );
    }

    /**
     * 查询最近更新的任务。
     *
     * @param limit 返回数量上限
     * @return 任务原始投影列表
     */
    @SuppressWarnings("unchecked")
    public List<Object[]> findRecent(int limit) {
        Query query = entityManager.createNativeQuery("""
                select id, task_type, status, progress, routing_key,
                       error_summary, retry_count, created_at, updated_at
                from omni.sys_tasks
                order by updated_at desc, id desc
                """);
        query.setMaxResults(Math.min(Math.max(1, limit), MAX_RECENT_LIMIT));
        return query.getResultList();
    }

    /**
     * 按管理端筛选条件分页查询任务。
     *
     * @param page 页码，从零开始
     * @param size 每页数量
     * @param status 任务状态，空字符串表示不限
     * @param taskType 任务类型，空字符串表示不限
     * @param searchPattern 模糊搜索模式，空字符串表示不限
     * @param sortColumn 排序列，仅允许白名单内的列名
     * @param ascending 是否升序
     * @return 任务分页投影
     */
    @SuppressWarnings("unchecked")
    public TaskPage findPage(
            int page,
            int size,
            String status,
            String taskType,
            String searchPattern,
            String sortColumn,
            boolean ascending
    ) {
        String filters = """
                where (:status = '' or status = :status)
                  and (:taskType = '' or task_type = :taskType)
                  and (
                    :searchPattern = ''
                    or lower(task_type) like :searchPattern
                    or lower(coalesce(routing_key, '')) like :searchPattern
                    or lower(coalesce(error_summary, '')) like :searchPattern
                    or cast(id as text) like :searchPattern
                  )
                """;
        Query contentQuery = entityManager.createNativeQuery("""
                select id, task_type, status, progress, routing_key,
                       error_summary, retry_count, created_at, updated_at
                from omni.sys_tasks
                """ + filters + taskOrderClause(sortColumn, ascending));
        bindPageFilters(contentQuery, status, taskType, searchPattern);
        int boundedSize = Math.min(Math.max(1, size), MAX_PAGE_SIZE);
        contentQuery.setFirstResult(Math.max(0, page) * boundedSize);
        contentQuery.setMaxResults(boundedSize);

        Query countQuery = entityManager.createNativeQuery(
                "select count(*) from omni.sys_tasks " + filters
        );
        bindPageFilters(countQuery, status, taskType, searchPattern);
        long totalElements = numberValue(countQuery.getSingleResult());
        return new TaskPage(contentQuery.getResultList(), totalElements);
    }

    /**
     * 按任务 ID 查询包含载荷的原始投影。
     *
     * @param taskId 任务 ID
     * @return 任务原始投影列表
     */
    @SuppressWarnings("unchecked")
    public List<Object[]> findByIdRaw(UUID taskId) {
        Query query = entityManager.createNativeQuery("""
                select id, task_type, status, progress, routing_key,
                       error_summary, retry_count, created_at, updated_at, payload
                from omni.sys_tasks
                where id = :taskId
                """);
        query.setParameter("taskId", taskId);
        return query.getResultList();
    }

    /**
     * 更新任务状态和进度。
     *
     * @param taskId 任务 ID
     * @param status 任务状态
     * @param progress 任务进度
     * @return 更新记录数
     */
    public int updateStatus(UUID taskId, String status, int progress) {
        Query query = entityManager.createNativeQuery("""
                update omni.sys_tasks
                set status = :status,
                    progress = :progress,
                    error_summary = null,
                    updated_at = now(),
                    version = version + 1
                where id = :taskId
                """);
        query.setParameter("taskId", taskId);
        query.setParameter("status", status);
        query.setParameter("progress", progress);
        return query.executeUpdate();
    }

    private long longValue(String sql, Map<String, Object> parameters) {
        Query query = entityManager.createNativeQuery(sql);
        parameters.forEach(query::setParameter);
        return numberValue(query.getSingleResult());
    }

    private void bindPageFilters(Query query, String status, String taskType, String searchPattern) {
        query.setParameter("status", status);
        query.setParameter("taskType", taskType);
        query.setParameter("searchPattern", searchPattern);
    }

    private long numberValue(Object result) {
        if (result instanceof Number number) {
            return number.longValue();
        }
        return Long.parseLong(result.toString());
    }

    /**
     * 任务分页原始投影。
     *
     * @param items 当前页任务
     * @param totalElements 筛选后的总数量
     */
    /**
     * 任务排序白名单：仅允许固定列，防止动态排序注入。
     */
    private static final java.util.Set<String> TASK_ORDERABLE_COLUMNS =
            java.util.Set.of("updated_at", "created_at", "progress", "task_type", "status");

    /**
     * 构建任务排序子句：列不在白名单时回退为更新时间，并追加 id 倒序兜底。
     */
    private String taskOrderClause(String column, boolean ascending) {
        String safe = TASK_ORDERABLE_COLUMNS.contains(column) ? column : "updated_at";
        return "order by " + safe + (ascending ? " asc" : " desc") + ", id desc";
    }

    public record TaskPage(List<Object[]> items, long totalElements) {
    }
}
