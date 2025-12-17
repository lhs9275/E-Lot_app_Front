// lib/screens/etc/report.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:psp2_fn/auth/token_storage.dart';
import 'package:psp2_fn/storage/report_history_storage.dart';

/// 단독 실행 데모(프로덕트에서는 호출 화면에서 push)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const _ReportDemoApp());
}

class _ReportDemoApp extends StatelessWidget {
  const _ReportDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // 기본 테마 컬러도 보라색 계열로 맞춤
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5F33DF)),
      ),
      home: const ReportPage(reviewId: 1, stationName: '데모 충전소'),
    );
  }
}

class ReportPage extends StatefulWidget {
  const ReportPage({super.key, required this.reviewId, this.stationName});

  final int reviewId;
  final String? stationName;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

enum ReportReason {
  spam('SPAM', '스팸/광고성 게시글'),
  abuse('ABUSE', '욕설 · 비방 · 혐오'),
  etc('ETC', '기타');

  const ReportReason(this.code, this.label);
  final String code;
  final String label;
}

class _ReportPageState extends State<ReportPage> {
  // --- 상태 변수 (기능 유지) ---
  final TextEditingController _textController = TextEditingController();
  ReportReason _selected = ReportReason.spam;
  bool _submitting = false;
  String? _kakaoNick;

  // --- 디자인 컬러 상수 ---
  final Color _bgColor = const Color(0xFFF9FBFD);
  final Color _cardColor = Colors.white;
  final Color _primaryColor = const Color(0xFF5F33DF);
  final Color _textColor = const Color(0xFF1A1A1A);
  final Color _subTextColor = const Color(0xFF8E929C);

  @override
  void initState() {
    super.initState();
    _loadKakaoName();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // --- 기능 로직 (100% 원본 유지) ---
  Future<void> _loadKakaoName() async {
    try {
      final user = await UserApi.instance.me();
      final nick = user.kakaoAccount?.profile?.nickname;
      if (!mounted) return;
      if (nick != null && nick.isNotEmpty) {
        setState(() => _kakaoNick = nick);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final description = _textController.text.trim();
    setState(() => _submitting = true);

    try {
      final token = await TokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인 후 신고할 수 있습니다.')));
        }
        setState(() => _submitting = false);
        return;
      }

      final baseUrl = dotenv.env['BACKEND_BASE_URL'] ?? 'https://clos21.kr';
      final uri = Uri.parse('$baseUrl/api/reviews/${widget.reviewId}/reports');
      final body = jsonEncode({
        'reasonCode': _selected.code,
        'description': description,
      });

      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (!mounted) return;

      if (res.statusCode == 201) {
        _textController.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
        await ReportHistoryStorage.add(
          LocalReport(
            stationName: widget.stationName ?? '알 수 없음',
            reporterName: _kakaoNick ?? '로그인 필요',
            reasonCode: _selected.code,
            reasonLabel: _selected.label,
            description: description,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      } else if (res.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 세션이 만료되었습니다. 다시 로그인해주세요.')),
        );
      } else if (res.statusCode == 400) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신고 사유를 선택해주세요.')));
      } else if (res.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미 신고한 리뷰입니다.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('신고 처리 중 오류 (${res.statusCode})')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신고 처리 중 오류가 발생했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // --- 화면 UI (디자인 변경) ---
  @override
  Widget build(BuildContext context) {
    final title = widget.stationName != null ? '${widget.stationName} 신고' : '리뷰 신고';

    return Scaffold(
      backgroundColor: _bgColor, // 배경색 적용
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w800, color: _textColor, fontSize: 18),
        ),
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: _textColor),
          onPressed: () {
            if (Navigator.of(context).canPop()) Navigator.of(context).maybePop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 신고 사유 선택 (Card Style)
              Container(
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
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.report_problem_rounded, color: Colors.redAccent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '신고 사유',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textColor),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '가장 적합한 사유를 선택해주세요.',
                                  style: TextStyle(fontSize: 12, color: _subTextColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 라디오 버튼 디자인 커스텀
                      ...ReportReason.values.map(
                            (reason) => _buildRadioTile(reason),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 2. 신고 내용 입력 (Card Style)
              Container(
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
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '상세 내용 (선택)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textColor),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _textController,
                        maxLines: 5,
                        maxLength: 1000,
                        style: TextStyle(color: _textColor, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '관리자에게 전달할 상세 내용을 적어주세요.\n(허위 신고 시 제재를 받을 수 있습니다.)',
                          hintStyle: TextStyle(color: _subTextColor.withOpacity(0.6), fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF5F6FA), // 입력창 회색 배경
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          counterStyle: TextStyle(color: _subTextColor, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // 3. 신고하기 버튼 (Gradient)
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
                    '신고 접수하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),

              if (_kakaoNick != null) ...[
                const SizedBox(height: 12),
                Text(
                  '신고자: $_kakaoNick',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _subTextColor, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 커스텀 라디오 타일 위젯
  Widget _buildRadioTile(ReportReason reason) {
    final bool isSelected = _selected == reason;
    return GestureDetector(
      onTap: () => setState(() => _selected = reason),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: _primaryColor.withOpacity(0.3)) : null,
        ),
        child: Row(
          children: [
            // 라디오 버튼 원형 디자인
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _primaryColor : const Color(0xFFCFD8DC),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              reason.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _primaryColor : _textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}