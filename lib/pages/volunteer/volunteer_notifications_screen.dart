import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/task_model.dart';
import '../../theme/sahaya_theme.dart';
import '../../utils/translator.dart';
import 'active_task_screen.dart';
import 'task_chat_screen.dart';

class VolunteerNotificationsScreen extends StatelessWidget {
  final String uid;

  const VolunteerNotificationsScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: T('Notifications', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          _SectionTitle(title: 'Unread Chats'),
          const SizedBox(height: 8),
          _UnreadChatsSection(uid: uid),
          const SizedBox(height: 18),
          _SectionTitle(title: 'Resubmission Required'),
          const SizedBox(height: 8),
          _ProofRejectedSection(uid: uid),
          const SizedBox(height: 18),
          _SectionTitle(title: 'Proof Review Pending'),
          const SizedBox(height: 8),
          _ProofPendingSection(uid: uid),
          if (isDark) const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _UnreadChatsSection extends StatelessWidget {
  final String uid;

  const _UnreadChatsSection({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('assignedVolunteerIds', arrayContains: uid)
          .snapshots(),
      builder: (context, taskSnap) {
        if (taskSnap.connectionState == ConnectionState.waiting) {
          return const _LoadingCard();
        }
        if (taskSnap.hasError) {
          return const _EmptyCard(message: 'Unable to load chat updates right now.');
        }

        final tasks = (taskSnap.data?.docs ?? []).map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return TaskModel.fromJson(data);
        }).toList();

        if (tasks.isEmpty) {
          return const _EmptyCard(message: 'No assigned chats yet.');
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('volunteer_profiles').doc(uid).snapshots(),
          builder: (context, profileSnap) {
            final profile = profileSnap.data?.data() as Map<String, dynamic>?;
            final readByTask = profile?['chatReadAtByTask'] as Map<String, dynamic>? ?? <String, dynamic>{};

            return FutureBuilder<List<_UnreadThread>>(
              key: ValueKey(tasks.map((t) => t.id).join('|')),
              future: _loadUnreadThreads(tasks: tasks, readByTask: readByTask, uid: uid),
              builder: (context, unreadSnap) {
                if (!unreadSnap.hasData && unreadSnap.connectionState == ConnectionState.waiting) {
                  return const _LoadingCard();
                }

                final unread = unreadSnap.data ?? const <_UnreadThread>[];
                if (unread.isEmpty) {
                  return const _EmptyCard(message: 'All chats are read.');
                }

                return _CardShell(
                  child: Column(
                    children: [
                      for (var i = 0; i < unread.length; i++) ...[
                        _UnreadChatTile(thread: unread[i]),
                        if (i != unread.length - 1)
                          const Divider(height: 1),
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
  }

  Future<List<_UnreadThread>> _loadUnreadThreads({
    required List<TaskModel> tasks,
    required Map<String, dynamic> readByTask,
    required String uid,
  }) async {
    final list = <_UnreadThread>[];

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
      final senderId = (data['senderId'] as String?) ?? '';
      if (senderId == uid) {
        continue;
      }

      final ts = data['timestamp'];
      if (ts is! Timestamp) {
        continue;
      }

      DateTime? lastRead;
      final raw = readByTask[task.id];
      if (raw is Timestamp) {
        lastRead = raw.toDate();
      }

      final messageTime = ts.toDate();
      if (lastRead == null || messageTime.isAfter(lastRead)) {
        list.add(
          _UnreadThread(
            task: task,
            lastSender: (data['senderName'] as String?) ?? 'Member',
            lastText: (data['text'] as String?) ?? '',
            at: messageTime,
          ),
        );
      }
    }

    list.sort((a, b) => b.at.compareTo(a.at));
    return list;
  }
}

class _UnreadChatTile extends StatelessWidget {
  final _UnreadThread thread;

  const _UnreadChatTile({required this.thread});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = thread.task.description.trim().isNotEmpty
        ? thread.task.description
        : thread.task.taskType.name.replaceAll('_', ' ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
        '${thread.lastSender}: ${thread.lastText}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted),
      ),
      trailing: T(
        _fmtTime(thread.at),
        style: GoogleFonts.inter(color: cs.primary, fontSize: 11, fontWeight: FontWeight.w700),
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
  }

  String _fmtTime(DateTime dt) {
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
}

class _ProofPendingSection extends StatelessWidget {
  final String uid;

  const _ProofPendingSection({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('match_records')
          .where('volunteerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, matchSnap) {
        if (matchSnap.connectionState == ConnectionState.waiting) {
          return const _LoadingCard();
        }
        if (matchSnap.hasError) {
          return const _EmptyCard(message: 'Unable to load proof review updates right now.');
        }

        final docs = (matchSnap.data?.docs ?? const []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'proof_submitted';
        }).toList();
        if (docs.isEmpty) {
          return const _EmptyCard(message: 'No proof reviews pending.');
        }

        return _CardShell(
          child: Column(
            children: [
              for (var i = 0; i < docs.length; i++) ...[
                _ProofPendingTile(doc: docs[i]),
                if (i != docs.length - 1)
                  const Divider(height: 1),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ProofRejectedSection extends StatelessWidget {
  final String uid;

  const _ProofRejectedSection({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('volunteer_notifications')
          .where('volunteerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, notifSnap) {
        if (notifSnap.connectionState == ConnectionState.waiting) {
          return const _LoadingCard();
        }
        if (notifSnap.hasError) {
          return const _EmptyCard(message: 'Unable to load revision alerts right now.');
        }

        final docs = (notifSnap.data?.docs ?? const []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['type'] == 'proof_rejected' && data['read'] == false;
        }).toList();

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTs = aData['createdAt'];
          final bTs = bData['createdAt'];
          final aMs = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
          final bMs = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
          return bMs.compareTo(aMs);
        });

        if (docs.isEmpty) {
          return const _EmptyCard(message: 'No resubmission alerts.');
        }

        return _CardShell(
          child: Column(
            children: [
              for (var i = 0; i < docs.length; i++) ...[
                _ProofRejectedTile(doc: docs[i]),
                if (i != docs.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ProofRejectedTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;

  const _ProofRejectedTile({required this.doc});

  Future<void> _open(BuildContext context) async {
    final data = doc.data() as Map<String, dynamic>;
    final taskId = (data['taskId'] as String?) ?? '';
    final matchRecordId = (data['matchRecordId'] as String?) ?? '';
    if (taskId.isEmpty || matchRecordId.isEmpty) {
      return;
    }

    final taskSnap = await FirebaseFirestore.instance.collection('tasks').doc(taskId).get();
    if (!taskSnap.exists) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: T('Task details are unavailable right now.')),
        );
      }
      return;
    }

    final matchSnap = await FirebaseFirestore.instance.collection('match_records').doc(matchRecordId).get();
    final matchMap = matchSnap.data();

    final taskMap = taskSnap.data() as Map<String, dynamic>;
    taskMap['id'] = taskSnap.id;
    final task = TaskModel.fromJson(taskMap);

    try {
      await doc.reference.update({'read': true});
    } catch (_) {}

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveTaskScreen(
          matchRecordId: matchRecordId,
          task: task,
          ngoName: null,
          ngoPhone: null,
          ngoEmail: null,
          status: (matchMap?['status'] as String?) ?? 'proof_rejected',
          proof: matchMap?['proof'] as Map<String, dynamic>?,
          adminReviewNote: (matchMap?['adminReviewNote'] as String?) ?? (data['adminReviewNote'] as String?),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final note = ((data['adminReviewNote'] as String?) ?? '').trim();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: SahayaColors.coral.withValues(alpha: 0.12),
        child: const Icon(Icons.warning_amber_rounded, color: SahayaColors.coral),
      ),
      title: T(
        'Proof needs resubmission',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
      ),
      subtitle: T(
        note.isEmpty ? 'NGO requested updated proof.' : note,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(fontSize: 12),
      ),
      trailing: T(
        'Action',
        style: GoogleFonts.inter(color: SahayaColors.coral, fontWeight: FontWeight.w700),
      ),
      onTap: () => _open(context),
    );
  }
}

class _ProofPendingTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;

  const _ProofPendingTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final matchData = doc.data() as Map<String, dynamic>;
    final taskId = (matchData['taskId'] as String?) ?? '';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('tasks').doc(taskId).get(),
      builder: (context, taskSnap) {
        if (!taskSnap.hasData || !taskSnap.data!.exists) {
          return const SizedBox.shrink();
        }

        final taskMap = taskSnap.data!.data() as Map<String, dynamic>;
        taskMap['id'] = taskSnap.data!.id;
        final task = TaskModel.fromJson(taskMap);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.red.withValues(alpha: 0.12),
            child: const Icon(Icons.hourglass_top_rounded, color: Colors.red),
          ),
          title: T(
            task.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          subtitle: T(
            'Review pending from NGO',
            style: GoogleFonts.inter(fontSize: 12),
          ),
          trailing: T(
            'Pending',
            style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w700),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ActiveTaskScreen(
                  matchRecordId: doc.id,
                  task: task,
                  ngoName: null,
                  ngoPhone: null,
                  ngoEmail: null,
                  status: 'proof_submitted',
                  proof: matchData['proof'] as Map<String, dynamic>?,
                  adminReviewNote: matchData['adminReviewNote'] as String?,
                ),
              ),
            );
          },
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
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
        ),
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
            style: GoogleFonts.inter(
              color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted,
              fontSize: 13,
            ),
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

class _UnreadThread {
  final TaskModel task;
  final String lastSender;
  final String lastText;
  final DateTime at;

  const _UnreadThread({
    required this.task,
    required this.lastSender,
    required this.lastText,
    required this.at,
  });
}
