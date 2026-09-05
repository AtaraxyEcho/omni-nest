package com.omninest.modules.photos.service;

import com.omninest.modules.photos.repository.GeoCityRepository;
import java.math.BigDecimal;
import java.util.List;

/**
 * 已发布 GeoNames 数据集的不可变内存快照。
 *
 * <p>构建完成后整体不可变，索引切换通过整体替换引用完成，禁止原地增删。</p>
 *
 * @param datasetVersion 数据集版本号
 * @param cities 城市条目
 * @author OmniNest
 */
public record GeoCitySnapshot(String datasetVersion, List<Entry> cities) {

    /** 空快照：尚未导入或未发布任何数据集。 */
    public static final GeoCitySnapshot EMPTY = new GeoCitySnapshot(null, List.of());

    /** 快照城市条目，坐标为弧度预计算值。 */
    public record Entry(
            long geonameId,
            String name,
            String nameZh,
            String countryCode,
            String countryNameEn,
            String countryNameZh,
            String provinceNameEn,
            String provinceNameZh,
            double latitudeRadians,
            double longitudeRadians) {
    }

    /**
     * 从仓储行构建不可变快照。
     *
     * @param datasetVersion 数据集版本号
     * @param rows 城市行
     * @return 快照
     */
    public static GeoCitySnapshot from(String datasetVersion, List<GeoCityRepository.GeoCityRow> rows) {
        List<Entry> entries = rows.stream()
                .map(row -> new Entry(
                        row.getGeonameId(),
                        row.getName(),
                        row.getNameZh(),
                        row.getCountryCode(),
                        row.getCountryNameEn(),
                        row.getCountryNameZh(),
                        row.getProvinceNameEn(),
                        row.getProvinceNameZh(),
                        Math.toRadians(row.getLatitude().doubleValue()),
                        Math.toRadians(row.getLongitude().doubleValue())))
                .toList();
        return new GeoCitySnapshot(datasetVersion, entries);
    }
}
