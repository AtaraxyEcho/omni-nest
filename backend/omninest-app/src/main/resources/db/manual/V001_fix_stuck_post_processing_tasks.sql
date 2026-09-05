-- 文件后处理历史僵尸任务清理（幂等）
-- 适用版本： ThumbnailConsumer/FileIndexConsumer/TextExtractionConsumer 补状态接线前产生的数据
-- 背景：这三个任务类型曾经只执行业务不回写 sys_tasks，任务记录永久停留在 QUEUED/进度 0，
--       且运行中数据已无法判断真实结果，统一标记为 FAILED 便于管理员在任务页手动重试。
-- 前置条件：无
-- 影响：仅更新 sys_tasks 状态字段；不影响任何业务数据
-- 校验：执行后 SELECT task_type, status, count(*) FROM omni.sys_tasks WHERE task_type IN (...) GROUP BY 1,2;
-- 回滚：无需回滚（终态标记不会阻断业务；确需重跑任务可在管理端任务页重试）

UPDATE omni.sys_tasks
SET status = 'FAILED',
    error_summary = 'LEGACY_STUCK_QUEUED: 状态跟踪接线修复前的历史任务，真实执行结果未知',
    completed_at = now(),
    updated_at = now()
WHERE task_type IN ('THUMBNAIL', 'FILE_INDEX', 'TEXT_EXTRACTION')
  AND status IN ('QUEUED', 'RETRY_WAIT')
  AND heartbeat_at IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM omni.sys_task_dispatches d
      WHERE d.task_id = sys_tasks.id
        AND d.status IN ('PENDING', 'PUBLISHING')
  );
