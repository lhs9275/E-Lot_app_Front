package kr.clos21.springbootdevelop.controller;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.MultiValueMap;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.UriComponentsBuilder;

/**
 * KakaoPay 등에서 HTTPS 리다이렉트 후 앱 스킴으로 재전달하기 위한 브리지 엔드포인트.
 * target 파라미터로 전달된 스킴(URL)에 나머지 쿼리 파라미터(orderId, pg_token 등)를 그대로 붙여서 이동한다.
 */
@RestController
@RequestMapping("/pay")
public class PayBridgeController {

    @GetMapping(value = "/bridge", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> bridge(
            @RequestParam(value = "target", required = false) String target,
            HttpServletRequest request) {
        if (target == null || target.isBlank()) {
            // target이 없으면 실패 페이지로 안내
            String body = """
                    <html><body>
                      <h3>Missing target</h3>
                      <p>target parameter is required.</p>
                    </body></html>
                    """;
            return ResponseEntity.badRequest().body(body);
        }

        // target을 제외한 나머지 쿼리 파라미터를 그대로 붙여줌 (orderId, pg_token 등)
        MultiValueMap<String, String> params =
                UriComponentsBuilder.fromUriString(request.getRequestURL().toString())
                        .query(request.getQueryString())
                        .build()
                        .getQueryParams();
        params.remove("target");

        UriComponentsBuilder builder = UriComponentsBuilder.fromUriString(target);
        params.forEach(builder::queryParam);
        String redirectTo = builder.build(true).toUriString();

        String body = """
                <html>
                  <head>
                    <meta http-equiv="refresh" content="0;url=%s" />
                    <script>
                      // JS 리다이렉트 (메타 태그 대비)
                      window.location.href = "%s";
                    </script>
                  </head>
                  <body>
                    <p>Redirecting to app...</p>
                  </body>
                </html>
                """.formatted(escape(redirectTo), escape(redirectTo));

        return ResponseEntity.ok().contentType(MediaType.TEXT_HTML).body(body);
    }

    private String escape(String input) {
        return input.replace("\"", "&quot;");
    }
}
