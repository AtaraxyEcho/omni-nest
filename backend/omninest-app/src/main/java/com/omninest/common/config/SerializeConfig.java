package com.omninest.common.config;

import com.alibaba.fastjson2.JSONReader;
import com.alibaba.fastjson2.JSONWriter;
import com.alibaba.fastjson2.support.config.FastJsonConfig;
import com.alibaba.fastjson2.support.spring6.http.converter.FastJsonHttpMessageConverter;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.MediaType;

/**
 * 统一 JSON 序列化配置。
 */
@Configuration
public class SerializeConfig {
    public static final String DATE_TIME_PATTERN = "yyyy-MM-dd HH:mm:ss";

    @Bean
    public FastJsonConfig fastJsonConfig() {
        FastJsonConfig config = new FastJsonConfig();
        config.setCharset(StandardCharsets.UTF_8);
        config.setDateFormat(DATE_TIME_PATTERN);
        config.setReaderFeatures(JSONReader.Feature.SupportSmartMatch);
        config.setWriterFeatures(
                JSONWriter.Feature.WriteEnumsUsingName,
                JSONWriter.Feature.WriteNulls
        );
        return config;
    }

    @Bean
    public FastJsonHttpMessageConverter fastJsonHttpMessageConverter(FastJsonConfig fastJsonConfig) {
        FastJsonHttpMessageConverter converter = new FastJsonHttpMessageConverter();
        converter.setFastJsonConfig(fastJsonConfig);
        converter.setSupportedMediaTypes(List.of(MediaType.APPLICATION_JSON));
        return converter;
    }
}
