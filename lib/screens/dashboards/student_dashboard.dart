import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Student Dashboard',
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const TabBar(
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.black54,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        tabs: [
                          Tab(text: 'Available'),
                          Tab(text: 'My Tasks'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      children: [
                        /// Available tasks
                        StreamBuilder<List<Task>>(
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

                        /// My tasks
                        _MyTasksView(
                          uid: uid,
                          tasksService: _tasks,
                          onMarkComplete: _markComplete,
                        ),
                      ],
                    ),
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
