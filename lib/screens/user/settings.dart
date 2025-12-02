import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: '계정',
            children: [
              _RowTile(
                icon: Icons.person_outline,
                iconColor: cs.primary,
                title: '로그아웃',
                subtitle: '현재 계정에서 로그아웃합니다.',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('로그아웃 기능은 준비 중입니다.')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '지도/위치',
            children: [
              _RowTile(
                icon: Icons.location_pin,
                iconColor: Colors.indigo,
                title: '위치 권한 안내',
                subtitle: '정확한 추천을 위해 위치 권한을 허용하세요.',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('설정 > 앱 권한에서 위치를 허용해주세요.')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '정보',
            children: [
              _RowTile(
                icon: Icons.help_outline,
                iconColor: Colors.teal,
                title: 'FAQ / 문의',
                subtitle: '문의나 버그 신고는 고객센터를 이용해주세요.',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('문의 기능은 준비 중입니다.')),
                  );
                },
              ),
              _RowTile(
                icon: Icons.info_outline,
                iconColor: Colors.grey,
                title: '앱 버전',
                subtitle: 'v1.0.0',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: txt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
