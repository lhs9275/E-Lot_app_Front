// lib/screens/mypage.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'package:psp2_fn/auth/token_storage.dart';
import 'favorite.dart';
import '../bottom_navbar.dart';
import '../map.dart';
import '../etc/report.dart';
import 'settings.dart';
import 'my_reservations.dart';
import '../../storage/report_history_storage.dart';

// --- 🎨 공통 디자인 상수 ---
const Color _bgColor = Color(0xFFF9FBFD);
const Color _primaryColor = Color(0xFF5F33DF);
const Color _cardColor = Colors.white;
const Color _textColor = Color(0xFF1A1A1A);
const Color _subTextColor = Color(0xFF8E929C);

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  String? _userName;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  /// 로그인 유저 정보 로드 (기존 로직 유지)
  Future<void> _loadUserInfo() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      await _loadKakaoFallback();
      return;
    }

    final baseUrl = dotenv.env['BACKEND_BASE_URL'] ?? 'https://clos21.kr';

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final name = (data['nickname'] ??
            data['name'] ??
            data['username'] ??
            data['userName'] ??
            '') as String;

        setState(() {
          _isLoggedIn = true;
          _userName = name.isNotEmpty ? name : null;
        });
        if (_userName == null) {
          await _loadKakaoFallback();
        }
      } else {
        setState(() {
          _isLoggedIn = true;
          _userName = null;
        });
        await _loadKakaoFallback();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoggedIn = true;
        _userName = null;
      });
      await _loadKakaoFallback();
    }
  }

  Future<void> _loadKakaoFallback() async {
    try {
      final user = await UserApi.instance.me();
      final nick = user.kakaoAccount?.profile?.nickname;
      if (!mounted) return;
      if (nick != null && nick.isNotEmpty) {
        setState(() {
          _isLoggedIn = true;
          _userName = nick;
        });
      } else {
        setState(() {
          _isLoggedIn = false;
          _userName = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoggedIn = false;
        _userName = null;
      });
    }
  }

  void _handleBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const MapScreen()),
      );
    }
  }

  // --- 화면 빌드 ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor, // 배경색 변경
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bgColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _textColor),
          onPressed: () => _handleBack(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 프로필 영역
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_rounded, size: 36, color: _primaryColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoggedIn ? (_userName ?? '사용자님') : '로그인이 필요합니다',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isLoggedIn ? '오늘도 안전 운전하세요!' : '서비스 이용을 위해 로그인해주세요.',
                          style: const TextStyle(fontSize: 13, color: _subTextColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                    icon: const Icon(Icons.settings_rounded, color: _subTextColor),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // 2. 퀵 메뉴 (카드형)
              Row(
                children: [
                  Expanded(
                    child: _QuickMenuCard(
                      icon: Icons.event_note_rounded,
                      label: '내 예약',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MyReservationsScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickMenuCard(
                      icon: Icons.star_rounded,
                      label: '즐겨찾기',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const FavoritesPage()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickMenuCard(
                      icon: Icons.emoji_events_rounded,
                      label: '랭킹',
                      onTap: () => Navigator.of(context).pushNamed('/ranking'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 3. 내 활동 섹션
              const Text(
                '내 활동',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textColor),
              ),
              const SizedBox(height: 12),
              _ListRow(
                icon: Icons.rate_review_rounded,
                iconColor: _primaryColor,
                title: '내가 쓴 리뷰',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyReviewsPage()),
                ),
              ),
              const SizedBox(height: 12),
              _ListRow(
                icon: Icons.history_rounded,
                iconColor: _primaryColor, // 통일감을 위해 색상 변경
                title: '신고 내역',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyReportsPage()),
                ),
              ),

              const SizedBox(height: 32),

              // 4. 고객센터 (필요시 추가)
              // 여기서는 디자인 깔끔하게 마무리
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MainBottomNavBar(currentIndex: 3),
    );
  }
}

/// 퀵 메뉴 카드 (디자인 개선)
class _QuickMenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickMenuCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: _primaryColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 리스트 메뉴 (디자인 개선)
class _ListRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _ListRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: _subTextColor),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// [내 리뷰 페이지] MyReviewsPage (디자인 리팩토링)
// -----------------------------------------------------------------------------

class _MyReview {
  final int id;
  final String stationName;
  final int rating;

