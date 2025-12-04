// lib/screens/report.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:psp2_fn/auth/token_storage.dart';

/// ✅ 단독 테스트용 엔트리 포인트
/// 실제 앱(main.dart)에서 사용할 땐 이 main()은 안 써도 됨.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '신고/차단',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
      ),
      // 데모용: reviewId=123인 리뷰를 신고하는 화면
      home: const ReportPage(
        reviewId: 123,
        authorName: '충호',
      ),
    );
  }
}

/// 백엔드에 넘길 reason 코드 후보들
enum ReportReason {
  help('도움'),
  insult('비방 및 욕설'),
  commercial('원치 않는 상업성 게시글'),
  violence('중요성 표현 또는 노골적인 폭력'),
  wrongInfo('잘못된 정보'),
  etc('기타');

  final String label;
  const ReportReason(this.label);
}

class ReportPage extends StatefulWidget {
  /// ✅ 신고할 대상 리뷰 ID (백엔드 PathVariable)
  final int reviewId;

  /// (선택) UI에 보여줄 작성자 이름
  final String? authorName;

  const ReportPage({
    super.key,
    required this.reviewId,
    this.authorName,
  });

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final TextEditingController _textController = TextEditingController();
  ReportReason? _selected = ReportReason.help;
  bool _blockChecked = false;
  int _currentTab = 0; // 0: 게시물 신고/차단, 1: 작성자 신고/차단
  bool _submitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// ✅ 신고 API 호출: POST /api/reviews/{reviewId}/reports
  Future<void> _submit() async {
    // 1. 신고 사유 선택 여부 체크
    if (_selected == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고 사유를 선택해 주세요.')),
      );
      return;
    }

    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      // 2. accessToken 확인
      final token = await TokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        debugPrint('❌ 신고 실패: 저장된 accessToken이 없습니다. 로그인 필요.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그인 후 신고 기능을 사용할 수 있습니다.'),
            ),
          );
        }
        setState(() => _submitting = false);
        return;
      }

      // 3. URL 구성
      final baseUrl =
          dotenv.env['BACKEND_BASE_URL'] ?? 'https://clos21.kr';
      final uri = Uri.parse(
          '$baseUrl/api/reviews/${widget.reviewId}/reports');

      // 4. HTTP 헤더 & 바디 구성
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // 🔹 디버그용 payload (프론트에서만 사용)
      final payload = {
        'targetType': _currentTab == 0 ? 'post' : 'author',
        'reason': _selected!.name, // ex) 'insult'
        'reasonLabel': _selected!.label, // ex) '비방 및 욕설'
        'detail': _textController.text.trim(),
        'block': _blockChecked,
      };
      debugPrint('신고 전송(로컬 payload): $payload');

      // 🔹 실제 백엔드 DTO에 맞게 바디 구성
      // StationReviewReportRequest(reasonCode, reasonDetail) 가정
      final backendBody = jsonEncode({
        'reasonCode': _selected!.name,               // ex) 'insult'
        'description': _textController.text.trim(), // 상세 내용
      });

      debugPrint('신고 전송: POST $uri body=$backendBody');

      // 5. 요청 전송
      final res = await http.post(uri, headers: headers, body: backendBody);

      if (!mounted) return;

      if (res.statusCode == 201) {
        // 6. 성공 처리
        FocusScope.of(context).unfocus();
        _textController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신고가 접수되었습니다.')),
        );

        // 이 페이지가 모달로 올라온 경우 닫아주기
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true); // true = 신고 성공
        }
      } else if (res.statusCode == 401) {
        debugPrint('❌ 신고 실패(401): ${res.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요하거나 세션이 만료되었습니다.')),
        );
      } else {
        debugPrint('❌ 신고 실패: [${res.statusCode}] ${res.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('신고 실패 (${res.statusCode})'),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ 신고 중 예외: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신고 중 오류가 발생했습니다.')),
        );
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
        title: Text(
          widget.authorName != null
              ? '${widget.authorName}님의 리뷰 신고/차단'
              : '신고/차단하기',
        ),
        actions: [
          IconButton(
            tooltip: '닫기',
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).maybePop();
              }
            },
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 탭(세그먼트)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('게시물 신고/차단')),
                  ButtonSegment(value: 1, label: Text('작성자 신고/차단')),
                ],
                selected: {_currentTab},
                onSelectionChanged: (s) =>
                    setState(() => _currentTab = s.first),
                showSelectedIcon: false,
              ),
            ),
            const SizedBox(height: 4),

            // 본문
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 섹션 제목
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            '신고 사유',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(필수)',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),

                    // 라디오 리스트
                    Column(
                      children: ReportReason.values
                          .map(
                            (reason) => RadioListTile<ReportReason>(
                          contentPadding: EdgeInsets.zero,
                          groupValue: _selected,
                          value: reason,
                          onChanged: (r) =>
                              setState(() => _selected = r),
                          title: Text(reason.label),
                          dense: true,
                          visualDensity: const VisualDensity(
                            horizontal: -4,
                            vertical: -2,
                          ),
                        ),
                      )
                          .toList(),
                    ),

                    const SizedBox(height: 8),
                    // 텍스트 입력
                    TextField(
                      controller: _textController,
                      maxLines: 6,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText: '1,000자 이내로 신고 내용을 입력해 주세요.',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 8),
                    // 안내 문구(불릿)
                    const _BulletNote(
                      lines: [
                        '신고 항목에 포함되지 않는 내용은 기타를 선택하여 신고 내용을 작성해주시기 바랍니다.',
                        '신고해주신 내용은 관리자 검토 후 내부정책에 의거 조치가 진행됩니다.',
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 차단 여부 (현재는 서버로 안 보내고 UI 용도 / 추후 확장 가능)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _blockChecked,
                      onChanged: (v) =>
                          setState(() => _blockChecked = v ?? false),
                      title: Text(
                        _currentTab == 0
                            ? '해당 게시물을 차단합니다.'
                            : '해당 사용자의 게시물을 차단합니다.',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),
            // 하단 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).maybePop();
                        }
                      },
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Text('신고'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletNote extends StatelessWidget {
  final List<String> lines;
  const _BulletNote({required this.lines});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines
          .map(
            (t) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• '),
              Expanded(child: Text(t, style: style)),
            ],
          ),
        ),
      )
          .toList(),
    );
  }
}
