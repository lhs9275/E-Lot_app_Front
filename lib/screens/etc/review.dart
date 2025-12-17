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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ReviewPage(stationId: 'DEMO_STATION_ID', placeName: '데모 충전소'),
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
  // --- 상태 변수 (기능 유지) ---
  int _rating = 5; // 기본 점수 5점으로 변경 (긍정적 유도)
  final TextEditingController _controller = TextEditingController();
  static const int _maxLen = 300;
  bool _submitting = false;
  String? _displayName;

  // --- 디자인 컬러 상수 ---
  final Color _bgColor = const Color(0xFFF9FBFD);
  final Color _primaryColor = const Color(0xFF5F33DF);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF1A1A1A);
  final Color _subTextColor = const Color(0xFF8E929C);

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

  // --- 기능 로직 (기존 코드 그대로 유지) ---
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
    if (content.isEmpty || _submitting) {
      if (content.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰 내용을 입력해주세요.')),
        );
      }
      return;
    }

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('리뷰가 등록되었습니다.')));
        setState(() {
          _rating = 5;
          _controller.clear();
        });
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      } else if (res.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      } else if (res.statusCode == 400) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('입력값을 확인해주세요.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('리뷰 등록 실패 (${res.statusCode})')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('리뷰 등록 중 오류가 발생했습니다.')));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  // --- 화면 UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          '리뷰 작성',
          style: TextStyle(fontWeight: FontWeight.w700, color: _textColor),
        ),
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _textColor, size: 20),
          onPressed: () {
            if (Navigator.of(context).canPop()) Navigator.of(context).maybePop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 장소 정보 섹션
              Text(
                widget.placeName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textColor,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _displayName != null ? '작성자: $_displayName' : '익명 작성',
                style: TextStyle(color: _subTextColor, fontSize: 13, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // 2. 별점 선택 섹션 (둥근 카드)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      '이용 경험은 어떠셨나요?',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final star = i + 1;
                        final selected = star <= _rating;
                        return GestureDetector(
                          onTap: () => setState(() => _rating = star),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.star_rounded,
                              // 별점은 눈에 띄어야 하므로 Amber 사용, 아니면 회색
                              color: selected ? const Color(0xFFFFD700) : const Color(0xFFE0E0E0),
                              size: 42,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$_rating점',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _primaryColor),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. 리뷰 내용 입력 섹션 (둥근 카드)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '상세 리뷰',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _controller,
                      maxLines: 6,
                      maxLength: _maxLen,
                      style: TextStyle(color: _textColor, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: '충전소 이용 시 불편했던 점이나 좋았던 점을\n자유롭게 작성해주세요.',
                        hintStyle: TextStyle(color: _subTextColor.withOpacity(0.6), fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFF5F6FA), // 입력창 내부 회색
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                        counterStyle: TextStyle(color: _subTextColor, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 4. 등록 버튼 (그라데이션 & 둥근 스타일)
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5F33DF), Color(0xFF7A5AF8)], // 보라색 그라데이션
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5F33DF).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                      : const Text(
                    '리뷰 등록하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}