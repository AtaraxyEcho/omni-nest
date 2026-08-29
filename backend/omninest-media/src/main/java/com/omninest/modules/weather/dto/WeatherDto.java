package com.omninest.modules.weather.dto;

/**
 * 天气数据传输对象
 */
public record WeatherDto(
    double temp,
    double feelsLike,
    String text,
    String icon,
    String humidity,
    String windSpeed,
    String windDir,
    String pressure,
    String visibility,
    int uvIndex,
    String sunrise,
    String sunset,
    int aqi,
    int pm2p5,
    String aqiCategory,
    String updateTime,
    String healthAdvice,
    double tempMax,
    double tempMin,
    String precip,
    String windScale,
    String textDay,
    String textNight
) {
    /**
     * 返回空数据（用于未启用或获取失败时）
     */
    public static WeatherDto empty() {
        return new WeatherDto(
            0.0, 0.0, "未知", "999",
            "--", "--", "--", "--", "--",
            0, "--", "--",
            0, 0, "--", "", "",
            0.0, 0.0, "--", "--", "--", "--"
        );
    }
}
