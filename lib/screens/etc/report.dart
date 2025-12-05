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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
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
  final TextEditingController _textController = TextEditingController();
  ReportReason _selected = ReportReason.spam;
  bool _submitting = false;
  String? _kakaoNick;

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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('로그인 후 신고할 수 있습니다.')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('신고 사유를 선택해주세요.')));
      } else if (res.statusCode == 409) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('이미 신고한 리뷰입니다.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('신고 처리 중 오류 (${res.statusCode})')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('신고 처리 중 오류가 발생했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = widget.stationName != null
        ? '${widget.stationName} 리뷰 신고'
        : '리뷰 신고';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.report_gmailerrorred_rounded,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '신고 사유 (필수)',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '가장 적합한 사유를 선택해주세요.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...ReportReason.values.map(
                        (reason) => RadioListTile<ReportReason>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          visualDensity: const VisualDensity(
                            horizontal: -4,
                            vertical: -2,
                          ),
                          title: Text(reason.label),
                          value: reason,
                          groupValue: _selected,
                          onChanged: (r) {
                            if (r != null) setState(() => _selected = r);
                          },
                        ),
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
                        '신고 내용 (선택)',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _textController,
                        maxLines: 5,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          hintText: '상세 사유를 적어주세요. (최대 1000자, 선택 입력)',
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
                    : const Text('신고하기'),
              ),
              if (_kakaoNick != null) ...[
                const SizedBox(height: 8),
                Text(
                  '신고자: $_kakaoNick',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
