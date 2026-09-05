package com.omninest.modules.photos.service;

/**
 * 球面距离计算工具。
 *
 * <p>统一使用 Haversine 公式（atan2 形式），地球平均半径 6371.0088 公里。</p>
 *
 * @author OmniNest
 */
public final class GeoDistance {

    private static final double EARTH_RADIUS_KM = 6371.0088;

    private GeoDistance() {
    }

    /**
     * 计算两点球面距离。
     *
     * @param latitude1 点 1 纬度（度）
     * @param longitude1 点 1 经度（度）
     * @param latitude2Radians 点 2 纬度（弧度，快照预计算值）
     * @param longitude2Radians 点 2 经度（弧度，快照预计算值）
     * @return 距离（公里）
     */
    public static double haversineKm(
            double latitude1,
            double longitude1,
            double latitude2Radians,
            double longitude2Radians) {
        double latitude1Radians = Math.toRadians(latitude1);
        double deltaLatitude = latitude2Radians - latitude1Radians;
        double deltaLongitude = longitude2Radians - Math.toRadians(longitude1);
        double a = Math.pow(Math.sin(deltaLatitude / 2), 2)
                + Math.cos(latitude1Radians) * Math.cos(latitude2Radians)
                        * Math.pow(Math.sin(deltaLongitude / 2), 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return EARTH_RADIUS_KM * c;
    }
}
