import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 카카오페이 결제 WebView
/// 결제 완료 시 approval_url로 리다이렉트되면 pg_token을 추출해서 반환
class KakaoPayWebView extends StatefulWidget {
  final String paymentUrl;
  final String orderId;
  final bool allowBridgeNavigation;

  const KakaoPayWebView({
    super.key,
    required this.paymentUrl,
    required this.orderId,
    this.allowBridgeNavigation = false,
  });

  @override
  State<KakaoPayWebView> createState() => _KakaoPayWebViewState();
}

class _KakaoPayWebViewState extends State<KakaoPayWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('[KakaoPayWebView] Page started: $url');
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            debugPrint('[KakaoPayWebView] Page finished: $url');
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url;
            debugPrint('[KakaoPayWebView] Navigation request: $url');

            // 카카오톡 앱 실행 스킴 감지 (kakaotalk://)
            if (url.startsWith('kakaotalk://') ||
                url.startsWith('intent://')) {
              _launchExternalApp(url);
              return NavigationDecision.prevent;
            }

            // 커스텀 스킴 딥링크 감지 (psp2fn://)
            if (url.startsWith('psp2fn://')) {
              _handleDeepLink(url);
              return NavigationDecision.prevent;
            }

            // approval_url (pay/bridge 또는 api/payments/kakao/approve) 감지
            if (url.contains('/pay/bridge') ||
                url.contains('/api/payments/kakao/approve')) {
              if (widget.allowBridgeNavigation) {
                return NavigationDecision.navigate;
              }
              _handleApprovalUrl(url);
              return NavigationDecision.prevent;
            }

            // 취소/실패 URL 감지
            if (url.contains('/api/payments/kakao/cancel') ||
                url.contains('pay/cancel')) {
              Navigator.of(context).pop({'result': 'cancel', 'source': 'url'});
              return NavigationDecision.prevent;
            }
            if (url.contains('/api/payments/kakao/fail') ||
                url.contains('pay/fail')) {
              Navigator.of(context).pop({'result': 'fail', 'source': 'url'});
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            debugPrint('[KakaoPayWebView] Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  Future<void> _launchExternalApp(String url) async {
    debugPrint('[KakaoPayWebView] Launching external app: $url');
    try {
      final uri = Uri.parse(url);
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('[KakaoPayWebView] Cannot launch URL: $url');
        // 카카오톡이 설치되지 않은 경우 웹 결제로 진행
        if (url.contains('kakaotalk://')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('카카오톡이 설치되어 있지 않습니다.')),
          );
        }
      }
    } catch (e) {
      debugPrint('[KakaoPayWebView] Launch error: $e');
    }
  }

  void _handleDeepLink(String url) {
    debugPrint('[KakaoPayWebView] Deep link detected: $url');
    final uri = Uri.parse(url);
    final pgToken = uri.queryParameters['pg_token'];
    final orderId = uri.queryParameters['orderId'] ?? widget.orderId;

    if (uri.host == 'pay') {
      final path = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (path == 'success' && pgToken != null) {
        Navigator.of(context).pop({
          'result': 'success',
          'orderId': orderId,
          'pgToken': pgToken,
          'source': 'deeplink',
        });
      } else if (path == 'cancel') {
        Navigator.of(context).pop({'result': 'cancel', 'source': 'deeplink'});
      } else if (path == 'fail') {
        Navigator.of(context).pop({'result': 'fail', 'source': 'deeplink'});
      }
      return;
    }

    if (uri.host == 'payment-complete') {
      Navigator.of(context).pop({
        'result': 'success',
        'reservationId':
            uri.queryParameters['reservationId'] ?? uri.queryParameters['orderId'],
        'orderId': orderId,
        'source': 'deeplink',
      });
      return;
    }
    if (uri.host == 'payment-cancel') {
      Navigator.of(context).pop({
        'result': 'cancel',
        'reservationId':
            uri.queryParameters['reservationId'] ?? uri.queryParameters['orderId'],
        'orderId': orderId,
        'source': 'deeplink',
      });
      return;
    }
    if (uri.host == 'payment-fail') {
      Navigator.of(context).pop({
        'result': 'fail',
        'reservationId':
            uri.queryParameters['reservationId'] ?? uri.queryParameters['orderId'],
        'orderId': orderId,
        'source': 'deeplink',
      });
      return;
    }
  }

  void _handleApprovalUrl(String url) {
    debugPrint('[KakaoPayWebView] Approval URL detected: $url');
    final uri = Uri.parse(url);
    final pgToken = uri.queryParameters['pg_token'];
    final orderId = uri.queryParameters['orderId'] ?? widget.orderId;

    if (pgToken != null) {
      Navigator.of(context).pop({
        'result': 'success',
        'orderId': orderId,
        'pgToken': pgToken,
      });
    } else {
      // pg_token이 없으면 페이지 로드 (서버에서 처리)
      _controller.loadRequest(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('카카오페이 결제'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop({
            'result': 'cancel',
            'source': 'user_close',
          }),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
