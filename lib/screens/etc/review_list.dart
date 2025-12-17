import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:psp2_fn/auth/token_storage.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'report.dart';
import 'review.dart';

class ReviewListPage extends StatefulWidget {
  const ReviewListPage({
    super.key,
    required this.stationId,
    required this.stationName,
  });

  final String stationId;
  final String stationName;

  @override
  State<ReviewListPage> createState() => _ReviewListPageState();
}

class _ReviewListPageState extends State<ReviewListPage> {
  bool _loading = true;
  String? _error;
  List<_ReviewItem> _reviews = [];
  String? _kakaoNick;

  // --- 🎨 디자인 컬러 상수 ---
  final Color _bgColor = const Color(0xFFF9FBFD);
  final Color _primaryColor = const Color(0xFF5F33DF);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF1A1A1A);
  final Color _subTextColor = const Color(0xFF8E929C);

  @override
  void initState() {
    super.initState();
    _loadKakaoName();
    _fetchReviews();
  }

  // --- 기능 로직 (기존 코드 유지) ---
  Future<void> _loadKakaoName() async {
    try {
      final user = await UserApi.instance.me();
      final nick = user.kakaoAccount?.profile?.nickname;
      if (!mounted) return;
      if (nick != null && nick.isNotEmpty) {
        setState(() => _kakaoNick = nick);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _fetchReviews() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final baseUrl = dotenv.env['BACKEND_BASE_URL'] ?? 'https://clos21.kr';
    final uri = Uri.parse('$baseUrl/api/stations/${widget.stationId}/reviews');

    try {
      final token = await TokenStorage.getAccessToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final res = await http.get(uri, headers: headers);
      if (!mounted) return;

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        List<dynamic> raw;
        if (decoded is List<dynamic>) {
          raw = decoded;
        } else if (decoded is Map<String, dynamic> &&
            decoded['content'] is List<dynamic>) {
          raw = decoded['content'] as List<dynamic>;
        } else {
          raw = const [];
        }
        final items = raw
            .map((e) => _ReviewItem.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _reviews = items;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = '리뷰를 불러오지 못했습니다. (${res.statusCode})';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '리뷰를 불러오는 중 오류가 발생했습니다.';
      });
    }
  }

  Future<void> _reportReview(_ReviewItem review) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ReportPage(reviewId: review.id, stationName: widget.stationName),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
    }
  }

  // --- UI 구현 (디자인 리팩토링) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          '리뷰 목록',
          style: TextStyle(fontWeight: FontWeight.w800, color: _textColor),
        ),
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _textColor),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _fetchReviews,
            icon: const Icon(Icons.refresh_rounded),
          ),
          // 리뷰 작성 버튼을 앱바에서도 접근 가능하게 유지
          IconButton(
            tooltip: '리뷰 작성',
            onPressed: _openWritePage,
            icon: const Icon(Icons.rate_review_rounded),
          ),
        ],
      ),
      body: _buildBody(),
      // 플로팅 버튼으로 리뷰 작성 강조 (선택 사항, 없어도 됨)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openWritePage,
        backgroundColor: _primaryColor,
        icon: const Icon(Icons.edit, color: Colors.white),
        label: const Text('리뷰 쓰기', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: _primaryColor));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: _subTextColor)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _fetchReviews,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryColor,
                side: BorderSide(color: _primaryColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.rate_review_outlined, size: 48, color: _primaryColor.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            Text('아직 등록된 리뷰가 없습니다.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _textColor)),
            const SizedBox(height: 6),
            Text('가장 먼저 리뷰를 남겨보세요!', style: TextStyle(color: _subTextColor)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100), // 하단 FAB 공간 확보
      itemCount: _reviews.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final r = _reviews[index];
        return _buildReviewCard(r);
      },
    );
  }

  Widget _buildReviewCard(_ReviewItem r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 프로필 + 이름 + 날짜 + 신고
          Row(
            children: [
              // 프로필 아바타 (디자인 요소 추가)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_rounded, color: _primaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.maskedAuthorName(fallbackName: _kakaoNick),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.createdAt ?? '날짜 정보 없음',
                      style: TextStyle(
                        fontSize: 12,
                        color: _subTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '신고하기',
                icon: Icon(Icons.more_horiz_rounded, color: _subTextColor),
                onPressed: () => _reportReview(r),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 별점
          _buildStars(r.rating),

          const SizedBox(height: 10),

          // 리뷰 내용
          Text(
            r.content,
            style: TextStyle(
              fontSize: 15,
              color: _textColor,
              height: 1.5, // 줄간격 확보로 가독성 향상
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_rounded, // 꽉 찬 별/빈 별 모양 통일
          size: 20,
          color: filled ? const Color(0xFFFFD700) : Colors.grey.shade200, // Amber vs 연회색
        );
      }),
    );
  }
}

