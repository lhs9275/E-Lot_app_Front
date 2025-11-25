// lib/screens/favorites_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:psp2_fn/auth/token_storage.dart';

/// 즐겨찾기 아이템 모델 (stationId + stationName만 사용)
class FavoriteItem {
  final String id;   // stationId
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

  /// ✅ 백엔드에서 즐겨찾기 목록 불러오기
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
      final url =
      Uri.parse('$_backendBaseUrl/api/me/favorites/stations');
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget body;
    if (_isLoading) {
      body = const Center(
        child: CircularProgressIndicator(),
      );
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadFavorites,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
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
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _items.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: cs.outlineVariant),
          itemBuilder: (context, i) {
            final item = _items[i];
            return Dismissible(
              key: ValueKey(item.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.red.withOpacity(.85),
                child: const Icon(Icons.delete, color: Colors.white),
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
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.maybePop(context),
            tooltip: '뒤로',
          ),
          title: const Text('즐겨찾기'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: '새로고침',
              icon: const Icon(Icons.refresh),
              onPressed: _loadFavorites,
            ),
          ],
        ),
        body: body,
      ),
    );
  }
}

/// ✅ 빈 상태
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '즐겨 찾기 목록이 비었습니다',
              style: txt.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Icon(
            Icons.bookmark_border_rounded,
            size: 56,
            color: cs.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// 한 줄 타일 (stationName만 표시)
class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({required this.item, required this.onDelete});
  final FavoriteItem item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: cs.surfaceVariant,
        child: Icon(
          Icons.ev_station_rounded,
          color: cs.onSurfaceVariant,
        ),
      ),
      title: Text(
        item.name,
        style: txt.titleMedium
            ?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'ID: ${item.id}',
        style: txt.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      trailing: IconButton(
        tooltip: '삭제',
        icon: const Icon(Icons.delete_outline_rounded),
        onPressed: onDelete,
      ),
      onTap: () {
        // TODO: 나중에 이 stationId로 지도 이동 / 상세 연결 가능
      },
    );
  }
}
