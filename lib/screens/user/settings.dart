import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'package:psp2_fn/auth/auth_api.dart' as clos_auth;
import 'package:psp2_fn/auth/token_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoggedIn = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshLoginState();
  }

  Future<void> _refreshLoginState() async {
    final token = await TokenStorage.getAccessToken();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = token != null && token.isNotEmpty;
    });
  }

  Future<void> _handleAuthToggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_isLoggedIn) {
        final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('로그아웃'),
                content: const Text('정말 로그아웃하시겠습니까?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('취소'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text(
                      '로그아웃',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ) ??
            false;
        if (!confirmed) return;

        try {
          await UserApi.instance.logout();
        } catch (_) {
          // ignore logout errors; continue clearing local tokens
        }
        await TokenStorage.clear();
        if (!mounted) return;
        setState(() => _isLoggedIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃되었습니다.')),
        );
      } else {
        await clos_auth.AuthApi.loginWithKakao();
        if (!mounted) return;
        setState(() => _isLoggedIn = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('처리 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                title: _isLoggedIn ? '로그아웃' : '로그인',
                subtitle:
                    _isLoggedIn ? '현재 계정을 로그아웃합니다.' : '카카오로 로그인합니다.',
                onTap: _busy ? null : _handleAuthToggle,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '위치',
            children: [
              _RowTile(
                icon: Icons.location_pin,
                iconColor: Colors.indigo,
                title: '위치 접근 안내',
                subtitle: '기기 설정 > 위치 권한을 허용해 주세요.',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('설정 > 위치 접근 권한을 확인해주세요.'),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '도움말',
            children: [
              _RowTile(
                icon: Icons.help_outline,
                iconColor: Colors.teal,
                title: 'FAQ / 문의',
                subtitle: '문의 및 자주 묻는 질문을 준비 중입니다.',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('FAQ는 준비 중입니다.')),
                  );
                },
              ),
              _RowTile(
                icon: Icons.info_outline,
                iconColor: Colors.grey,
                title: '앱 정보',
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.02 * 255).round()),
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
            color: iconColor.withAlpha((0.12 * 255).round()),
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