// --- 아래 기능 클래스 및 확장은 건드리지 않음 ---

class _ReviewItem {
  _ReviewItem({
    required this.id,
    required this.authorName,
    required this.rating,
    required this.content,
    this.createdAt,
  });

  final int id;
  final String authorName;
  final int rating;
  final String content;
  final String? createdAt;

  String maskedAuthorName({String? fallbackName}) {
    final normalized = _stripEmailDomain(authorName).trim();
    final effective = _shouldUseFallback(normalized) &&
        fallbackName != null &&
        fallbackName.trim().isNotEmpty
        ? fallbackName.trim()
        : normalized;
    if (effective.isEmpty) return '익명';

    final runes = effective.runes.toList();
    final len = runes.length;
    if (len == 1) return '*';
    if (len == 2) {
      return '${String.fromCharCode(runes.first)}*';
    }
    final first = String.fromCharCode(runes.first);
    final last = String.fromCharCode(runes.last);
    final middle = List.filled(len - 2, '*').join();
    return '$first$middle$last';
  }

  String _stripEmailDomain(String raw) {
    final at = raw.indexOf('@');
    if (at <= 0) return raw;
    return raw.substring(0, at);
  }

  bool _shouldUseFallback(String raw) {
    if (raw.isEmpty) return true;
    if (raw.contains('@')) return true;
    return false;
  }

  factory _ReviewItem.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'] ?? json['reviewId'] ?? 0;
    final ratingRaw = json['rating'] ?? json['score'] ?? 0;
    final contentRaw =
        json['content'] ?? json['text'] ?? json['comment'] ?? '내용이 없습니다.';
    final authorRaw = _pickAuthorName(json);
    final createdRaw =
        json['createdAt'] ??
            json['createdDate'] ??
            json['writtenAt'] ??
            json['regDt'];

    return _ReviewItem(
      id: (idRaw is num) ? idRaw.toInt() : int.tryParse(idRaw.toString()) ?? 0,
      authorName: authorRaw.toString(),
      rating: (ratingRaw is num)
          ? ratingRaw.toInt().clamp(0, 5)
          : int.tryParse(ratingRaw.toString())?.clamp(0, 5) ?? 0,
      content: contentRaw.toString(),
      createdAt: createdRaw?.toString(),
    );
  }

  static String _pickAuthorName(Map<String, dynamic> json) {
    String? emailFallback;

    String? pickFromMap(Map<String, dynamic>? map) {
      if (map == null) return null;
      final nameKeys = [
        'name',
        'realName',
        'userRealName',
        'displayName',
        'userDisplayName',
        'authorName',
        'writerName',
        'nickname',
        'nickName',
        'userName',
      ];
      for (final key in nameKeys) {
        final value = _stringOrNull(map[key]);
        if (value == null) continue;
        if (value.contains('@')) {
          emailFallback ??= value;
          continue;
        }
        return value;
      }
      final emailKeys = ['writerEmail', 'email'];
      for (final key in emailKeys) {
        final value = _stringOrNull(map[key]);
        if (value == null) continue;
        emailFallback ??= value;
      }
      return null;
    }

    final mapsToCheck = <Map<String, dynamic>?>[
      json,
      json['writer'] is Map<String, dynamic> ? json['writer'] as Map<String, dynamic> : null,
      json['author'] is Map<String, dynamic> ? json['author'] as Map<String, dynamic> : null,
      json['user'] is Map<String, dynamic> ? json['user'] as Map<String, dynamic> : null,
      json['member'] is Map<String, dynamic> ? json['member'] as Map<String, dynamic> : null,
    ];

    for (final map in mapsToCheck) {
      final picked = pickFromMap(map);
      if (picked != null) return picked;
    }

    return emailFallback ?? '익명';
  }

  static String? _stringOrNull(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return s;
  }
}

extension on _ReviewListPageState {
  Future<void> _openWritePage() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReviewPage(
          stationId: widget.stationId,
          placeName: widget.stationName,
        ),
      ),
    );
    if (result == true && mounted) {
      await _fetchReviews();
    }
  }
}