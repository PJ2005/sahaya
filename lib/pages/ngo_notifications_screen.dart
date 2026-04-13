import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/task_model.dart';
import '../theme/sahaya_theme.dart';
import '../utils/translator.dart';
import 'proof_review_screen.dart';
import 'volunteer/task_chat_screen.dart';

class NgoNotificationsScreen extends StatelessWidget {
  final String ngoId;

  const NgoNotificationsScreen({super.key, required this.ngoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: T('Notifications', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          _SectionTitle(title: 'Unread Chats'),
          const SizedBox(height: 8),
          _NgoUnreadChatsSection(ngoId: ngoId),
          const SizedBox(height: 18),
          _SectionTitle(title: 'Proof Review Pending'),
          const SizedBox(height: 8),
          _NgoProofPendingSection(ngoId: ngoId),
        ],
      ),
    );
  }
}

class _NgoUnreadChatsSection extends StatelessWidget {
  final String ngoId;

  const _NgoUnreadChatsSection({required this.ngoId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('problem_cards')
          .where('ngoId', isEqualTo: ngoId)
          .snapshots(),
      builder: (context, cardSnap) {
        if (cardSnap.connectionState == ConnectionState.waiting) {
          return const _LoadingCard();
        }
        if (cardSnap.hasError) {
          return const _EmptyCard(message: 'Unable to load chat updates right now.');
        }

        final cardIds = (cardSnap.data?.docs ?? []).map((d) => d.id).toList();
        if (cardIds.isEmpty) {
          return const _EmptyCard(message: 'No assigned task chats yet.');
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tasks')
              .where('problemCardId', whereIn: cardIds.take(30).toList())
              .snapshots(),
          builder: (context, taskSnap) {
            if (taskSnap.connectionState == ConnectionState.waiting) {
              return const _LoadingCard();
            }
            if (taskSnap.hasError) {
              return const _EmptyCard(message: 'Unable to load task chats right now.');
            }

            final tasks = (taskSnap.data?.docs ?? []).map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return TaskModel.fromJson(data);
            }).toList();

            if (tasks.isEmpty) {
              return const _EmptyCard(message: 'No task chats yet.');
            }

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('ngo_profiles').doc(ngoId).snapshots(),
              builder: (context, profileSnap) {
                final profileMap = profileSnap.data?.data() as Map<String, dynamic>?;
                final readByTask = profileMap?['chatReadAtByTask'] as Map<String, dynamic>? ?? <String, dynamic>{};

                return FutureBuilder<List<_UnreadChat>>(
                  key: ValueKey(tasks.map((t) => t.id).join('|')),
                  future: _loadUnread(tasks: tasks, readByTask: readByTask),
                  builder: (context, unreadSnap) {
                    if (!unreadSnap.hasData && unreadSnap.connectionState == ConnectionState.waiting) {
                      return const _LoadingCard();
                    }

                    final unread = unreadSnap.data ?? const <_UnreadChat>[];
                    if (unread.isEmpty) {
                      return const _EmptyCard(message: 'All chats are read.');
                    }

                    return _CardShell(
                      child: Column(
                        children: [
                          for (var i = 0; i < unread.length; i++) ...[
                            _UnreadTile(item: unread[i]),
                            if (i != unread.length - 1) const Divider(height: 1),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<_UnreadChat>> _loadUnread({required List<TaskModel> tasks, required Map<String, dynamic> readByTask}) async {
    final items = <_UnreadChat>[];

    for (final task in tasks) {
      final latest = await FirebaseFirestore.instance
          .collection('task_chats')
          .doc(task.id)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (latest.docs.isEmpty) continue;

      final data = latest.docs.first.data();
      final ts = data['timestamp'];
      if (ts is! Timestamp) continue;

      final senderId = (data['senderId'] as String?) ?? '';
      if (senderId == ngoId) continue;

      DateTime? lastRead;
      final raw = readByTask[task.id];
      if (raw is Timestamp) {
        lastRead = raw.toDate();
      }

      final at = ts.toDate();
      if (lastRead == null || at.isAfter(lastRead)) {
        items.add(
          _UnreadChat(
            task: task,
            sender: ((data['senderName'] as String?) ?? 'Member').trim(),
            text: ((data['text'] as String?) ?? '').trim(),
            at: at,
          ),
        );
      }
    }

    items.sort((a, b) => b.at.compareTo(a.at));
    return items;
  }
}

class _UnreadTile extends StatelessWidget {
  final _UnreadChat item;

  const _UnreadTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final title = item.task.description.trim().isNotEmpty ? item.task.description : item.task.taskType.name.replaceAll('_', ' ');

    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: cs.primary.withValues(alpha: 0.12),
            child: Icon(Icons.forum_rounded, color: cs.primary),
          ),
          const Positioned(
            right: -1,
            top: -1,
            child: CircleAvatar(radius: 5, backgroundColor: Colors.green),
          ),
        ],
      ),
      title: T(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      subtitle: T(
        '${item.sender}: ${item.text}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted),
      ),
      trailing: T(_fmt(item.at), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary)),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskChatScreen(
              taskId: item.task.id,
              taskTitle: title,
              profileCollection: 'ngo_profiles',
            ),
          ),
        );
      },
    );
  }

  String _fmt(DateTime dt) {
    final now = DateTime.now();
    if (now.year == dt.year && now.month == dt.month && now.day == dt.day) {
      final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final mm = dt.minute.toString().padLeft(2, '0');
      final ap = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hh:$mm $ap';
    }
    return '${dt.day}/${dt.month}';
  }
}

class _NgoProofPendingSection extends StatelessWidget {
  final String ngoId;

  const _NgoProofPendingSection({required this.ngoId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ngo_notifications')
          .where('ngoId', isEqualTo: ngoId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCard();
        }
        if (snapshot.hasError) {
          return const _EmptyCard(message: 'Unable to load proof notifications right now.');
        }

        final docs = (snapshot.data?.docs ?? const []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['type'] == 'proof_submitted' && data['read'] == false;
        }).toList();
        if (docs.isEmpty) {
          return const _EmptyCard(message: 'No proof reviews pending.');
        }

        return _CardShell(
          child: Column(
            children: [
              for (var i = 0; i < docs.length; i++) ...[
                _ProofTile(notification: docs[i], ngoId: ngoId),
                if (i != docs.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ProofTile extends StatelessWidget {
  final QueryDocumentSnapshot notification;
  final String ngoId;

  const _ProofTile({required this.notification, required this.ngoId});

  @override
  Widget build(BuildContext context) {
    final data = notification.data() as Map<String, dynamic>;
    final taskId = (data['taskId'] as String?) ?? '';

    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.red.withValues(alpha: 0.12),
        child: const Icon(Icons.hourglass_top_rounded, color: Colors.red),
      ),
      title: T('Proof submitted for a task', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      subtitle: T(taskId.isEmpty ? 'Waiting for review' : 'Task: $taskId', style: GoogleFonts.inter(fontSize: 12)),
      trailing: T('Pending', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w700)),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProofReviewScreen(ngoId: ngoId)),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        T(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: cs.primary, letterSpacing: 0.8)),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;

  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: isDark ? null : [sahayaCardShadow(context)],
      ),
      child: child,
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: T(
            message,
            style: GoogleFonts.inter(color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _CardShell(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _UnreadChat {
  final TaskModel task;
  final String sender;
  final String text;
  final DateTime at;

  const _UnreadChat({
    required this.task,
    required this.sender,
    required this.text,
    required this.at,
  });
}
