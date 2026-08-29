package com.omninest.modules.video.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.net.URI;
import java.util.Set;
import org.junit.jupiter.api.Test;

class TmdbMetadataProviderTest {

    private final MediaRuntimeConfigService configService = mock(MediaRuntimeConfigService.class);
    private final TmdbMetadataProvider provider = new TmdbMetadataProvider(configService);

    @Test
    void v3SearchUriUsesApiKeyWhenBothCredentialsConfigured() throws Exception {
        whenBaseUrl("https://api.themoviedb.org/3");
        when(configService.tmdbIncludeAdult()).thenReturn(false);

        URI uri = searchUri(new FileNameGuess("飞驰人生3", 2024, null, null), "test-key", "v4-token");

        assertThat(uri.toString()).startsWith("https://api.themoviedb.org/3/search/movie?");
        assertThat(uri.getRawQuery()).contains("query=%E9%A3%9E%E9%A9%B0%E4%BA%BA%E7%94%9F3");
        assertThat(uri.getRawQuery()).contains("api_key=test-key");
        assertThat(uri.getRawQuery()).contains("primary_release_year=2024");
        assertThat(uri.getRawQuery()).doesNotContain("&year=");
    }

    @Test
    void v4SearchUriUsesBearerCredentialWithoutApiKeyQuery() throws Exception {
        whenBaseUrl("https://api.themoviedb.org/4");
        when(configService.tmdbIncludeAdult()).thenReturn(true);

        URI uri = searchUri(new FileNameGuess("Some Show", 2020, 1, null), "test-key", "v4-token");

        assertThat(uri.toString()).startsWith("https://api.themoviedb.org/4/search/tv?");
        assertThat(uri.getRawQuery()).doesNotContain("api_key=");
        assertThat(uri.getRawQuery()).contains("include_adult=true");
        assertThat(uri.getRawQuery()).contains("first_air_date_year=2020");
    }

    @Test
    void searchQueriesUseConfiguredStrategy() throws Exception {
        when(configService.tmdbSearchQueriesStrategy()).thenReturn("NORMALIZED_ONLY");

        Method method = TmdbMetadataProvider.class.getDeclaredMethod("searchQueries", String.class);
        method.setAccessible(true);

        @SuppressWarnings("unchecked")
        Set<String> queries = (Set<String>) method.invoke(provider, "飞驰人生3");

        assertThat(queries).containsExactly("飞驰人生3");
    }

    private void whenBaseUrl(String baseUrl) {
        when(configService.tmdbBaseUrl()).thenReturn(baseUrl);
        when(configService.tmdbLanguage()).thenReturn("zh-CN");
    }

    private URI searchUri(FileNameGuess guess, String apiKey, String accessToken) throws Exception {
        Object credential = credential(apiKey, accessToken);
        boolean tv = guess.seasonNumber() != null;
        Method method = TmdbMetadataProvider.class.getDeclaredMethod(
                "searchUri",
                FileNameGuess.class,
                credential.getClass(),
                String.class,
                boolean.class,
                boolean.class
        );
        method.setAccessible(true);
        return (URI) method.invoke(provider, guess, credential, guess.title(), true, tv);
    }

    private Object credential(String apiKey, String accessToken) throws Exception {
        Class<?> type = Class.forName(TmdbMetadataProvider.class.getName() + "$TmdbCredential");
        Constructor<?> constructor = type.getDeclaredConstructor(String.class, String.class, int.class);
        constructor.setAccessible(true);
        return constructor.newInstance(apiKey, accessToken, apiVersion());
    }

    private int apiVersion() throws Exception {
        Method method = TmdbMetadataProvider.class.getDeclaredMethod("apiVersion");
        method.setAccessible(true);
        return (int) method.invoke(provider);
    }
}
