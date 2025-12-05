import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:psp2_fn/auth/token_storage.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchReviews();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('리뷰 목록 - ${widget.stationName}'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _fetchReviews,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: '리뷰 작성',
            onPressed: _openWritePage,
            icon: const Icon(Icons.rate_review_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 38, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(_error!, style: txt.bodyMedium),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _fetchReviews,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            )
          : _reviews.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.reviews_rounded, size: 40, color: cs.primary),
                  const SizedBox(height: 12),
                  Text('아직 등록된 리뷰가 없습니다.', style: txt.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    '첫 리뷰를 남겨보세요.',
                    style: txt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.rate_review, size: 18),
                    label: const Text('리뷰 작성'),
                    onPressed: _openWritePage,
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: _reviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final r = _reviews[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.authorName,
                                    style: txt.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    r.createdAt ?? '작성 시각 정보 없음',
                                    style: txt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: '신고하기',
                              icon: const Icon(
                                Icons.flag_outlined,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _reportReview(r),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildStars(r.rating),
                        const SizedBox(height: 6),
                        Text(r.content, style: txt.bodyMedium),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStars(int rating) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          size: 16,
          color: filled ? cs.secondary : cs.onSurfaceVariant,
        );
      }),
    );
  }
}

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

  factory _ReviewItem.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'] ?? json['reviewId'] ?? 0;
    final ratingRaw = json['rating'] ?? json['score'] ?? 0;
    final contentRaw =
        json['content'] ?? json['text'] ?? json['comment'] ?? '내용이 없습니다.';
    final authorRaw =
        json['authorName'] ??
        json['writerName'] ??
        json['writerEmail'] ??
        json['writer'] ??
        json['nickname'] ??
        json['userName'] ??
        '익명';
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
}

extension on _ReviewListPageState {
  Future<void> _openWritePage() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReviewPage(
          stationId: widget.stationId,
          placeName: widget.stationName,
          imageUrl:
              'https://images.unsplash.com/photo-1483721310020-03333e577078?q=80&w=800&auto=format&fit=crop',
        ),
      ),
    );
    if (result == true && mounted) {
      await _fetchReviews();
    }
  }
}
