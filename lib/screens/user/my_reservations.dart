import 'package:flutter/material.dart';

import '../../auth/token_storage.dart';
import '../../models/reservation.dart';
import '../../services/reservation_api_service.dart';
import '../bottom_navbar.dart';

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  // --- 상태 변수 (기능 유지) ---
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Reservation> _items = const [];

  // --- 🎨 디자인 컬러 상수 ---
  final Color _bgColor = const Color(0xFFF9FBFD);
  final Color _primaryColor = const Color(0xFF5F33DF);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF1A1A1A);
  final Color _subTextColor = const Color(0xFF8E929C);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // --- 기능 로직 (100% 원본 유지) ---
  Future<void> _refresh({bool allowWhileBusy = false}) async {
    if (_busy && !allowWhileBusy) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '로그인이 필요합니다.';
        _items = const [];
      });
      return;
    }

    try {
      final items = await reservationApi.listMyReservations();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '예약 목록을 불러오지 못했습니다.';
        _items = const [];
      });
    }
  }

  Future<void> _cancelReservation(Reservation reservation) async {
    if (_busy) return;
    final canCancel = _canCancel(reservation);
    if (!canCancel) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('예약 취소'),
        content: const Text('결제를 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('취소하기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await reservationApi.cancelReservation(reservation.reservationCode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('취소 요청이 처리되었습니다.')),
      );
      await _refresh(allowWhileBusy: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('취소 처리 중 오류가 발생했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _canCancel(Reservation reservation) {
    return reservation.reservationStatus == 'PAYMENT_PENDING' ||
        reservation.reservationStatus == 'REQUESTED';
  }

  String _formatCurrency(int amount) {
    final raw = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
      buffer.write(raw[i]);
    }
    return '${buffer.toString()}원';
  }

  Color _statusColor(Reservation reservation) {
    final status = reservation.reservationStatus;
    if (status == 'PAID') return Colors.green;
    if (status == 'USED') return Colors.blue;
    if (status == 'PAYMENT_PENDING') return Colors.orange;
    if (status == 'CANCELLED') return Colors.redAccent;
    if (status == 'EXPIRED') return Colors.grey;
    if (status == 'REFUNDING') return Colors.deepOrange;
    if (status == 'REFUNDED') return Colors.red;
    return _subTextColor;
  }

  String _statusLabel(Reservation reservation) {
    return reservation.reservationStatusLabel ??
        reservation.paymentStatusLabel ??
        reservation.reservationStatus ??
        reservation.paymentStatus ??
        '상태 없음';
  }

  // --- UI 구현 (디자인 리팩토링) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          '내 예약',
          style: TextStyle(fontWeight: FontWeight.w800, color: _textColor),
        ),
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _textColor),
        actions: [
          IconButton(
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: _primaryColor,
        child: _buildBody(),
      ),
      bottomNavigationBar: const MainBottomNavBar(currentIndex: 2),
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
            Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.redAccent.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: _subTextColor)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _refresh(allowWhileBusy: true),
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
      );
    }
    if (_items.isEmpty) {
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
              child: Icon(Icons.event_note_rounded,
                  size: 48, color: _primaryColor.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            Text(
              '예약 내역이 없습니다.',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16, color: _textColor),
            ),
            const SizedBox(height: 6),
            Text(
              '충전소나 주차장을 예약해보세요.',
              style: TextStyle(color: _subTextColor),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildReservationCard(_items[index]);
      },
    );
  }

  Widget _buildReservationCard(Reservation item) {
    final amount = item.totalAmount;
    final statusColor = _statusColor(item);
    final canCancel = _canCancel(item);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 아이콘 + 이름 + 상태 태그
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                Icon(Icons.confirmation_number_rounded, color: _primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName ?? item.reservationCode,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '코드: ${item.reservationCode}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(item),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
          ),

          // 하단: 금액 + 취소 버튼
          Row(
            children: [
              if (amount != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '결제 금액',
                      style: TextStyle(fontSize: 11, color: _subTextColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatCurrency(amount),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: _textColor,
                      ),
                    ),
                  ],
                )
              else
                Text('금액 정보 없음', style: TextStyle(color: _subTextColor)),

              const Spacer(),

              if (canCancel)
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _cancelReservation(item),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text(
                      '예약 취소',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}