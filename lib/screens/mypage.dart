// lib/screens/mypage.dart
import 'package:flutter/material.dart';
import 'package:psp2_fn/auth/token_storage.dart';
import 'favorite.dart'; // ⭐ 즐겨찾기 페이지

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

  Future<void> _loadUserInfo() async {
    // accessToken 존재 여부만 체크
    final token = await TokenStorage.getAccessToken();
    // final name = await TokenStorage.getUserName(); // 나중에 카카오 이름 연동 시 사용

    if (!mounted) return;
    setState(() {
      _isLoggedIn = token != null && token.isNotEmpty;
      // _userName = name;
    });
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title 기능은 준비 중입니다.')),
    );
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
          onPressed: () => Navigator.maybePop(context),
          tooltip: '뒤로',
        ),
      ),

      body: SafeArea(
        top: false, // AppBar가 있어서 위쪽 SafeArea는 안 씀
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 상단 프로필 영역
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 프로필 아바타 (카카오 프로필 연동 전까지 기본 아이콘)
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
                    child: GestureDetector(
                      onTap: () {
                        // TODO: 로그인 / 내 정보 페이지로 이동
                      },
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
                  ),
                  IconButton(
                    onPressed: () {
                      // TODO: 설정 페이지로 이동
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

/// ⛏ 껍데기용: 내가 작성한 리뷰 리스트 화면
class MyReviewsPage extends StatelessWidget {
  const MyReviewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 리뷰'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.reviews_rounded, size: 40, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              '작성한 리뷰가 아직 없습니다.',
              style: txt.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '충전소/주차장 상세에서 리뷰를 남겨보세요.',
              style: txt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
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
      appBar: AppBar(
        title: const Text('신고 내역'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.report_problem_rounded, size: 40, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              '등록된 신고 내역이 없습니다.',
              style: txt.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '불편사항이 있다면 상세 화면에서 신고를 남겨주세요.',
              style: txt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
