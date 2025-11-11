// lib/screens/favorites_page.dart
import 'package:flutter/material.dart';

/// 즐겨찾기 아이템 모델
class FavoriteItem {
  final String id; // Dismissible 키용
  final String name;
  final String? address;
  final String? thumbnailUrl;

  const FavoriteItem({
    required this.id,
    required this.name,
    this.address,
    this.thumbnailUrl,
  });

  FavoriteItem copyWith({
    String? id,
    String? name,
    String? address,
    String? thumbnailUrl,
  }) =>
      FavoriteItem(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      );
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final List<FavoriteItem> _items = [];

  /// ✅ 이 페이지 전용 스캐폴드 메신저 (루트와 분리)
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
  GlobalKey<ScaffoldMessengerState>();

  /// ✅ FAB이 안 움직이는 떠있는 스낵바
  void _showStatus(String message, {SnackBarAction? action}) {
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    _messengerKey.currentState?.hideCurrentSnackBar();
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomSafe + 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        action: action,
      ),
    );
  }

  // 추가 다이얼로그
  Future<void> _addFavoriteDialog() async {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final thumbCtrl = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final insets = MediaQuery.of(ctx).viewInsets;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + insets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '즐겨찾기 추가',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: '이름 (필수)',
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: cs.primary),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addrCtrl,
                decoration: const InputDecoration(
                  labelText: '주소 (선택)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: thumbCtrl,
                decoration: const InputDecoration(
                  labelText: '썸네일 URL (선택)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty) return;
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('추가'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (ok == true && mounted) {
      setState(() {
        _items.add(
          FavoriteItem(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: nameCtrl.text.trim(),
            address:
            addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(),
            thumbnailUrl:
            thumbCtrl.text.trim().isEmpty ? null : thumbCtrl.text.trim(),
          ),
        );
      });
      _showStatus('즐겨찾기에 추가되었습니다.');
    }
  }

  void _deleteAt(int index) {
    final removed = _items.removeAt(index);
    setState(() {});
    _showStatus(
      '"${removed.name}" 을(를) 삭제했습니다.',
      action: SnackBarAction(
        label: '되돌리기',
        onPressed: () {
          setState(() {
            _items.insert(index, removed);
          });
        },
      ),
    );
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

    return ScaffoldMessenger( // ✅ 루트와 분리된 Messenger
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
        ),
        body: _items.isEmpty
            ? const _EmptyState()
            : ListView.separated(
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
                onDelete: () => _deleteAt(i),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addFavoriteDialog,
          icon: const Icon(Icons.add_rounded),
          label: const Text('추가'),
        ),
      ),
    );
  }
}

/// ✅ 빈 상태 (아이콘 → 내 이미지로 교체)
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
              '즐겨 찾는 주차장이 없습니다',
              style: txt.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'lib/assets/icons/app_icon/bookmark_icon.png', // 네 이미지 경로
              width: 72,
              height: 72,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return Icon(Icons.map_rounded, size: 56, color: cs.onSurface);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 한 줄 타일 (썸네일 없는 경우 기존 아이콘 유지)
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
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: item.thumbnailUrl == null
            ? Container(
          width: 54,
          height: 54,
          color: cs.surfaceVariant.withOpacity(.4),
          child: Icon(Icons.local_parking_rounded,
              color: cs.onSurfaceVariant),
        )
            : Image.network(
          item.thumbnailUrl!,
          width: 54,
          height: 54,
          fit: BoxFit.cover,
        ),
      ),
      title: Text(
        item.name,
        style:
        txt.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      subtitle: item.address == null
          ? null
          : Text(
        item.address!,
        style: txt.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontSize: 13.5,
        ),
      ),
      trailing: IconButton(
        tooltip: '삭제',
        icon: const Icon(Icons.delete_outline_rounded),
        onPressed: onDelete,
      ),
      onTap: () {
        // TODO: 상세 페이지로 이동 연결
      },
    );
  }
}