  _MyReview({
    required this.id,
    required this.stationName,
    required this.rating,
  });

  factory _MyReview.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['reviewId']) as int;
    final name = (json['stationName'] ??
        json['stationTitle'] ??
        json['title'] ??
        '알 수 없는 충전소') as String;
    final rating = (json['rating'] as num?)?.toInt() ?? 0;

    return _MyReview(
      id: id,
      stationName: name,
      rating: rating,
    );
  }
}

class MyReviewsPage extends StatefulWidget {
  const MyReviewsPage({super.key});

  @override
  State<MyReviewsPage> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends State<MyReviewsPage> {
  bool _loading = true;
  String? _error;
  List<_MyReview> _reviews = [];

  @override
  void initState() {
    super.initState();
    _fetchMyReviews();
  }

  // --- 기능 로직 유지 ---
  Future<void> _fetchMyReviews() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '로그인이 필요합니다.';
      });
      return;
    }

    final baseUrl = dotenv.env['BACKEND_BASE_URL'] ?? 'https://clos21.kr';
    final uri = Uri.parse('$baseUrl/mapi/reviews/me');

    try {
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final List<dynamic> list =
        jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
        final items = list
            .map((e) => _MyReview.fromJson(e as Map<String, dynamic>))
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '리뷰를 불러오는 중 오류가 발생했습니다.';
      });
    }
  }

  Future<void> _deleteReview(_MyReview review) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('리뷰 삭제'),
        content: Text('"${review.stationName}" 리뷰를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final baseUrl = dotenv.env['BACKEND_BASE_URL'] ?? 'https://clos21.kr';
    final uri = Uri.parse('$baseUrl/api/reviews/${review.id}');

    try {
      final res = await http.delete(uri, headers: {'Authorization': 'Bearer $token'});

      if (!mounted) return;

      if (res.statusCode == 204 || res.statusCode == 200) {
        setState(() {
          _reviews.removeWhere((r) => r.id == review.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('리뷰가 삭제되었습니다.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패 (${res.statusCode})')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제 중 오류가 발생했습니다.')));
    }
  }

  Widget _buildStarRow(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return Icon(
          Icons.star_rounded,
          size: 18,
          color: filled ? const Color(0xFFFFD700) : Colors.grey.shade200, // Amber color
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('내가 쓴 리뷰', style: TextStyle(fontWeight: FontWeight.w700, color: _textColor)),
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _textColor),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: _subTextColor)))
          : _reviews.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rate_review_outlined, size: 48, color: _subTextColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('작성한 리뷰가 없습니다.', style: TextStyle(color: _subTextColor)),
          ],
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _reviews.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final review = _reviews[index];
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.ev_station_rounded, color: _primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        review.stationName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _textColor),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                      onPressed: () => _deleteReview(review),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStarRow(review.rating),
              ],
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// [내 신고 내역 페이지] MyReportsPage (디자인 리팩토링)
// -----------------------------------------------------------------------------

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  bool _loading = true;
  List<LocalReport> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final data = await ReportHistoryStorage.load();
    if (!mounted) return;
    setState(() {
      _reports = data;
      _loading = false;
    });
  }

  String _formatTs(int timestampMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}.${two(dt.month)}.${two(dt.day)}';
  }

  Future<void> _deleteReport(int index) async {
    await ReportHistoryStorage.removeAt(index);
    await _loadReports();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text('신고 내역', style: TextStyle(fontWeight: FontWeight.w700, color: _textColor)),
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _textColor),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : _reports.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.report_gmailerrorred_rounded, size: 48, color: _subTextColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('신고 내역이 없습니다.', style: TextStyle(color: _subTextColor)),
          ],
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final r = _reports[index];
          final station = r.stationName.isNotEmpty ? r.stationName : '정보 없음';
          final reason = r.reasonLabel.isNotEmpty ? r.reasonLabel : r.reasonCode;
          final tsText = _formatTs(r.timestampMs);

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('신고 접수', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                    Text(tsText, style: const TextStyle(fontSize: 12, color: _subTextColor)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _textColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '사유: $reason',
                            style: const TextStyle(fontSize: 14, color: _subTextColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: _subTextColor, size: 20),
                      onPressed: () => _deleteReport(index),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}