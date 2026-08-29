package com.omninest.modules.weather.infrastructure;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONObject;
import com.omninest.common.util.RedisUtil;
import com.omninest.modules.weather.service.UserLocationStore;
import com.omninest.modules.weather.service.UserLocationStore.UserLocationSnapshot;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 使用 Redis 保存用户最近上报的位置快照。
 *
 * @author OmniNest
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RedisUserLocationStore implements UserLocationStore {

    private static final String LOCATION_KEY_PREFIX = "weather:user:location:";

    private final RedisUtil redisUtil;

    /**
     * 保存用户位置快照并设置有效期。
     *
     * @param userId 用户标识
     * @param location 位置快照
     * @param ttl 快照有效期
     */
    @Override
    public void save(UUID userId, UserLocationSnapshot location, Duration ttl) {
        JSONObject json = new JSONObject();
        json.put("latLon", location.latLon());
        json.put("source", location.source());
        json.put("ts", location.reportedAt().toEpochMilli());
        try {
            redisUtil.set(key(userId), json.toJSONString(), ttl);
        } catch (RuntimeException exception) {
            log.error("保存用户位置失败: userId={}", userId, exception);
        }
    }

    /**
     * 查询并解析用户位置快照。
     *
     * @param userId 用户标识
     * @return 位置快照
     */
    @Override
    public Optional<UserLocationSnapshot> find(UUID userId) {
        try {
            String value = redisUtil.get(key(userId));
            if (value == null || value.isBlank()) {
                return Optional.empty();
            }
            JSONObject json = JSON.parseObject(value);
            return Optional.of(new UserLocationSnapshot(
                    json.getString("latLon"),
                    json.getString("source"),
                    Instant.ofEpochMilli(json.getLongValue("ts"))
            ));
        } catch (RuntimeException exception) {
            log.error("读取用户位置失败: userId={}", userId, exception);
            return Optional.empty();
        }
    }

    private String key(UUID userId) {
        return LOCATION_KEY_PREFIX + userId;
    }
}
