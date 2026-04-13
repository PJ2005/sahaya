import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/sahaya_theme.dart';
import '../../utils/translator.dart';

class TaskChatScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final String? profileCollection;

  const TaskChatScreen({
    super.key, 
    required this.taskId, 
    required this.taskTitle,
    this.profileCollection,
  });

  @override
  State<TaskChatScreen> createState() => _TaskChatScreenState();
}

class _TaskChatScreenState extends State<TaskChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  String _currentUserName = 'Volunteer';
  bool _sending = false;

  Map<String, dynamic>? _taskData;
  List<_ChatMember> _members = const [];
  DateTime? _lastMarkedReadAt;
  String? _profileCollectionForCurrentUser;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _loadChatContext();
    _markLatestAsRead();
  }

  Future<void> _markLatestAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    try {
      final latest = await FirebaseFirestore.instance
          .collection('task_chats')
          .doc(widget.taskId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (latest.docs.isEmpty) {
        return;
      }

      final ts = latest.docs.first.data()['timestamp'];
      if (ts is! Timestamp) {
        return;
      }

      final latestAt = ts.toDate();
      if (_lastMarkedReadAt != null && !latestAt.isAfter(_lastMarkedReadAt!)) {
        return;
      }

      final collection = await _resolveProfileCollection(uid);
      if (collection == null) {
        return;
      }

      try {
        await FirebaseFirestore.instance.collection(collection).doc(uid).update({
          'chatReadAtByTask.${widget.taskId}': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        await FirebaseFirestore.instance.collection(collection).doc(uid).set({
          'chatReadAtByTask': {
            widget.taskId: FieldValue.serverTimestamp(),
          },
        }, SetOptions(merge: true));
      }
      _lastMarkedReadAt = latestAt;
    } catch (_) {
      // Ignore read-marker failures to avoid blocking chat usage.
    }
  }

  Future<String?> _resolveProfileCollection(String uid) async {
    if (widget.profileCollection != null) {
      _profileCollectionForCurrentUser = widget.profileCollection;
      return _profileCollectionForCurrentUser;
    }

    if (_profileCollectionForCurrentUser != null) {
      return _profileCollectionForCurrentUser;
    }

    final volunteerDoc = await FirebaseFirestore.instance.collection('volunteer_profiles').doc(uid).get();
    if (volunteerDoc.exists) {
      _profileCollectionForCurrentUser = 'volunteer_profiles';
      return _profileCollectionForCurrentUser;
    }

    final ngoDoc = await FirebaseFirestore.instance.collection('ngo_profiles').doc(uid).get();
    if (ngoDoc.exists) {
      _profileCollectionForCurrentUser = 'ngo_profiles';
      return _profileCollectionForCurrentUser;
    }

    return null;
  }

  Future<void> _fetchUserName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      if (widget.profileCollection == 'ngo_profiles') {
        _profileCollectionForCurrentUser = 'ngo_profiles';
        final ngoProfileDoc = await FirebaseFirestore.instance.collection('ngo_profiles').doc(uid).get();
        if (ngoProfileDoc.exists && ngoProfileDoc.data() != null) {
          final data = ngoProfileDoc.data()!;
          final name = ((data['name'] as String?) ?? 'NGO Coordinator').trim();
          if (mounted) {
            setState(() => _currentUserName = name.isEmpty ? 'NGO Coordinator' : name);
            return;
          }
        }
      }

      if (widget.profileCollection == 'volunteer_profiles') {
        _profileCollectionForCurrentUser = 'volunteer_profiles';
        final volunteerDoc = await FirebaseFirestore.instance.collection('volunteer_profiles').doc(uid).get();
        if (volunteerDoc.exists && volunteerDoc.data() != null) {
          final data = volunteerDoc.data()!;
          final username = ((data['username'] as String?) ?? (data['name'] as String?) ?? 'Volunteer').trim();
          if (mounted && username.isNotEmpty) {
            setState(() => _currentUserName = username);
            return;
          }
        }
      }

      final profileDoc = await FirebaseFirestore.instance.collection('volunteer_profiles').doc(uid).get();
      if (profileDoc.exists && profileDoc.data() != null) {
        _profileCollectionForCurrentUser = 'volunteer_profiles';
        final data = profileDoc.data()!;
        final username = ((data['username'] as String?) ?? (data['name'] as String?) ?? 'Volunteer').trim();
        if (mounted && username.isNotEmpty) {
          setState(() => _currentUserName = username);
          return;
        }
      }

      final ngoProfileDoc = await FirebaseFirestore.instance.collection('ngo_profiles').doc(uid).get();
      if (ngoProfileDoc.exists && ngoProfileDoc.data() != null) {
        _profileCollectionForCurrentUser = 'ngo_profiles';
        final data = ngoProfileDoc.data()!;
        final name = ((data['name'] as String?) ?? 'NGO Coordinator').trim();
        if (mounted) {
          setState(() => _currentUserName = name.isEmpty ? 'NGO Coordinator' : name);
          return;
        }
      }

      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null && mounted) {
        final name = ((doc.data()!['username'] as String?) ?? (doc.data()!['name'] as String?) ?? 'Volunteer').trim();
        setState(() => _currentUserName = name.isEmpty ? 'Volunteer' : name);
      }
    }
  }

  Future<void> _loadChatContext() async {
    try {
      final taskDoc = await FirebaseFirestore.instance.collection('tasks').doc(widget.taskId).get();
      if (!taskDoc.exists || taskDoc.data() == null) {
        return;
      }

      final taskData = taskDoc.data()!;
      final volunteerIds = List<String>.from(taskData['assignedVolunteerIds'] ?? const <String>[]);
      final members = <_ChatMember>[];

      for (final uid in volunteerIds) {
        members.add(await _resolveVolunteer(uid));
      }

      final problemCardId = taskData['problemCardId'] as String?;
      if (problemCardId != null && problemCardId.isNotEmpty) {
        final problemDoc = await FirebaseFirestore.instance.collection('problem_cards').doc(problemCardId).get();
        final ngoId = problemDoc.data()?['ngoId'] as String?;
        if (ngoId != null && ngoId.isNotEmpty) {
          members.add(await _resolveNgo(ngoId));
        }
      }

      if (mounted) {
        setState(() {
          _taskData = taskData;
          _members = members;
        });
      }
    } catch (_) {
      // Keep chat usable even if context lookup fails.
    }
  }

  Future<_ChatMember> _resolveVolunteer(String uid) async {
    final profileDoc = await FirebaseFirestore.instance.collection('volunteer_profiles').doc(uid).get();
    if (profileDoc.exists && profileDoc.data() != null) {
      final data = profileDoc.data()!;
      final name = ((data['username'] as String?) ?? (data['name'] as String?) ?? 'Volunteer').trim();
      final safeName = name.isEmpty ? 'Volunteer' : name;
      return _ChatMember(
        uid: uid,
        name: safeName,
        role: 'Volunteer',
        subtitle: _skillsPreview(data['skillTags']),
      );
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      final data = userDoc.data()!;
      final name = ((data['username'] as String?) ?? (data['name'] as String?) ?? 'Volunteer').trim();
      final safeName = name.isEmpty ? 'Volunteer' : name;
      return _ChatMember(uid: uid, name: safeName, role: 'Volunteer');
    }

    return _ChatMember(uid: uid, name: 'Volunteer', role: 'Volunteer');
  }

  Future<_ChatMember> _resolveNgo(String ngoId) async {
    final ngoProfileDoc = await FirebaseFirestore.instance.collection('ngo_profiles').doc(ngoId).get();
    if (ngoProfileDoc.exists && ngoProfileDoc.data() != null) {
      final data = ngoProfileDoc.data()!;
      final name = ((data['name'] as String?) ?? 'NGO Coordinator').trim();
      final phone = (data['phone'] as String?)?.trim();
      final email = (data['email'] as String?)?.trim();
      return _ChatMember(
        uid: ngoId,
        name: name.isEmpty ? 'NGO Coordinator' : name,
        role: 'NGO',
        subtitle: _contactPreview(phone: phone, email: email),
      );
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(ngoId).get();
    if (userDoc.exists && userDoc.data() != null) {
      final data = userDoc.data()!;
      final name = ((data['name'] as String?) ?? 'NGO Coordinator').trim();
      final phone = (data['phone'] as String?)?.trim();
      final email = (data['email'] as String?)?.trim();
      return _ChatMember(
        uid: ngoId,
        name: name.isEmpty ? 'NGO Coordinator' : name,
        role: 'NGO',
        subtitle: _contactPreview(phone: phone, email: email),
      );
    }

    return _ChatMember(uid: ngoId, name: 'NGO Coordinator', role: 'NGO');
  }

  String _skillsPreview(dynamic skillsRaw) {
    final skills = List<String>.from(skillsRaw ?? const <String>[]);
    if (skills.isEmpty) {
      return '';
    }
    return skills.take(3).join(', ');
  }

  String _contactPreview({String? phone, String? email}) {
    if (phone != null && phone.isNotEmpty) {
      return phone;
    }
    if (email != null && email.isNotEmpty) {
      return email;
    }
    return '';
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    try {
      await FirebaseFirestore.instance
          .collection('task_chats')
          .doc(widget.taskId)
          .collection('messages')
          .add({
        'senderId': uid,
        'senderName': _currentUserName,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _showMembers() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.7;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                T(
                  'Members',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                T(
                  _taskData?['description'] as String? ?? widget.taskTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted,
                  ),
                ),
                const SizedBox(height: 12),
                if (_members.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: T(
                        'No member details available yet.',
                        style: GoogleFonts.inter(
                          color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted,
                        ),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxSheetHeight),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _members.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final m = _members[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
                            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 21,
                                backgroundColor: cs.primary.withValues(alpha: 0.12),
                                child: T(
                                  m.initials,
                                  style: GoogleFonts.inter(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    T(
                                      m.name,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    T(
                                      m.role,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: cs.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (m.subtitle.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      T(
                                        m.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showMembers,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              T('Task Coordination', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary)),
              Row(
                children: [
                  Expanded(
                    child: T(widget.taskTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_up_rounded, size: 18, color: cs.primary),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showMembers,
            icon: const Icon(Icons.group_rounded),
            tooltip: 'Members',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0B1220), const Color(0xFF0F172A)]
                : [const Color(0xFFF8FAFC), Colors.white],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('task_chats')
                    .doc(widget.taskId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;
                  if (docs.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _markLatestAsRead();
                    });
                  }
                  final myUid = FirebaseAuth.instance.currentUser?.uid;
                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: T(
                          'No messages yet. Start the coordination conversation.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: isDark ? SahayaColors.darkMuted : SahayaColors.lightMuted,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true,
                    padding: const EdgeInsets.all(20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final senderId = data['senderId'];
                      final isMe = senderId == myUid;
                      
                      String displayedSenderName = data['senderName'] ?? '...';
                      try {
                        if (_members.isNotEmpty && senderId != null) {
                          final match = _members.firstWhere((m) => m.uid == senderId);
                          displayedSenderName = match.name;
                        }
                      } catch (_) {}

                      return _ChatBubble(
                        text: data['text'] ?? '',
                        sender: displayedSenderName,
                        isMe: isMe,
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                top: 10,
                bottom: MediaQuery.of(context).padding.bottom + 10,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111827) : Colors.white,
                border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        hintStyle: GoogleFonts.inter(fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton.small(
                    onPressed: _sending ? null : _send,
                    backgroundColor: cs.primary,
                    elevation: 0,
                    child: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMember {
  final String uid;
  final String name;
  final String role;
  final String subtitle;

  const _ChatMember({
    required this.uid,
    required this.name,
    required this.role,
    this.subtitle = '',
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.map((e) => e[0]).take(2).join().toUpperCase();
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final String sender;
  final bool isMe;

  const _ChatBubble({required this.text, required this.sender, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: T(sender, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMe 
                ? cs.primary 
                : (isDark ? SahayaColors.darkBorder : const Color(0xFFF3F4F6)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 16),
              ),
            ),
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isMe ? Colors.white : cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
