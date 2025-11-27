// lib/screens/review.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:psp2_fn/auth/token_storage.dart';

/// ✅ 단독 실행 테스트용 엔트리 포인트
/// 실제 앱에 통합할 때는 이 main()은 제거하고 ReviewPage만 사용하세요.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  runApp(const _ReviewApp(key: ValueKey('_reviewAppRoot')));
}

class _ReviewApp extends StatelessWidget {
  const _ReviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '리뷰 작성',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
        fontFamily: 'Pretendard', // 없으면 시스템 폰트 사용
      ),
      home: const ReviewPage(
        stationId: 'DEMO_STATION_ID',
        placeName: 'OOOOOO 주차장',
        imageUrl:
        'https://images.unsplash.com/photo-1483721310020-03333e577078?q=80&w=800&auto=format&fit=crop',
      ),
    );
  }
}

class ReviewPage extends StatefulWidget {
  /// ✅ 백엔드에 넘길 충전소/주차장 ID
  final String stationId;

  /// 상단 카드에 보여줄 장소 이름
  final String placeName;

  /// 썸네일 이미지 URL
  final String imageUrl;

  const ReviewPage({
    super.key,
    required this.stationId,
    required this.placeName,
    required this.imageUrl,
  });

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  int _rating = 1;
  final TextEditingController _controller = TextEditingController();
  static const int _maxLen = 300;

  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _submitting) return;

    final baseUrl =
        dotenv.env['BACKEND_BASE_URL'] ?? 'https://clos21.kr'; // fallback
    final uri =
    Uri.parse('$baseUrl/api/stations/${widget.stationId}/reviews');

    setState(() => _submitting = true);

    try {
      final token = await TokenStorage.getAccessToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'stationId': widget.stationId,  // ✅ 추가
        'rating': _rating,
        'content': content,
      });

      debugPrint('리뷰 전송: POST $uri body=$body');

      final res = await http.post(uri, headers: headers, body: body);

      if (!mounted) return;

      if (res.statusCode == 201) {
        debugPrint('리뷰 생성 성공: ${res.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰가 등록되었습니다.')),
        );

        setState(() {
          _rating = 1;
          _controller.clear();
        });

        // 필요하면: Navigator.pop(context, true);
      } else {
        debugPrint('리뷰 생성 실패: [${res.statusCode}] ${res.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('리뷰 등록 실패 (${res.statusCode})'),
          ),
        );
      }
    } catch (e) {
      debugPrint('리뷰 생성 중 예외 발생: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('리뷰 등록 중 오류가 발생했습니다.')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;
    final len = _controller.text.characters.length;
    final progress = (len / _maxLen).clamp(0, 1).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('리뷰'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 상단 캡슐 + 별점
              _RatingCapsule(
                name: '충호', // TODO: 로그인 유저 이름으로 교체 가능
                rating: _rating,
                onChanged: (v) => setState(() => _rating = v),
              ),
              const SizedBox(height: 20),

              /// 장소 카드
              _PlaceCard(title: widget.placeName, imageUrl: widget.imageUrl),
              const SizedBox(height: 20),

              /// 입력 카드
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '리뷰 내용',
                      style:
                      txt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      maxLines: 6,
                      maxLength: _maxLen,
                      decoration: InputDecoration(
                        hintText:
                        '방문하신 주차장에 대한 솔직한 리뷰를 작성해 주세요.',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest,
                        counterText: '',
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          BorderSide(color: cs.primary, width: 1.2),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),

                    /// 글자수 + 진행바
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 6,
                              value: progress,
                              backgroundColor: cs.surfaceContainerHighest
                                  .withValues(alpha: .7),
                              valueColor: AlwaysStoppedAnimation(
                                cs.primary.withValues(alpha: .9),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$len/$_maxLen',
                          style: txt.labelMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              /// 등록 버튼
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _submitting
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.send_rounded),
                  label: Text(_submitting ? '등록 중...' : '등록'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _controller.text.trim().isEmpty || _submitting
                      ? null
                      : () {
                    HapticFeedback.lightImpact();
                    _submit();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 상단 캡슐: 이름칩 + 별점(크게) + 그라데이션
class _RatingCapsule extends StatelessWidget {
  final String name;
  final int rating;
  final ValueChanged<int> onChanged;

  const _RatingCapsule({
    required this.name,
    required this.rating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PhysicalModel(
      color: Colors.transparent,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.surfaceBright,
              cs.surface, // 은은한 깊이감
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 이름 칩
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                name,
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 별점
            _StarRow(value: rating, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// 별 5개(터치 + 간단 애니메이션)
class _StarRow extends StatelessWidget {
  final int value; // 0~5
  final ValueChanged<int> onChanged;

  const _StarRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final active = Theme.of(context).colorScheme.secondary;
    final inactive = Theme.of(context).disabledColor;

    return Row(
      children: List.generate(5, (i) {
        final filled = i < value;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: InkResponse(
            radius: 22,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(i + 1);
            },
            child: AnimatedScale(
              scale: filled ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_border_rounded,
                size: 26,
                color: filled ? active : inactive,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// 장소 정보 카드(썸네일 + 텍스트)
class _PlaceCard extends StatelessWidget {
  final String title;
  final String imageUrl;

  const _PlaceCard({required this.title, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // 썸네일
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: cs.surfaceContainerHighest,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(imageUrl, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          // 텍스트
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '방문 장소',
                  style:
                  txt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: txt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.place_rounded,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '주차장 · 서울',
                      style: txt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
