// lib/screens/mypage.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:psp2_fn/auth/token_storage.dart';
import 'favorite.dart'; // ⭐ 즐겨찾기 페이지
import 'bottom_navbar.dart'; // ✅ 공통 하단 네비게이션 바
import 'map.dart';

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

  /// ✅ 로그인 유저 정보(/api/me)에서 이름 가져오기
  Future<void> _loadUserInfo() async {
    final token = await TokenStorage.getAccessToken();

    // 토큰이 없으면 비로그인 상태
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoggedIn = false;
        _userName = null;
      });
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
        final data = jsonDecode(utf8.decode(res.bodyBytes))
        as Map<String, dynamic>;

        // 백엔드 실제 필드명에 맞게 순서 조정
        final name = (data['nickname'] ??
            data['name'] ??
            data['username'] ??
            data['userName'] ??
            '') as String;

        setState(() {
          _isLoggedIn = true;
          _userName = name.isNotEmpty ? name : null;
        });
      } else {
        // 이름만 못 가져온 경우
        setState(() {
          _isLoggedIn = true;
          _userName = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoggedIn = true;
        _userName = null;
      });
    }
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title 기능은 준비 중입니다.')),
    );
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),

      /// 🔙 상단 뒤로가기 버튼
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF5F5F7),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => _handleBack(context),
          tooltip: '뒤로',
        ),
      ),

      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 상단 프로필 영역
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 36,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoggedIn
                              ? (_userName ?? '로그인 사용자')
                              : '로그인 후 이용해 주세요',
                          style: txt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isLoggedIn
                              ? '카카오 계정으로 로그인됨'
                              : '카카오 로그인으로 시작하기 >',
                          style: txt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // TODO: 설정 페이지
                    },
                    icon: const Icon(Icons.settings_outlined),
                    splashRadius: 22,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              /// 상단 3개 카드: 내 예약 / 즐겨찾기 / 랭킹
              Row(
                children: [
                  Expanded(
                    child: _QuickMenuCard(
                      icon: Icons.event_note_rounded,
                      label: '내 예약',
                      onTap: () => _showComingSoon('내 예약'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickMenuCard(
                      icon: Icons.star_rounded,
                      label: '즐겨찾기',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FavoritesPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickMenuCard(
                      icon: Icons.emoji_events_rounded,
                      label: '랭킹',
                      onTap: () => _showComingSoon('랭킹'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              /// 섹션 1: 내 활동(리뷰)
              Text(
                '내 활동',
                style: txt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _ListRow(
                icon: Icons.reviews_rounded,
                iconColor: cs.primary,
                title: '내 리뷰',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyReviewsPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              /// 섹션 2: 고객센터(신고)
              Text(
                '고객센터',
                style: txt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _ListRow(
                icon: Icons.report_problem_rounded,
                iconColor: Colors.redAccent,
                title: '신고',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyReportsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),

      /// ✅ 하단 네비게이션 바
      bottomNavigationBar: const MainBottomNavBar(currentIndex: 3),
    );
  }
}

/// 상단 3개 카드용 위젯
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
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: cs.primary),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: txt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 리스트 형태 메뉴(내 리뷰 / 신고)
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
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: txt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 🔹 내 리뷰 1개 데이터 (충전소 이름 + 별점 + ID)
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

/// ⛏ 내 리뷰 목록 화면 (충전소 이름 + 별점, 삭제 가능)
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
        content: Text(
          '"${review.stationName}"에 대한 리뷰를 삭제하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final baseUrl = dotenv.env['BACKEND_BASE_URL'] ?? 'https://clos21.kr';
    final uri = Uri.parse('$baseUrl/api/reviews/${review.id}');

    try {
      final res = await http.delete(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (res.statusCode == 204 || res.statusCode == 200) {
        setState(() {
          _reviews.removeWhere((r) => r.id == review.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰가 삭제되었습니다.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패 (${res.statusCode})')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제 중 오류가 발생했습니다.')),
      );
    }
  }

  Widget _buildStarRow(int rating) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          size: 18,
          color: filled ? cs.secondary : cs.onSurfaceVariant,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('내 리뷰')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Text(
          _error!,
          style: txt.bodyMedium,
        ),
      )
          : _reviews.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.reviews_rounded,
              size: 40,
              color: cs.primary,
            ),
            const SizedBox(height: 12),
            Text(
              '작성한 리뷰가 아직 없습니다.',
              style: txt.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '충전소/주차장 상세에서 리뷰를 남겨보세요.',
              style: txt.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _reviews.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final review = _reviews[index];
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            elevation: 1,
            shadowColor: Colors.black.withOpacity(0.03),
            child: ListTile(
              leading: const Icon(Icons.ev_station_outlined),
              title: Text(
                review.stationName,
                style: txt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: _buildStarRow(review.rating),
              trailing: IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                onPressed: () => _deleteReview(review),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ⛏ 껍데기용: 내가 작성한 신고 리스트 화면
class MyReportsPage extends StatelessWidget {
  const MyReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('신고 내역')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.report_problem_rounded, size: 40, color: Colors.red),
            const SizedBox(height: 12),
            Text('등록된 신고 내역이 없습니다.', style: txt.bodyMedium),
            const SizedBox(height: 4),
            Text(
              '불편사항이 있다면 상세 화면에서 신고를 남겨주세요.',
              style:
              txt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
