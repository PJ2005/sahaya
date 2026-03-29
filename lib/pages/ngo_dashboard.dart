import 'package:flutter/material.dart';
import 'upload_screen.dart';
import 'review_queue_screen.dart';

class NgoDashboard extends StatefulWidget {
  final String ngoId;
  const NgoDashboard({super.key, required this.ngoId});

  @override
  State<NgoDashboard> createState() => _NgoDashboardState();
}

class _NgoDashboardState extends State<NgoDashboard> {
  int _currentIndex = 0;
  late final List<Widget> _children;

  @override
  void initState() {
    super.initState();
    _children = [
      UploadScreen(ngoId: widget.ngoId),
      ReviewQueueScreen(ngoId: widget.ngoId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _children[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.blueAccent,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.cloud_upload), label: 'Target Ingestion'),
          BottomNavigationBarItem(icon: Icon(Icons.fact_check), label: 'Human Review Queue'),
        ],
      ),
    );
  }
}
