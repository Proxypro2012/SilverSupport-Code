class Task {
  final String id;
  final String title;
  final String description;
  final String status; // open | pendingApproval | assigned | completed
  final String createdBy;
  final String? assignedTo;
  final String? pendingApplicant;
  final int? timestamp;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.createdBy,
    this.assignedTo,
    this.pendingApplicant,
    this.timestamp,
  });

  /// Factory that works for both Firestore docs and RTDB snapshots
  factory Task.fromJson(Map<String, dynamic> json, [String? id]) {
    return Task(
      id: id ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'open',
      createdBy: json['createdBy'] ?? '',
      assignedTo: json['assignedTo'],
      pendingApplicant: json['pendingApplicant'],
      timestamp: json['timestamp'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "description": description,
      "status": status,
      "createdBy": createdBy,
      "assignedTo": assignedTo,
      "pendingApplicant": pendingApplicant,
      "timestamp": timestamp,
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? status,
    String? createdBy,
    String? assignedTo,
    String? pendingApplicant,
    int? timestamp,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      assignedTo: assignedTo ?? this.assignedTo,
      pendingApplicant: pendingApplicant ?? this.pendingApplicant,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
