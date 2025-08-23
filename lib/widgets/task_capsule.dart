import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskCapsule extends StatefulWidget {
  final Task task;
  final bool isSenior;
  final String? currentUserId;

  // Optional labels/actions
  final String? subtitle;
  final VoidCallback? onApply;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onMarkComplete;

  const TaskCapsule({
    super.key,
    required this.task,
    required this.isSenior,
    this.currentUserId,
    this.subtitle,
    this.onApply,
    this.onApprove,
    this.onReject,
    this.onMarkComplete,
  });

  @override
  State<TaskCapsule> createState() => _TaskCapsuleState();
}

class _TaskCapsuleState extends State<TaskCapsule> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final isAssignedToMe =
        widget.currentUserId != null && t.assignedTo == widget.currentUserId;

    // Status chip color
    Color chipColor;
    switch (t.status) {
      case 'open':
        chipColor = Colors.blue.shade100;
        break;
      case 'pendingApproval':
        chipColor = Colors.amber.shade100;
        break;
      case 'assigned':
        chipColor = Colors.green.shade100;
        break;
      case 'completed':
        chipColor = Colors.grey.shade300;
        break;
      default:
        chipColor = Colors.blueGrey.shade100;
    }

    // Flags for showing actions
    final canStudentApply =
        !widget.isSenior &&
        t.status == 'open' &&
        (t.pendingApplicant == null || t.pendingApplicant!.isEmpty);

    final canStudentMarkComplete =
        !widget.isSenior && t.status == 'assigned' && isAssignedToMe;

    final canSeniorApproveReject =
        widget.isSenior &&
        t.status == 'pendingApproval' &&
        t.pendingApplicant != null;

    final canSeniorMarkComplete = widget.isSenior && t.status == 'assigned';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title.isEmpty ? '(Untitled task)' : t.title,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _readableStatus(t.status),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.black54,
                ),
              ],
            ),

            // Expanded content
            AnimatedCrossFade(
              firstChild: const SizedBox(height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (t.description.isNotEmpty) ...[
                      Text(
                        t.description,
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _metaChip('Created by', t.createdBy),
                        _metaChip('Assigned to', t.assignedTo ?? '—'),
                        _metaChip('Pending', t.pendingApplicant ?? '—'),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Actions
                    Row(
                      children: [
                        if (canStudentApply && widget.onApply != null)
                          _pillButton(label: 'Apply', onTap: widget.onApply!),
                        if (canStudentMarkComplete &&
                            widget.onMarkComplete != null)
                          _pillButton(
                            label: 'Mark complete',
                            onTap: widget.onMarkComplete!,
                          ),
                        if (canSeniorApproveReject) ...[
                          if (widget.onApprove != null)
                            _pillButton(
                              label: 'Approve',
                              onTap: widget.onApprove!,
                            ),
                          if (widget.onReject != null)
                            _pillButton(
                              label: 'Reject',
                              onTap: widget.onReject!,
                              variant: _PillVariant.secondary,
                            ),
                        ],
                        if (canSeniorMarkComplete &&
                            widget.onMarkComplete != null)
                          _pillButton(
                            label: 'Mark complete',
                            onTap: widget.onMarkComplete!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
              sizeCurve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }

  String _readableStatus(String s) {
    switch (s) {
      case 'open':
        return 'Open';
      case 'pendingApproval':
        return 'Pending approval';
      case 'assigned':
        return 'Assigned';
      case 'completed':
        return 'Completed';
      default:
        return s;
    }
  }

  Widget _metaChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12.5, color: Colors.black87),
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required VoidCallback onTap,
    _PillVariant variant = _PillVariant.primary,
  }) {
    final bg = variant == _PillVariant.primary ? Colors.black : Colors.white;
    final fg = variant == _PillVariant.primary ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }
}

enum _PillVariant { primary, secondary }
