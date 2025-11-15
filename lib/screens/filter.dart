// lib/screens/filter_page.dart
import 'package:flutter/material.dart';

void main() => runApp(const _FilterApp());

/// ✅ 모든 간격/라운드 값을 한 곳에서 관리
class _G {
  static const double outer = 20.0;        // 화면 바깥 여백(ListView padding)
  static const double section = 60.0;      // 섹션(카드) 사이 간격
  static const double headerOption = 8.0;  // 헤더와 첫 옵션 사이 간격(펼쳤을 때)
  static const double optionVPad = 10.0;   // 옵션 한 줄의 위/아래 패딩
  static const double cardRadius = 12.0;   // 카드 라운드
}

class _FilterApp extends StatelessWidget {
  const _FilterApp({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: Brightness.light,
    ).copyWith(
      surface: Colors.white,
      onSurface: Colors.black87,
      onSurfaceVariant: Colors.black54,
      surfaceContainerHighest: const Color(0xFFF4F4F5),
      outlineVariant: const Color(0xFFE5E7EB),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: scheme),
      home: const FilterPage(),
    );
  }
}

enum TopCategory { evCharge, electricCharge, parking }
extension _Label on TopCategory {
  String get label => switch (this) {
    TopCategory.evCharge => '수소충전',
    TopCategory.electricCharge => 'EV충전',
    TopCategory.parking => '주차',
  };
}

class FilterPage extends StatefulWidget {
  const FilterPage({super.key});
  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  // 상단 카테고리
  TopCategory? _top;

  // EV 충전 선택값
  String? _evType;
  String? _evPressure;
  String? _evPriceRange;

  // 펼침 상태
  bool _openTop = false, _openType = false, _openPressure = false, _openPrice = false;

  // EV 옵션
  static const _evTypes = ['복합형'];
  static const _evPressures = ['350', '700'];
  static const _evPriceRanges = ['5000~10000', '10000~20000'];

  void _closeAllExcept(String key) {
    _openTop = key == 'top' ? _openTop : false;
    _openType = key == 'type' ? _openType : false;
    _openPressure = key == 'pressure' ? _openPressure : false;
    _openPrice = key == 'price' ? _openPrice : false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final sections = <Widget>[
      _InlineDropdown<TopCategory>(
        title: '충전, 주차 고르기',
        isOpen: _openTop,
        currentText: _top?.label,
        options: TopCategory.values,
        labelOf: (v) => v.label,
        selected: _top,
        onHeaderTap: () => setState(() {
          _openTop = !_openTop;
          _closeAllExcept('top');
        }),
        onSelect: (v) => setState(() {
          _top = v;
          _openTop = false; // 선택 즉시 닫기
          if (_top != TopCategory.evCharge) {
            _evType = _evPressure = _evPriceRange = null;
            _openType = _openPressure = _openPrice = false;
          }
        }),
      ),
      SizedBox(height: _G.section),

      if (_top == TopCategory.evCharge) ...[
        _InlineDropdown<String>(
          title: '충전소 유형',
          isOpen: _openType,
          currentText: _evType,
          options: _evTypes,
          labelOf: (s) => s,
          selected: _evType,
          onHeaderTap: () => setState(() {
            _openType = !_openType;
            _closeAllExcept('type');
          }),
          onSelect: (v) => setState(() {
            _evType = v;
            _openType = false;
          }),
        ),
        SizedBox(height: _G.section),
        _InlineDropdown<String>(
          title: '충전 압력',
          isOpen: _openPressure,
          currentText: _evPressure,
          options: _evPressures,
          labelOf: (s) => s,
          selected: _evPressure,
          onHeaderTap: () => setState(() {
            _openPressure = !_openPressure;
            _closeAllExcept('pressure');
          }),
          onSelect: (v) => setState(() {
            _evPressure = v;
            _openPressure = false;
          }),
        ),
        SizedBox(height: _G.section),
        _InlineDropdown<String>(
          title: '가격대',
          isOpen: _openPrice,
          currentText: _evPriceRange,
          options: _evPriceRanges,
          labelOf: (s) => s,
          selected: _evPriceRange,
          onHeaderTap: () => setState(() {
            _openPrice = !_openPrice;
            _closeAllExcept('price');
          }),
          onSelect: (v) => setState(() {
            _evPriceRange = v;
            _openPrice = false;
          }),
        ),
      ] else if (_top == TopCategory.electricCharge ||
          _top == TopCategory.parking) ...[
        const _InfoHint(text: '선택 항목이 아직 준비 중입니다.'),
      ],
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('필터'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(_G.outer, _G.outer, _G.outer, _G.outer),
                children: sections,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(top: BorderSide(color: cs.outlineVariant)),
              ),
              padding: const EdgeInsets.fromLTRB(_G.outer, 12, _G.outer, _G.outer),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final summary = {
                          'category': _top?.label,
                          if (_top == TopCategory.evCharge)
                            'ev': {
                              'type': _evType,
                              'pressure': _evPressure,
                              'price': _evPriceRange,
                            }
                        };
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('적용됨: $summary')));
                        Navigator.maybePop(context);
                      },
                      child: const Text('완료'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _top = null;
                      _evType = _evPressure = _evPriceRange = null;
                      _openTop = _openType = _openPressure = _openPrice = false;
                    }),
                    child: const Text('취소'),
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

