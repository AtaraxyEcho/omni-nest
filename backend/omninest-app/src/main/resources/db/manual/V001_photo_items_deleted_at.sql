-- 回收站：photo_items 增加软删时间戳
-- 适用版本：当前 V001 基线阶段（未进入历史迁移不可变阶段前与 V001 重写同步发布）
-- 前置条件：数据库中已存在 omni.photo_items 表
-- 影响：新增可空列 deleted_at， NULL 表示未删除；随后端版本照片删除改为进入回收站
-- 校验：SELECT count(*) FROM omni.photo_items WHERE deleted_at IS NOT NULL; 应为 0（升级后）
-- 回滚：ALTER TABLE "omni"."photo_items" DROP COLUMN IF EXISTS "deleted_at";
--      DROP INDEX IF EXISTS "omni"."idx_photo_items_owner_deleted_at";

ALTER TABLE "omni"."photo_items" ADD COLUMN IF NOT EXISTS "deleted_at" timestamptz(6);

CREATE INDEX IF NOT EXISTS "idx_photo_items_owner_deleted_at"
  ON "omni"."photo_items" USING btree ("owner_user_id" ASC, "deleted_at" ASC)
  WHERE "deleted_at" IS NOT NULL;
