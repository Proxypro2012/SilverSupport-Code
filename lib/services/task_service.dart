import 'package:firebase_database/firebase_database.dart';
import 'package:rxdart/rxdart.dart';
import '../models/task.dart';

class TaskService {
  final _db = FirebaseDatabase.instance.ref("tasks");

  Future<void> createTask({
    required String title,
    required String description,
    required String createdBy,
  }) async {
    final ref = _db.push();
    final task = Task(
      id: ref.key!,
      title: title,
      description: description,
      status: "open",
      createdBy: createdBy,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.set(task.toJson());
  }

  List<Task> _parseTasks(DataSnapshot snapshot) {
    final raw = snapshot.value;
    if (raw == null) return [];

    if (raw is Map) {
      return raw.entries.map<Task>((entry) {
        final map = Map<String, dynamic>.from(entry.value);
        return Task.fromJson(map, entry.key);
      }).toList();
    }

    if (raw is List) {
      return raw
          .asMap()
          .entries
          .where((e) => e.value != null)
          .map(
            (e) => Task.fromJson(
              Map<String, dynamic>.from(e.value),
              e.key.toString(),
            ),
          )
          .toList();
    }

    return [];
  }

  Stream<List<Task>> streamOpenTasks() {
    return _db
        .orderByChild("status")
        .equalTo("open")
        .onValue
        .map((event) {
          return _parseTasks(event.snapshot);
        })
        .handleError((_) => <Task>[])
        .asBroadcastStream();
  }

  Stream<List<Task>> streamSeniorCreated(String uid) {
    return _db
        .orderByChild("createdBy")
        .equalTo(uid)
        .onValue
        .map((event) {
          return _parseTasks(event.snapshot);
        })
        .handleError((_) => <Task>[])
        .asBroadcastStream();
  }

  Stream<List<Task>> streamStudentPending(String uid) {
    return _db
        .orderByChild("pendingApplicant")
        .equalTo(uid)
        .onValue
        .map((e) {
          final tasks = _parseTasks(e.snapshot);
          return tasks.where((t) => t.status == "pendingApproval").toList();
        })
        .handleError((_) => <Task>[])
        .asBroadcastStream();
  }

  Stream<List<Task>> streamStudentAssigned(String uid) {
    return _db
        .orderByChild("assignedTo")
        .equalTo(uid)
        .onValue
        .map((e) {
          final tasks = _parseTasks(e.snapshot);
          return tasks
              .where((t) => t.status == "assigned" || t.status == "completed")
              .toList();
        })
        .handleError((_) => <Task>[])
        .asBroadcastStream();
  }

  Stream<List<Task>> streamStudentAll(String uid) {
    final pendingStream = streamStudentPending(uid);
    final assignedStream = streamStudentAssigned(uid);

    return CombineLatestStream.combine2<List<Task>, List<Task>, List<Task>>(
      pendingStream,
      assignedStream,
      (pendingList, assignedList) {
        final map = <String, Task>{};
        for (final t in pendingList) map[t.id] = t;
        for (final t in assignedList) map[t.id] = t;

        final merged = map.values.toList()
          ..sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));
        return merged;
      },
    ).handleError((_) => <Task>[]).asBroadcastStream();
  }

  Future<void> applyToTask({
    required String taskId,
    required String userId,
  }) async {
    await _db.child(taskId).update({
      "status": "pendingApproval",
      "pendingApplicant": userId,
    });
  }

  Future<void> approveTask({required String taskId}) async {
    final snapshot = await _db.child(taskId).get();
    if (!snapshot.exists) return;

    final json = Map<String, dynamic>.from(snapshot.value as Map);
    final pendingUid = json["pendingApplicant"];
    if (pendingUid == null) return;

    await _db.child(taskId).update({
      "status": "assigned",
      "assignedTo": pendingUid,
      "pendingApplicant": null,
    });
  }

  Future<void> rejectTask({required String taskId}) async {
    await _db.child(taskId).update({
      "status": "open",
      "pendingApplicant": null,
    });
  }

  Future<void> markComplete({required String taskId}) async {
    await _db.child(taskId).update({"status": "completed"});
  }
}
