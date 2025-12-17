// lib/screens/favorites_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:psp2_fn/auth/token_storage.dart';
import '../bottom_navbar.dart';
import '../map.dart';

/// 즐겨찾기 아이템 모델 (stationId + stationName만 사용)
class FavoriteItem {
  final String id; // stationId
  final String name; // stationName

  const FavoriteItem({
    required this.id,
    required this.name,
  });
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  // --- 🎨 디자인 컬러 상수 ---
  final Color _bgColor = const Color(0xFFF9FBFD);
  final Color _primaryColor = const Color(0xFF5F33DF);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF1A1A1A);
  final Color _subTextColor = const Color(0xFF8E929C);

  /// ✅ 백엔드 기본 주소 (MapScreen과 동일)
  static const String _backendBaseUrl = 'https://clos21.kr';

  final List<FavoriteItem> _items = [];

  /// 로딩 / 에러 상태
  bool _isLoading = false;
  String? _error;

  /// ✅ 이 페이지 전용 스캐폴드 메신저 (루트와 분리)
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
  GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _loadFavorites(); // 페이지 진입 시 즐겨찾기 목록 불러오기
  }

  /// ✅ 백엔드에서 즐겨찾기 목록 불러오기 (기능 유지)
  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // 토큰 가져오기
    String? accessToken = await TokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = '로그인 후 즐겨찾기 목록을 볼 수 있습니다.';
      });
      return;
    }

    try {
      // 🔹 실제 컨트롤러: @GetMapping("/me/favorites/stations")
      final url = Uri.parse('$_backendBaseUrl/api/me/favorites/stations');
      final res = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      debugPrint('⭐ 즐겨찾기 목록 GET 결과: ${res.statusCode} ${res.body}');

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);

        // FavoriteStationController에서 List<FavoriteStationDto> 를 그대로 반환하므로
        // body 자체가 List 일 확률이 높음
        if (body is! List) {
          setState(() {
            _isLoading = false;
            _error = '서버 응답 형식이 올바르지 않습니다.';
          });
          return;
        }

        final list = body as List<dynamic>;

        final items = list.map<FavoriteItem>((raw) {
          final map = raw as Map<String, dynamic>;

          // ⚠️ FavoriteStationDto 필드에 맞게 키 이름 조정
          //    (stationId, stationName 이라고 가정)
          final stationId = (map['stationId'] ?? map['id'] ?? '').toString();
          final name =
          (map['stationName'] ?? map['name'] ?? '이름 없음').toString();

          return FavoriteItem(
            id: stationId,
            name: name,
          );
        }).toList();

        setState(() {
          _items
            ..clear()
            ..addAll(items);
          _isLoading = false;
        });
      } else if (res.statusCode == 401) {
        setState(() {
          _isLoading = false;
          _error = '로그인이 만료되었습니다. 다시 로그인해주세요.';
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = '즐겨찾기 목록을 불러오지 못했습니다. (${res.statusCode})';
        });
      }
    } catch (e) {
      debugPrint('❌ 즐겨찾기 목록 불러오는 중 오류: $e');
      setState(() {
        _isLoading = false;
        _error = '오류가 발생했습니다: $e';
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

  /// ✅ 이 페이지 전용 떠있는 스낵바
  void _showStatus(String message) {
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    _messengerKey.currentState?.hideCurrentSnackBar();
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomSafe + 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// ✅ 휴지통 / 스와이프 시: 서버에 DELETE 날리고, 성공하면 목록에서 제거
  Future<void> _deleteAt(int index) async {
    final item = _items[index];

    String? accessToken = await TokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      _showStatus('로그인 후 삭제할 수 있습니다.');
      return;
    }

    try {
      final url = Uri.parse(
          '$_backendBaseUrl/api/stations/${item.id}/favorite'); // 컨트롤러와 동일
      final res = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      debugPrint('🗑 즐겨찾기 삭제 결과: ${res.statusCode} ${res.body}');

      if (res.statusCode == 200 || res.statusCode == 204) {
        setState(() {
          _items.removeAt(index);
        });
        _showStatus('"${item.name}" 즐겨찾기에서 제거되었습니다.');
      } else {
        _showStatus('삭제 실패 (${res.statusCode}) 다시 시도해주세요.');
      }
    } catch (e) {
      debugPrint('❌ 즐겨찾기 삭제 중 오류: $e');
      _showStatus('삭제 중 오류가 발생했습니다.');
    }
  }

  @override
  void dispose() {
    // 페이지를 떠날 때 이 페이지 스낵바들만 정리 (루트에는 영향 X)
    _messengerKey.currentState?.clearSnackBars();
    super.dispose();
  }

  // --- UI 구현 (디자인 리팩토링) ---
  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_isLoading) {
      body = Center(
        child: CircularProgressIndicator(color: _primaryColor),
      );
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent.withOpacity(0.6)),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _subTextColor),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loadFavorites,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryColor,
                  side: BorderSide(color: _primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    } else if (_items.isEmpty) {
      body = const _EmptyState();
    } else {
      body = RefreshIndicator(
        onRefresh: _loadFavorites,
        color: _primaryColor,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12), // 구분선 대신 간격 사용
          itemBuilder: (context, i) {
            final item = _items[i];
            return Dismissible(
              key: ValueKey(item.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
              ),
              onDismissed: (_) => _deleteAt(i),
              child: _FavoriteTile(
                item: item,
                onDelete: () => _deleteAt(i), // 휴지통 버튼도 같은 로직 사용
              ),
            );
          },
        ),
      );
    }

    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _textColor),
            onPressed: () => _handleBack(context),
            tooltip: '뒤로',
          ),
          title: Text(
            '즐겨찾기',
            style: TextStyle(fontWeight: FontWeight.w800, color: _textColor),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: '새로고침',
              icon: Icon(Icons.refresh_rounded, color: _textColor),
              onPressed: _loadFavorites,
            ),
          ],
        ),
        body: body,
        bottomNavigationBar: const MainBottomNavBar(currentIndex: 1),
      ),
    );
  }
}

/// ✅ 빈 상태 (디자인 개선)
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF5F33DF).withOpacity(0.06), // 연한 보라색 배경
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star_border_rounded,
              size: 56,
              color: Color(0xFF5F33DF), // 보라색 아이콘
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '즐겨찾기 목록이 비었습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '자주 가는 충전소를 즐겨찾기에 추가해보세요!',
            style: TextStyle(color: Color(0xFF8E929C)),
          ),
        ],
      ),
    );
  }
}

/// 한 줄 타일 (stationName만 표시) - 카드형 디자인 (개선됨)
class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({required this.item, required this.onDelete});
  final FavoriteItem item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // 둥근 모서리
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // 부드러운 그림자
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 아이콘 (보라색 포인트)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF5F33DF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.star_rounded, color: Color(0xFF5F33DF), size: 24),
          ),
          const SizedBox(width: 16),
          // 텍스트 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${item.id}',
                  style: const TextStyle(
                    color: Color(0xFF8E929C),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // 삭제 버튼
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}