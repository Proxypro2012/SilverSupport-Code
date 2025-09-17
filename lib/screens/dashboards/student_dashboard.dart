import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../widgets/task_capsule.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final _auth = FirebaseAuth.instance;
  final _tasks = TaskService();
  int _selectedIndex = 0;

  void _logout() async {
    await _auth.signOut();
    if (mounted) context.go("/");
  }

  Future<void> _applyToTask(Task task) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    if (task.pendingApplicant == uid) return; // already applied
    await _tasks.applyToTask(taskId: task.id, userId: uid);
  }

  Future<void> _markComplete(Task task) async {
    await _tasks.markComplete(taskId: task.id);
  }

  void _onNavBarTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: uid == null
          ? null
          : FirebaseFirestore.instance.collection("students").doc(uid).get(),
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
                          // Add the two colored squares, spaced evenly
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.lightBlueAccent,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.lightBlueAccent
                                            .withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.greenAccent.withOpacity(
                                          0.2,
                                        ),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Add more vertical spacing between squares and tasks
                          const SizedBox(height: 40),
                          // Available tasks
                          Expanded(
                            child: StreamBuilder<List<Task>>(
                              stream: _tasks.streamOpenTasks(),
                              builder: (context, snap) {
                                if (snap.hasError) {
                                  return const _EmptyState(
                                    icon: Icons.error,
                                    text: "Error loading tasks",
                                  );
                                }
                                if (snap.connectionState ==
                                        ConnectionState.waiting &&
                                    (snap.data == null || snap.data!.isEmpty)) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                final tasks = snap.data ?? [];
                                if (tasks.isEmpty) {
                                  return const _EmptyState(
                                    icon: Icons.task_alt,
                                    text: "No tasks available right now!",
                                  );
                                }
                                return ListView.builder(
                                  itemCount: tasks.length,
                                  itemBuilder: (context, i) {
                                    final task = tasks[i];
                                    final alreadyApplied =
                                        task.pendingApplicant == uid;
                                    return TaskCapsule(
                                      task: task,
                                      isSenior: false,
                                      currentUserId: uid,
                                      subtitle: alreadyApplied
                                          ? "⏳ Already applied"
                                          : "Open for applicants",
                                      onApply: alreadyApplied
                                          ? null
                                          : () => _applyToTask(task),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    } else if (_selectedIndex == 1) {
                      // My Tasks (applied/assigned)
                      return _MyTasksView(
                        uid: uid,
                        tasksService: _tasks,
                        onMarkComplete: _markComplete,
                      );
                    } else if (_selectedIndex == 2) {
                      // Completed tab: show tasks completed by this student
                      return _CompletedTasksView(uid: uid, tasksService: _tasks);
                    } else if (_selectedIndex == 3) {
                      // Community
                      return const Center(
                        child: Text(
                          'Community (Coming Soon)',
                          style: TextStyle(fontSize: 20),
                        ),
                      );
                    } else if (_selectedIndex == 4) {
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
                selectedItemColor: Colors.blueAccent,
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
                    icon: Icon(Icons.check_circle),
                    label: 'Completed',
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

/// My Tasks view
class _MyTasksView extends StatelessWidget {
  final String? uid;
  final TaskService tasksService;
  final Future<void> Function(Task task) onMarkComplete;

  const _MyTasksView({
    required this.uid,
    required this.tasksService,
    required this.onMarkComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const _EmptyState(
        icon: Icons.person_off,
        text: "Not authenticated.",
      );
    }

    return StreamBuilder<List<Task>>(
      stream: tasksService.streamStudentAll(uid!),
      builder: (context, snap) {
        if (snap.hasError) {
          return const _EmptyState(
            icon: Icons.error,
            text: "Error loading tasks",
          );
        }

        if (snap.connectionState == ConnectionState.waiting &&
            (snap.data == null || snap.data!.isEmpty)) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snap.data ?? [];
        if (tasks.isEmpty) {
          return const _EmptyState(
            icon: Icons.hourglass_empty,
            text: "You haven’t applied or been assigned any tasks yet.",
          );
        }

        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, i) {
            final t = tasks[i];
            String subtitle = "Unknown";
            if (t.status == 'pendingApproval') {
              subtitle = '⏳ Pending approval';
            } else if (t.status == 'assigned') {
              subtitle = '📌 Assigned to you';
            } else if (t.status == 'completed') {
              subtitle = '✅ Completed';
            }
            return TaskCapsule(
              task: t,
              isSenior: false,
              currentUserId: uid,
              subtitle: subtitle,
              onMarkComplete: (t.status == 'assigned' && t.assignedTo == uid)
                  ? () => onMarkComplete(t)
                  : null,
            );
          },
        );
      },
    );
  }
}

/// Completed Tasks view
class _CompletedTasksView extends StatelessWidget {
  final String? uid;
  final TaskService tasksService;

  const _CompletedTasksView({required this.uid, required this.tasksService});

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Center(
        child: Text('Not authenticated.'),
      );
    }
    // Fetch completed task IDs from Firestore
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('students').doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!.data();
        final completedIds = (data?['userdata']?['completed_tasks'] as List?)?.cast<String>() ?? [];
        if (completedIds.isEmpty) {
          return const Center(child: Text('No completed tasks yet.'));
        }
        // Fetch the actual task details from Realtime Database
        return StreamBuilder(
          stream: tasksService.streamStudentAssigned(uid!),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final allTasks = snap.data as List<Task>;
            final completedTasks = allTasks.where((t) => completedIds.contains(t.id) && t.status == 'completed').toList();
            if (completedTasks.isEmpty) {
              return const Center(child: Text('No completed tasks yet.'));
            }
            return ListView.builder(
              itemCount: completedTasks.length,
              itemBuilder: (context, i) {
                final t = completedTasks[i];
                return TaskCapsule(
                  task: t,
                  isSenior: false,
                  currentUserId: uid,
                  subtitle: '✅ Completed',
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Shared empty state widget
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.black54),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
