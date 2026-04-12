import 'package:flutter/material.dart';
import '../flavors.dart';
import '../utils/translator.dart';


class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: T(F.title)),
      body: Center(child: T('Hello ${F.title}')),
    );
  }
}
