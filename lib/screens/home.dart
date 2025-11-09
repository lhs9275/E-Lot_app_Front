import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // 지금은 안 써도 되지만 놔둬도 됨

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key}); // ← const 추가

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E-lot 홈')),
      body: const Center(
        child: Text('여기가 메인 화면!'),
      ),
    );
  }
}