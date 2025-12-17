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
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Reservation> _items = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

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

    final confirmed =
        await showDialog<bool>(
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
                child: const Text('취소하기'),
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

  Color _statusColor(Reservation reservation, ColorScheme cs) {
    final status = reservation.reservationStatus;
    if (status == 'PAID') return Colors.green;
    if (status == 'USED') return Colors.blue;
    if (status == 'PAYMENT_PENDING') return Colors.orange;
    if (status == 'CANCELLED') return Colors.redAccent;
    if (status == 'EXPIRED') return Colors.grey;
    if (status == 'REFUNDING') return Colors.deepOrange;
    if (status == 'REFUNDED') return Colors.red;
    return cs.onSurfaceVariant;
  }

  String _statusLabel(Reservation reservation) {
    return reservation.reservationStatusLabel ??
        reservation.paymentStatusLabel ??
        reservation.reservationStatus ??
        reservation.paymentStatus ??
        '상태 없음';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 예약'),
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          _error!,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 120),
                          Center(
                            child: Text(
                              '예약 내역이 없습니다.',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final amount = item.totalAmount;
                          final statusColor = _statusColor(item, cs);
                          final canCancel = _canCancel(item);

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                  color: Colors.black.withOpacity(0.06),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.itemName ??
                                            item.reservationCode,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        _statusLabel(item),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (amount != null)
                                  Text(
                                    '금액: ${_formatCurrency(amount)}',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  '코드: ${item.reservationCode}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                if (canCancel) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _cancelReservation(item),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                      ),
                                      child: const Text('취소'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
      ),
      bottomNavigationBar: const MainBottomNavBar(currentIndex: 2),
    );
  }
}
