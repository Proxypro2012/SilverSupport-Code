import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../widgets/task_capsule.dart';

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
  int _selectedIndex = 0;

  void _onNavBarTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

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

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: uid == null
          ? null
          : FirebaseFirestore.instance.collection("seniors").doc(uid).get(),
      builder: (context, snapshot) {
        String welcomeText = 'Welcome';
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          final data = snapshot.data!.data();
          if (data != null &&
              data['name'] != null &&
              data['name'].toString().trim().isNotEmpty) {
            welcomeText = 'Welcome, ' + data['name'];
          }
        }
        return Scaffold(
          extendBody: true,
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
                child: Builder(
                  builder: (context) {
                    if (_selectedIndex == 0) {
                      // Dashboard
                      return Column(
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  welcomeText,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.logout,
                                    color: Colors.black,
                                  ),
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
                        ],
                      );
                    } else if (_selectedIndex == 1) {
                      // My Tasks
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 24,
                            ),
                            child: Text(
                              'Tasks you have posted:',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Expanded(
                            child: StreamBuilder<List<Task>>(
                              stream: uid == null
                                  ? const Stream.empty()
                                  : _tasks.streamSeniorCreated(uid),
                              builder: (context, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                final list = snap.data ?? [];
                                if (list.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      'You haven\'t posted any tasks yet.',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.black,
                                      ),
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
                                    final subtitle =
                                        subtitles[t.status] ?? 'Unknown';
                                    // Fetch and show the user's name instead of UID in TaskCapsule
                                    return FutureBuilder<
                                        DocumentSnapshot<
                                            Map<String, dynamic>>>(
                                      future: t.assignedTo != null
                                          ? FirebaseFirestore.instance
                                              .collection('students')
                                              .doc(t.assignedTo)
                                              .get()
                                          : null,
                                      builder: (context, snapshot) {
                                        String? assignedName;
                                        if (snapshot.connectionState ==
                                                ConnectionState.done &&
                                            snapshot.hasData) {
                                          final data =
                                              snapshot.data!.data();
                                          if (data != null &&
                                              data['name'] != null &&
                                              data['name']
                                                  .toString()
                                                  .trim()
                                                  .isNotEmpty) {
                                            assignedName = data['name'];
                                          }
                                        }
                                        return TaskCapsule(
                                          task: t,
                                          isSenior: true,
                                          currentUserId: uid,
                                          subtitle: subtitle +
                                              (assignedName != null
                                                  ? ' - $assignedName'
                                                  : ''),
                                          onApprove: (t.status ==
                                                  'pendingApproval')
                                              ? () => _approveTask(t)
                                              : null,
                                          onReject: (t.status ==
                                                  'pendingApproval')
                                              ? () => _rejectTask(t)
                                              : null,
                                          onMarkComplete: (t.status ==
                                                  'assigned')
                                              ? () => _markComplete(t)
                                              : null,
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    } else if (_selectedIndex == 2) {
                      // Community
                      return const Center(
                        child: Text(
                          'Community (Coming Soon)',
                          style: TextStyle(fontSize: 20),
                        ),
                      );
                    } else if (_selectedIndex == 3) {
                      // Categories
                      return const Center(
                        child: Text(
                          'Categories (Coming Soon)',
                          style: TextStyle(fontSize: 20),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BottomNavigationBar(
                backgroundColor: Colors.white.withOpacity(0.9),
                selectedItemColor: Colors.green,
                unselectedItemColor: Colors.black54,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard),
                    label: 'Dashboard',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.task),
                    label: 'My Tasks',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.people),
                    label: 'Community',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.category),
                    label: 'Categories',
                  ),
                ],
                currentIndex: _selectedIndex,
                onTap: _onNavBarTap,
                type: BottomNavigationBarType.fixed,
                elevation: 8,
                showSelectedLabels: true,
                showUnselectedLabels: true,
              ),
            ),
          ),
        );
      },
    );
  }
}
