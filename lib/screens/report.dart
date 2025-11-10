import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

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
      // 앱 실행 즉시 풀스크린 신고 화면
      home: const ReportPage(),
    );
  }
}

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
  const ReportPage({super.key});

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

  Future<void> _submit() async {
    // 유효성 검사
    if (_selected == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고 사유를 선택해 주세요.')),
      );
      return;
    }

    setState(() => _submitting = true);

    // 실제 전송 위치 (예: API 호출)
    final payload = {
      'targetType': _currentTab == 0 ? 'post' : 'author',
      'reason': _selected!.name,
      'reasonLabel': _selected!.label,
      'detail': _textController.text.trim(),
      'block': _blockChecked,
    };
    debugPrint('신고 전송: $payload');

    // 데모용 지연
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    // 🔽 입력창 비우기 + 키보드 내리기
    FocusScope.of(context).unfocus();
    _textController.clear();

    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('신고가 접수되었습니다.')),
    );

    // 루트가 아니면 뒤로 가기 (루트면 유지)
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('신고/차단하기'),
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
                onSelectionChanged: (s) => setState(() => _currentTab = s.first),
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
                          Text('(필수)', style: TextStyle(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),

                    // 라디오 리스트
                    ...ReportReason.values.map(
                          (reason) => RadioListTile<ReportReason>(
                        contentPadding: EdgeInsets.zero,
                        value: reason,
                        groupValue: _selected,
                        onChanged: (v) => setState(() => _selected = v),
                        title: Text(reason.label),
                        dense: true,
                        visualDensity:
                        const VisualDensity(horizontal: -4, vertical: -2),
                      ),
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

                    // 차단 여부
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _blockChecked,
                      onChanged: (v) => setState(() => _blockChecked = v ?? false),
                      title: const Text('해당 게시물을 차단합니다.'),
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
                        child: CircularProgressIndicator(strokeWidth: 2),
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
