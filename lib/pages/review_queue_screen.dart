import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/problem_card.dart';
import '../components/review_card_dialog.dart';

class ReviewQueueScreen extends StatelessWidget {
  final String ngoId;
  const ReviewQueueScreen({super.key, required this.ngoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(title: const Text('Pending Human Review Queue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('problem_cards')
            .where('ngoId', isEqualTo: ngoId)
            .where('status', isEqualTo: 'pending_review') // Only generic Drafts
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Structural Generic Reject natively intercepted: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
             return const Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                   SizedBox(height: 16),
                   Text('Target Review Queue is entirely purged.', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                 ]
               )
             );
          }

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final struct = ProblemCard.fromJson({...data, 'id': docs[index].id});
              
              Color confidenceColor = Colors.green;
              if (struct.confidenceScore < 0.70) confidenceColor = Colors.red;
              else if (struct.confidenceScore <= 0.85) confidenceColor = Colors.orange;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
                elevation: 0,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(value: struct.confidenceScore, backgroundColor: Colors.grey[100], color: confidenceColor),
                      const Icon(Icons.science, size: 16, color: Colors.black54)
                    ]
                  ),
                  title: Text(struct.issueType.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  subtitle: Text("${struct.locationWard}, ${struct.locationCity}\nSeverity: ${struct.severityLevel.name.toUpperCase()}", style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blueAccent),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => ReviewCardDialog(draftCard: struct),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
