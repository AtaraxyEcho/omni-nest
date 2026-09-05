-- GeoNames 离线地名库：geo_dataset / geo_cities 建表（幂等）
-- 适用版本：当前 V001 基线阶段（与 V001 重写同步发布）
-- 前置条件：无
-- 影响：新增两张独立参考表，无外键，与业务数据无数据库级关联
-- 数据准备（部署时人工执行，数据文件不入版本库）：
--   1. 下载 GeoNames dump（https://download.geonames.org/export/dump/）：
--        cities5000.zip、admin1CodesASCII.txt、countryInfo.txt、alternateNamesV2.zip
--   2. 解压后放到服务端共享目录 data/geonames/imports/<dump日期>/ 下：
--        cities5000.txt、admin1CodesASCII.txt、countryInfo.txt、alternateNamesV2.txt
--      多实例部署时至少 Worker 实例必须挂载该共享目录
--   3. 调用管理端点创建导入任务（photo:admin 权限）：
--        curl -X POST "$BASE_URL/api/v1/admin/photos/geo/import" \
--          -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
--          -d '{"dumpDate": "2026-09-05"}'
--   4. 通过 GET /api/v1/tasks/{taskId} 跟踪进度；发布成功后各实例自动重载索引，
--      也可手动触发 POST /api/v1/admin/photos/geo/reload
--   5. 存量照片回填：POST /api/v1/admin/photos/geo/backfill
-- 回滚：DROP TABLE IF EXISTS "omni"."geo_cities"; DROP TABLE IF EXISTS "omni"."geo_dataset";
-- 校验：SELECT count(*) FROM omni.geo_cities; 与 dump 行数一致
--       SELECT dataset_version, status FROM omni.geo_dataset WHERE status = 'PUBLISHED';

CREATE TABLE IF NOT EXISTS "omni"."geo_dataset" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "dataset_version" varchar(64) NOT NULL,
  "source_dump_date" date NOT NULL,
  "dataset_type" varchar(32) NOT NULL DEFAULT 'cities5000'::character varying,
  "source_hash" varchar(128),
  "status" varchar(20) NOT NULL,
  "created_at" timestamptz(6) NOT NULL DEFAULT now(),
  "updated_at" timestamptz(6) NOT NULL DEFAULT now(),
  "published_at" timestamptz(6),
  "version" int8 NOT NULL DEFAULT 0,
  CONSTRAINT "pk_geo_dataset" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "uk_geo_dataset_version"
  ON "omni"."geo_dataset" USING btree ("dataset_version" ASC);

CREATE TABLE IF NOT EXISTS "omni"."geo_cities" (
  "dataset_id" uuid NOT NULL,
  "geoname_id" int8 NOT NULL,
  "name" varchar(200) NOT NULL,
  "name_zh" varchar(200),
  "country_code" varchar(2) NOT NULL,
  "country_name_en" varchar(200),
  "country_name_zh" varchar(200),
  "province_name_en" varchar(200),
  "province_name_zh" varchar(200),
  "latitude" numeric(10,7) NOT NULL,
  "longitude" numeric(10,7) NOT NULL,
  "population" int8 NOT NULL DEFAULT 0,
  "feature_code" varchar(10),
  "created_at" timestamptz(6) NOT NULL DEFAULT now(),
  CONSTRAINT "pk_geo_cities" PRIMARY KEY ("dataset_id", "geoname_id")
);