/// 카드 안에서 “헤더 + (펼침)옵션들”이 같은 박스에 들어가는 위젯
class _InlineDropdown<T> extends StatelessWidget {
  const _InlineDropdown({
    required this.title,
    required this.isOpen,
    required this.options,
    required this.labelOf,
    required this.onHeaderTap,
    required this.onSelect,
    this.currentText,
    this.selected,
  });

  final String title;
  final bool isOpen;
  final List<T> options;
  final String Function(T) labelOf;
  final VoidCallback onHeaderTap;
  final void Function(T) onSelect;
  final String? currentText;
  final T? selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = cs.outlineVariant;
    final hasValue = (currentText != null && currentText!.isNotEmpty);

    return ClipRRect(
      borderRadius: BorderRadius.circular(_G.cardRadius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(_G.cardRadius),
        ),
        child: Column(
          children: [
            // 헤더 (카드 내부)
            InkWell(
              onTap: onHeaderTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 160),
                      child: Icon(Icons.expand_more_rounded,
                          size: 20, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasValue ? currentText! : title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black87, // 항상 검정
                          fontWeight:
                          hasValue ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 옵션들 (같은 카드 안에서 펼쳐짐)
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                child: isOpen
                    ? Column(
                  children: [
                    SizedBox(height: _G.headerOption),
                    ...List.generate(options.length, (i) {
                      final o = options[i];
                      final bool isSel = (selected == o);
                      final last = i == options.length - 1;
                      return _InlineOption(
                        label: labelOf(o),
                        selected: isSel,
                        showDivider: !last,
                        onTap: () => onSelect(o),
                      );
                    }),
                  ],
                )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 내부에 들어가는 옵션 행(체크/하이라이트)
class _InlineOption extends StatelessWidget {
  const _InlineOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.showDivider = true,
  });

  final String label;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? cs.primaryContainer : Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: _G.optionVPad),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_rounded, color: cs.primary, size: 20),
          ],
        ),
      ),
    ).withBottomDivider(showDivider ? cs.outlineVariant : null);
  }
}

extension on Widget {
  Widget withBottomDivider(Color? color) {
    if (color == null) return this;
    return Column(children: [
      this,
      Container(height: 1, color: color),
    ]);
  }
}

/// 안내 문구(기타 상태)
class _InfoHint extends StatelessWidget {
  const _InfoHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(top: _G.section),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(_G.cardRadius),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(text, style: const TextStyle(color: Colors.black54)),
    );
  }
}
