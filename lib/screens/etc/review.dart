// lib/screens/etc/review.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:psp2_fn/auth/token_storage.dart';

/// 단독 실행용 데모(앱 내에서는 push로 진입)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const _ReviewApp());
}

class _ReviewApp extends StatelessWidget {
  const _ReviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
      ),
      home: const ReviewPage(stationId: 'DEMO_STATION_ID', placeName: '데모 충전소'),
    );
  }
}

class ReviewPage extends StatefulWidget {
  const ReviewPage({
    super.key,
    required this.stationId,
    required this.placeName,
  });

  final String stationId;
  final String placeName;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  int _rating = 1;
  final TextEditingController _controller = TextEditingController();
  static const int _maxLen = 300;
  bool _submitting = false;
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _loadKakaoName();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadKakaoName() async {
    try {
      final user = await UserApi.instance.me();
      final nick = user.kakaoAccount?.profile?.nickname;
      if (!mounted) return;
      if (nick != null && nick.isNotEmpty) {
        setState(() => _displayName = nick);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _submitting) return;

    final baseUrl = dotenv.env['BACKEND_BASE_URL'] ?? 'https://clos21.kr';
    final uri = Uri.parse('$baseUrl/api/stations/${widget.stationId}/reviews');

    setState(() => _submitting = true);

    try {
      final token = await TokenStorage.getAccessToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'stationId': widget.stationId,
        'rating': _rating,
        'content': content,
      });

      final res = await http.post(uri, headers: headers, body: body);
      if (!mounted) return;

      if (res.statusCode == 201) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('리뷰가 등록되었습니다.')));
        setState(() {
          _rating = 1;
          _controller.clear();
        });
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      } else if (res.statusCode == 401) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      } else if (res.statusCode == 400) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('입력값을 확인해주세요.')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('리뷰 등록 실패 (${res.statusCode})')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('리뷰 등록 중 오류가 발생했습니다.')));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('리뷰 작성'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              if (Navigator.of(context).canPop())
                Navigator.of(context).maybePop();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.placeName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (_displayName != null) ...[
                const SizedBox(height: 4),
                Text(
                  '작성자: $_displayName',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '별점 선택',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (i) {
                          final star = i + 1;
                          final selected = star <= _rating;
                          return IconButton(
                            icon: Icon(
                              selected
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: selected
                                  ? Colors.amber
                                  : cs.onSurfaceVariant,
                              size: 28,
                            ),
                            onPressed: () => setState(() => _rating = star),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '리뷰 내용',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _controller,
                        maxLines: 6,
                        maxLength: _maxLen,
                        decoration: const InputDecoration(
                          hintText: '솔직하게 느낀 점을 적어주세요. (최대 300자)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('리뷰 등록'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
