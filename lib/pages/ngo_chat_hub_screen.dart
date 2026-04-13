import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/task_model.dart';
import '../theme/sahaya_theme.dart';
import '../utils/translator.dart';
import 'volunteer/task_chat_screen.dart';

class NgoChatHubScreen extends StatelessWidget {
  final String ngoId;

  const NgoChatHubScreen({super.key, required this.ngoId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: T('Chats', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('problem_cards')
            .where('ngoId', isEqualTo: ngoId)
            .snapshots(),
        builder: (context, cardSnap) {
          if (cardSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (cardSnap.hasError) {
            return _empty(context, 'Could not load chats right now.');
          }

          final cardIds = (cardSnap.data?.docs ?? []).map((d) => d.id).toList();
          if (cardIds.isEmpty) {
            return _empty(context, 'No chats created yet.');
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tasks')
                .where('problemCardId', whereIn: cardIds.take(30).toList())
                .snapshots(),
            builder: (context, taskSnap) {
              if (taskSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (taskSnap.hasError) {
                return _empty(context, 'Could not load task chats.');
              }

              final tasks = (taskSnap.data?.docs ?? []).map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return TaskModel.fromJson(data);
              }).toList();

              if (tasks.isEmpty) {
                return _empty(context, 'No chats created yet.');
              }

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('ngo_profiles').doc(ngoId).snapshots(),
                builder: (context, profileSnap) {
                  final profileMap = profileSnap.data?.data() as Map<String, dynamic>?;
                  final readByTask = profileMap?['chatReadAtByTask'] as Map<String, dynamic>? ?? <String, dynamic>{};

                  return FutureBuilder<List<_ChatThread>>(
                    key: ValueKey(tasks.map((t) => t.id).join('|')),
                    future: _loadThreads(tasks, readByTask),
                    builder: (context, threadSnap) {
                      if (!threadSnap.hasData && threadSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final threads = threadSnap.data ?? const <_ChatThread>[];
                      if (threads.isEmpty) {
                        return _empty(context, 'No chats created yet.');
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: threads.length,
                        separatorBuilder: (context, index) => Divider(color: cs.outlineVariant.withValues(alpha: 0.4), height: 1),
                        itemBuilder: (context, index) {
                          final thread = threads[index];
                          final title = _taskTitle(thread.task);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: cs.primary.withValues(alpha: 0.12),
                              child: Icon(Icons.group_rounded, color: cs.primary),
                            ),
                            title: T(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                            ),
                            subtitle: T(
                              '${thread.lastSender}: ${thread.lastText}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? SahayaColors.darkMuted
                                    : SahayaColors.lightMuted,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                T(
                                  _fmt(thread.lastTimestamp),
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary),
                                ),
                                const SizedBox(height: 6),
                                if (thread.isUnread)
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TaskChatScreen(
                                    taskId: thread.task.id,
                                    taskTitle: title,
                                    profileCollection: 'ngo_profiles',
                                  ),
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
            },
          );
        },
      ),
    );
  }

  Future<List<_ChatThread>> _loadThreads(List<TaskModel> tasks, Map<String, dynamic> readByTask) async {
    final threads = <_ChatThread>[];

    for (final task in tasks) {
      final latest = await FirebaseFirestore.instance
          .collection('task_chats')
          .doc(task.id)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (latest.docs.isEmpty) {
        continue;
      }

      final data = latest.docs.first.data();
      final ts = data['timestamp'];
      if (ts is! Timestamp) {
        continue;
      }

      DateTime? lastRead;
      final raw = readByTask[task.id];
      if (raw is Timestamp) {
        lastRead = raw.toDate();
      }

      final msgTime = ts.toDate();
      final senderId = (data['senderId'] as String?) ?? '';
      final isUnread = senderId != ngoId && (lastRead == null || msgTime.isAfter(lastRead));

      threads.add(
        _ChatThread(
          task: task,
          lastSender: ((data['senderName'] as String?) ?? 'Member').trim(),
          lastText: ((data['text'] as String?) ?? '').trim(),
          lastTimestamp: msgTime,
          isUnread: isUnread,
        ),
      );
    }

    threads.sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));
    return threads;
  }

  String _taskTitle(TaskModel task) {
    final d = task.description.trim();
    return d.isNotEmpty ? d : task.taskType.name.replaceAll('_', ' ');
  }

  String _fmt(DateTime dt) {
    final now = DateTime.now();
    final sameDay = now.year == dt.year && now.month == dt.month && now.day == dt.day;
    if (sameDay) {
      final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final mm = dt.minute.toString().padLeft(2, '0');
      final ap = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hh:$mm $ap';
    }
    return '${dt.day}/${dt.month}';
  }

  Widget _empty(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: T(
          text,
          style: GoogleFonts.inter(color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted),
        ),
      ),
    );
  }
}

class _ChatThread {
  final TaskModel task;
  final String lastSender;
  final String lastText;
  final DateTime lastTimestamp;
  final bool isUnread;

  const _ChatThread({
    required this.task,
    required this.lastSender,
    required this.lastText,
    required this.lastTimestamp,
    required this.isUnread,
  });
}
