import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_api.dart';
import '../auth/token_storage.dart';
import '../models/reservation.dart';

late final ReservationApiService reservationApi;

void configureReservationApi({required String baseUrl}) {
  reservationApi = ReservationApiService(baseUrl: baseUrl);
}

class KakaoPaymentReadyResult {
  final String orderId;
  final String paymentUrl;
  final String? tid;

  const KakaoPaymentReadyResult({
    required this.orderId,
    required this.paymentUrl,
    this.tid,
  });
}

class ReservationApiService {
  ReservationApiService({required this.baseUrl});

  final String baseUrl;

  Future<KakaoPaymentReadyResult> readyKakaoPay({
    required String orderId,
    required String itemName,
    required int totalAmount,
    String? approvalUrl,
    String? cancelUrl,
    String? failUrl,
  }) async {
    final normalizedBase =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse('$normalizedBase/api/payments/kakao/ready');

    final payload = <String, dynamic>{
      'orderId': orderId,
      'itemName': itemName,
      'totalAmount': totalAmount,
      'quantity': 1,
      'taxFreeAmount': 0,
      if (approvalUrl != null && approvalUrl.trim().isNotEmpty)
        'approvalUrl': approvalUrl.trim(),
      if (cancelUrl != null && cancelUrl.trim().isNotEmpty) 'cancelUrl': cancelUrl.trim(),
      if (failUrl != null && failUrl.trim().isNotEmpty) 'failUrl': failUrl.trim(),
    };

    http.Response response = await _postJsonWithAuth(uri, payload);
    if (response.statusCode == 401) {
      try {
        await AuthApi.refreshTokens();
        response = await _postJsonWithAuth(uri, payload);
      } catch (_) {
        // refresh 실패 시 아래에서 에러 처리
      }
    }

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      String? pick(Map<String, dynamic> map, List<String> keys) {
        for (final key in keys) {
          final value = map[key];
          if (value is String && value.trim().isNotEmpty) return value.trim();
        }
        return null;
      }

      final paymentUrl = pick(
        decoded,
        const [
          'next_redirect_mobile_url',
          'nextRedirectMobileUrl',
          'next_redirect_app_url',
          'nextRedirectAppUrl',
          'next_redirect_pc_url',
          'nextRedirectPcUrl',
        ],
      );
      if (paymentUrl == null) {
        throw Exception('결제 URL을 받지 못했습니다.');
      }
      return KakaoPaymentReadyResult(
        orderId: orderId,
        paymentUrl: paymentUrl,
        tid: pick(decoded, const ['tid']),
      );
    }

    throw Exception('결제 준비 실패: ${response.statusCode} ${response.body}');
  }

  Future<Reservation> getReservation(String reservationCode) async {
    final uri = _buildReservationDetailUri(reservationCode);
    http.Response response = await _getWithAuth(uri);
    if (response.statusCode == 401) {
      try {
        await AuthApi.refreshTokens();
        response = await _getWithAuth(uri);
      } catch (_) {}
    }
    if (response.statusCode == 200) {
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return Reservation.fromJson(decoded);
    }
    throw Exception('예약 정보를 불러오지 못했습니다: ${response.statusCode}');
  }

  Future<List<Reservation>> listMyReservations({String? status}) async {
    final uri = _buildMyReservationsUri(status: status);
    http.Response response = await _getWithAuth(uri);
    if (response.statusCode == 401) {
      try {
        await AuthApi.refreshTokens();
        response = await _getWithAuth(uri);
      } catch (_) {}
    }
    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(Reservation.fromJson)
            .toList();
      }
      return const [];
    }
    throw Exception('예약 목록을 불러오지 못했습니다: ${response.statusCode}');
  }

  Future<void> completeReservation(String reservationCode) async {
    final uri = _buildCompleteReservationUri(reservationCode);
    http.Response response = await _postWithAuth(uri);
    if (response.statusCode == 401) {
      try {
        await AuthApi.refreshTokens();
        response = await _postWithAuth(uri);
      } catch (_) {}
    }
    if (response.statusCode == 200) return;
    throw Exception('예약 완료 처리 실패: ${response.statusCode}');
  }

  /// 백엔드에 취소 엔드포인트가 별도로 없어서, 결제 취소 콜백 엔드포인트를 호출한다.
  /// (PAYMENT_PENDING 상태에서만 사용 권장)
  Future<void> cancelReservation(String reservationCode) async {
    final normalizedBase =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse('$normalizedBase/api/payments/kakao/cancel').replace(
      queryParameters: {'orderId': reservationCode},
    );
    http.Response response = await _getWithAuth(uri);
    if (response.statusCode == 401) {
      try {
        await AuthApi.refreshTokens();
        response = await _getWithAuth(uri);
      } catch (_) {}
    }
    if (response.statusCode == 200) return;
    throw Exception('예약 취소 처리 실패: ${response.statusCode}');
  }

  Future<void> markPaymentFailed(String reservationCode) async {
    final normalizedBase =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse('$normalizedBase/api/payments/kakao/fail').replace(
      queryParameters: {'orderId': reservationCode},
    );
    http.Response response = await _getWithAuth(uri);
    if (response.statusCode == 401) {
      try {
        await AuthApi.refreshTokens();
        response = await _getWithAuth(uri);
      } catch (_) {}
    }
    if (response.statusCode == 200) return;
    throw Exception('결제 실패 처리 실패: ${response.statusCode}');
  }

  Uri _buildMyReservationsUri({String? status}) {
    final normalizedBase =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final params = <String, String>{};
    if (status != null && status.trim().isNotEmpty) params['status'] = status.trim();
    return Uri.parse('$normalizedBase/mapi/reservations/me')
        .replace(queryParameters: params.isEmpty ? null : params);
  }

  Uri _buildReservationDetailUri(String reservationCode) {
    final normalizedBase =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$normalizedBase/mapi/reservations/$reservationCode');
  }

  Uri _buildCompleteReservationUri(String reservationCode) {
    final normalizedBase =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$normalizedBase/mapi/reservations/$reservationCode/complete');
  }

  Future<http.Response> _getWithAuth(Uri uri) async {
    final token = await TokenStorage.getAccessToken();
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return http.get(uri, headers: headers);
  }

  Future<http.Response> _postWithAuth(Uri uri) async {
    final token = await TokenStorage.getAccessToken();
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return http.post(uri, headers: headers);
  }

  Future<http.Response> _postJsonWithAuth(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final token = await TokenStorage.getAccessToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return http.post(uri, headers: headers, body: jsonEncode(body));
  }
}

