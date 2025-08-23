import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../widgets/task_capsule.dart';

// ✅ same imports as yours

class SeniorDashboard extends StatefulWidget {
  const SeniorDashboard({super.key});

  @override
  State<SeniorDashboard> createState() => _SeniorDashboardState();
}

class _SeniorDashboardState extends State<SeniorDashboard> {
  final _auth = FirebaseAuth.instance;
  final _tasks = TaskService();

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _logout() async {
    await _auth.signOut();
    if (mounted) context.go("/");
  }

  Future<void> _postTask() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    if (title.isEmpty) return;

    setState(() => _posting = true);
    await _tasks.createTask(title: title, description: desc, createdBy: uid);
    _titleController.clear();
    _descController.clear();
    setState(() => _posting = false);
  }

  Future<void> _approveTask(Task task) async {
    await _tasks.approveTask(taskId: task.id);
  }

  Future<void> _rejectTask(Task task) async {
    await _tasks.rejectTask(taskId: task.id);
  }

  Future<void> _markComplete(Task task) async {
    await _tasks.markComplete(taskId: task.id);
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xffdfe9f3), Color(0xffe2d6f5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Senior Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.black),
                        onPressed: _logout,
                      ),
                    ],
                  ),
                ),

                // New task card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            hintText: 'Task title',
                            border: InputBorder.none,
                          ),
                        ),
                        const Divider(),
                        TextField(
                          controller: _descController,
                          decoration: const InputDecoration(
                            hintText: 'Short description (optional)',
                            border: InputBorder.none,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _posting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: _postTask,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Post Task'),
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Tasks list
                Expanded(
                  child: StreamBuilder<List<Task>>(
                    stream: uid == null
                        ? const Stream.empty()
                        : _tasks.streamSeniorCreated(uid),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final list = snap.data ?? [];
                      if (list.isEmpty) {
                        return const Center(
                          child: Text(
                            'You haven\'t posted any tasks yet.',
                            style: TextStyle(fontSize: 18, color: Colors.black),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final t = list[i];
                          final subtitles = {
                            'open': 'Open',
                            'pendingApproval': 'Pending approval',
                            'assigned': 'Assigned',
                            'completed': 'Completed',
                          };
                          final subtitle = subtitles[t.status] ?? 'Unknown';

                          return TaskCapsule(
                            task: t,
                            isSenior: true,
                            currentUserId: uid,
                            subtitle: subtitle,
                            onApprove: (t.status == 'pendingApproval')
                                ? () => _approveTask(t)
                                : null,
                            onReject: (t.status == 'pendingApproval')
                                ? () => _rejectTask(t)
                                : null,
                            onMarkComplete: (t.status == 'assigned')
                                ? () => _markComplete(t)
                                : null,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
