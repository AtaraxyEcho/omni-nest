package com.omninest.modules.user.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.omninest.common.ratelimit.RateLimitService;
import com.omninest.common.security.BrowserSecurityPolicy;
import com.omninest.common.security.ClientIpResolver;
import com.omninest.common.security.RegistrationPolicy;
import com.omninest.modules.user.dto.AuthTokenResponse;
import com.omninest.modules.user.dto.AuthUserDto;
import com.omninest.modules.user.dto.LoginRequest;
import com.omninest.modules.user.service.AuthService;
import java.time.Duration;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import tools.jackson.databind.ObjectMapper;

class AuthControllerCookieTest {
    private final AuthService authService = mock(AuthService.class);
    private final BrowserSecurityPolicy browserSecurityPolicy = mock(BrowserSecurityPolicy.class);
    private final RateLimitService rateLimitService = mock(RateLimitService.class);
    private final RegistrationPolicy registrationPolicy = mock(RegistrationPolicy.class);
    private final ClientIpResolver clientIpResolver = mock(ClientIpResolver.class);
    private final ObjectMapper objectMapper = new ObjectMapper();

    private AuthController controller;
    private AuthTokenResponse token;

    @BeforeEach
    void setUp() {
        controller = new AuthController(
                authService,
                browserSecurityPolicy,
                rateLimitService,
                registrationPolicy,
                clientIpResolver
        );
        token = tokenResponse();
        when(rateLimitService.tryAcquire(anyString(), anyInt(), any(Duration.class))).thenReturn(true);
        when(clientIpResolver.resolve(anyString(), any(), any())).thenReturn("203.0.113.8");
        when(authService.login(any(LoginRequest.class), anyString(), anyString(), anyString(), anyString(), anyString()))
                .thenReturn(token);
    }

    @Test
    void webLoginWritesHttpOnlyCookieAndOmitsRefreshTokenFromBody() throws Exception {
        MockHttpServletResponse servletResponse = new MockHttpServletResponse();

        var response = controller.login(
                new LoginRequest("root", "secret"),
                "web",
                "browser-1",
                "Chrome",
                request(),
                servletResponse
        );

        assertThat(response.getData().refreshToken()).isNull();
        assertThat(objectMapper.writeValueAsString(response)).doesNotContain("refreshToken");
        assertThat(servletResponse.getHeader(HttpHeaders.SET_COOKIE))
                .contains("omninest_refresh_token=refresh-token")
                .contains("HttpOnly")
                .contains("SameSite=Strict");
    }

    @Test
    void nativeLoginKeepsRefreshTokenInBodyAndDoesNotWriteCookie() {
        MockHttpServletResponse servletResponse = new MockHttpServletResponse();

        var response = controller.login(
                new LoginRequest("root", "secret"),
                "android",
                "phone-1",
                "Pixel",
                request(),
                servletResponse
        );

        assertThat(response.getData().refreshToken()).isEqualTo("refresh-token");
        assertThat(servletResponse.getHeader(HttpHeaders.SET_COOKIE)).isNull();
    }

    private MockHttpServletRequest request() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("127.0.0.1");
        request.addHeader("User-Agent", "test-agent");
        return request;
    }

    private AuthTokenResponse tokenResponse() {
        AuthUserDto user = new AuthUserDto(
                UUID.fromString("10000000-0000-0000-0000-000000000001"),
                "root",
                "Root",
                null,
                "root@example.com",
                "ACTIVE",
                "SUPER_ADMIN",
                Set.of("SUPER_ADMIN"),
                Set.of("system:config:manage"),
                1024,
                0
        );
        return new AuthTokenResponse(
                "Bearer",
                "access-token",
                "2026-08-24T12:30:00Z",
                "refresh-token",
                "2026-09-24T12:00:00Z",
                user
        );
    }
}
