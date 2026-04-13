import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/task_model.dart';
import '../../theme/sahaya_theme.dart';
import '../../utils/translator.dart';
import 'task_chat_screen.dart';

class VolunteerChatHubScreen extends StatelessWidget {
  final String uid;

  const VolunteerChatHubScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: T('Chats', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .where('assignedVolunteerIds', arrayContains: uid)
            .snapshots(),
        builder: (context, taskSnapshot) {
          if (taskSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (taskSnapshot.hasError) {
            return _empty(
              context,
              icon: Icons.error_outline_rounded,
              title: 'Could not load chats',
              subtitle: 'Please check your connection and try again.',
            );
          }

          final tasks = (taskSnapshot.data?.docs ?? []).map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return TaskModel.fromJson(data);
          }).toList();

          if (tasks.isEmpty) {
            return _empty(
              context,
              icon: Icons.forum_outlined,
              title: 'No team chats yet',
              subtitle: 'Accept missions to join coordination chats.',
            );
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('volunteer_profiles').doc(uid).snapshots(),
            builder: (context, profileSnapshot) {
              final profileMap = profileSnapshot.data?.data() as Map<String, dynamic>?;
              final readByTask = profileMap?['chatReadAtByTask'] as Map<String, dynamic>? ?? <String, dynamic>{};

              return FutureBuilder<List<_ChatThread>>(
                key: ValueKey(tasks.map((t) => t.id).join('|')),
                future: _loadThreads(tasks, readByTask: readByTask),
                builder: (context, threadSnapshot) {
                  if (!threadSnapshot.hasData && threadSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final threads = threadSnapshot.data ?? const <_ChatThread>[];
                  if (threads.isEmpty) {
                    return _empty(
                      context,
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No chats created yet',
                      subtitle: 'Start a message from an active mission.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: threads.length,
                    separatorBuilder: (context, index) => Divider(color: cs.outlineVariant.withValues(alpha: 0.4), height: 1),
                    itemBuilder: (context, index) {
                      final thread = threads[index];
                      final title = _titleFor(thread.task);
                      final subtitle = '${thread.lastSender}: ${thread.lastText}';

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
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: T(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? SahayaColors.darkMuted
                                  : SahayaColors.lightMuted,
                            ),
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            T(
                              _formatTime(thread.lastTimestamp),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (thread.isUnread)
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
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
                                profileCollection: 'volunteer_profiles',
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
      ),
    );
  }

  Future<List<_ChatThread>> _loadThreads(
    List<TaskModel> tasks, {
    required Map<String, dynamic> readByTask,
  }) async {
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
      DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(0);
      if (ts is Timestamp) {
        timestamp = ts.toDate();
      }

      DateTime? lastRead;
      final readRaw = readByTask[task.id];
      if (readRaw is Timestamp) {
        lastRead = readRaw.toDate();
      }
      final senderId = (data['senderId'] as String?) ?? '';
      final isUnread = senderId != uid && (lastRead == null || timestamp.isAfter(lastRead));

      threads.add(
        _ChatThread(
          task: task,
          lastSender: (data['senderName'] as String?)?.trim().isNotEmpty == true && data['senderName'] != 'Volunteer'
              ? (data['senderName'] as String)
              : 'Member',
          lastText: ((data['text'] as String?) ?? '').trim(),
          lastTimestamp: timestamp,
          isUnread: isUnread,
        ),
      );
    }

    threads.sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));
    return threads;
  }

  String _titleFor(TaskModel task) {
    final desc = task.description.trim();
    if (desc.isNotEmpty) {
      return desc;
    }
    return task.taskType.name.replaceAll('_', ' ');
  }

  String _formatTime(DateTime dt) {
    if (dt.year < 2000) return '';
    final now = DateTime.now();
    final sameDay = now.year == dt.year && now.month == dt.month && now.day == dt.day;
    if (sameDay) {
      final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final mm = dt.minute.toString().padLeft(2, '0');
      final ap = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hh:$mm $ap';
    }
    return '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}';
  }

  Widget _empty(BuildContext context, {required IconData icon, required String title, required String subtitle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 50, color: isDark ? SahayaColors.darkBorder : const Color(0xFFD1D5DB)),
            const SizedBox(height: 14),
            T(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            T(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted,
              ),
            ),
          ],
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
