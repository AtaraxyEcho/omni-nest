package com.omninest.modules.photos.service;

import com.alibaba.fastjson2.JSON;
import com.omninest.common.ratelimit.RateLimitService;
import com.alibaba.fastjson2.JSONObject;
import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.binder.cache.CaffeineCacheMetrics;
import jakarta.annotation.PostConstruct;
import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * GPS 逆地理编码服务，使用 OpenStreetMap Nominatim API 将坐标转换为地名。
 * 速率限制和缓存行为通过配置中心动态调整。
 *
 * @author OmniNest
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PhotoGeoService {

    private static final String NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse";
    private static final Duration TIMEOUT = Duration.ofSeconds(10);
    private static final Duration RATE_LIMIT_WAIT = Duration.ofSeconds(2);
    private static final long MAX_CACHE_ENTRIES = 10_000;
    private static final Duration CACHE_TTL = Duration.ofHours(24);

    private final PhotosRuntimeConfigService configService;
    private final NominatimRateLimiter rateLimiter;
    private final RateLimitService distributedRateLimiter;
    private final MeterRegistry meterRegistry;

    private final Cache<String, Map<String, Object>> cache = Caffeine.newBuilder()
            .maximumSize(MAX_CACHE_ENTRIES)
            .expireAfterAccess(CACHE_TTL)
            .recordStats()
            .build();

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(TIMEOUT)
            .build();

    /**
     * 注册地理编码缓存容量、命中和淘汰指标。
     */
    @PostConstruct
    public void registerCacheMetrics() {
        CaffeineCacheMetrics.monitor(meterRegistry, cache, "photo.geo.reverse");
    }

    /**
     * 逆地理编码：将经纬度转换为地名信息。
     * 速率限制和缓存行为从配置中心动态读取。
     *
     * @param latitude 纬度
     * @param longitude 经度
     * @return 地名信息 Map（含 city/state/country/district/displayName），失败时返回空 Map
     */
    public Map<String, Object> reverseGeocode(BigDecimal latitude, BigDecimal longitude) {
        if (latitude == null || longitude == null) {
            return Map.of();
        }

        boolean cacheEnabled = configService.isGeoCacheEnabled();
        String cacheKey = String.format(
                Locale.ROOT,
                "%.2f,%.2f",
                latitude.doubleValue(),
                longitude.doubleValue()
        );

        if (cacheEnabled) {
            Map<String, Object> cached = cache.getIfPresent(cacheKey);
            if (cached != null) {
                return cached;
            }
        }

        int rateLimit = Math.max(1, configService.geoRateLimitPerSecond());

        // Redis 分布式预检：多实例部署时防止超过全局速率
        if (!distributedRateLimiter.tryAcquire(
                "nominatim:geo", rateLimit, Duration.ofSeconds(1))) {
            log.warn("Nominatim 分布式速率限制，跳过本次查询");
            return Map.of();
        }

        // 进程内间距控制：确保单实例内请求间隔不低于 1 秒
        if (!rateLimiter.tryAcquire(rateLimit, RATE_LIMIT_WAIT)) {
            log.warn("Nominatim 速率限制等待超时，跳过本次查询");
            return Map.of();
        }

        try {
            String url = NOMINATIM_URL
                    + "?lat=" + latitude.toPlainString()
                    + "&lon=" + longitude.toPlainString()
                    + "&format=json&accept-language=zh&zoom=14";
            HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                    .timeout(TIMEOUT)
                    .header("User-Agent", "OmniNest/1.0 (photo-geocoder)")
                    .GET()
                    .build();
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                log.warn("Nominatim 请求失败: status={}", response.statusCode());
                return Map.of();
            }
            JSONObject json = JSON.parseObject(response.body());
            Map<String, Object> result = new HashMap<>();
            putIfNotBlank(result, "displayName", json.getString("display_name"));
            JSONObject address = json.getJSONObject("address");
            if (address != null) {
                String city = address.getString("city");
                if (city == null || city.isBlank()) {
                    city = address.getString("town");
                }
                if (city == null || city.isBlank()) {
                    city = address.getString("village");
                }
                if (city == null || city.isBlank()) {
                    city = address.getString("municipality");
                }
                String district = firstNotBlank(
                        address.getString("city_district"),
                        address.getString("district"),
                        address.getString("county"),
                        address.getString("suburb")
                );
                putIfNotBlank(result, "city", city);
                putIfNotBlank(result, "state", address.getString("state"));
                putIfNotBlank(result, "district", district);
                putIfNotBlank(result, "country", address.getString("country"));
            }

            Map<String, Object> immutableResult = Map.copyOf(result);
            if (cacheEnabled) {
                cache.put(cacheKey, immutableResult);
            }
            return immutableResult;
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            log.warn("逆地理编码被中断");
            return Map.of();
        } catch (Exception ex) {
            log.warn("逆地理编码失败: lat={}, lon={}, error={}", latitude, longitude, ex.getMessage());
            return Map.of();
        }
    }

    private void putIfNotBlank(Map<String, Object> target, String key, String value) {
        if (value != null && !value.isBlank()) {
            target.put(key, value);
        }
    }

    private String firstNotBlank(String... values) {
        for (String value : values) {
            if (value != null && !value.isBlank()) {
                return value;
            }
        }
        return null;
    }
}
