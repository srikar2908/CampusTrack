import 'package:flutter/material.dart';

class StatusButton extends StatelessWidget {
  final String status;
  final bool isAdmin;
  final bool isRequester;
  final bool isLoading;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onCompleted; // This is used to trigger navigation to Mark Returned flow
  final VoidCallback? onCancel;
  final VoidCallback? onReschedule;

  const StatusButton({
    super.key,
    required this.status,
    required this.isAdmin,
    this.isRequester = false,
    this.isLoading = false,
    this.onApprove,
    this.onReject,
    this.onCompleted,
    this.onCancel,
    this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    if (isAdmin) {
      if (status == 'requested') {
        return ElevatedButton(
          // onApprove here means navigating to the scheduling screen
          onPressed: isLoading ? null : onApprove, 
          child: isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Schedule Pickup'),
        );
      } else if (status == 'scheduled' || status == 'completed') {
        // Admin sees a button to initiate the final verification/return process 
        // (which leads to the RequestDetailScreen with the "Mark as Returned" button)
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              // onCompleted here navigates to RequestDetailScreen for "Mark as Returned" flow
              onPressed: isLoading ? null : onCompleted,
              child: isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Finalize Return'), // Clearer label for the admin action
            ),
            const SizedBox(width: 8),
            // Reschedule button is useful if status is 'scheduled'
            if (status == 'scheduled' && onReschedule != null)
              IconButton(
                tooltip: 'Reschedule',
                onPressed: isLoading ? null : onReschedule,
                icon: const Icon(Icons.edit_calendar),
              ),
          ],
        );
      } else if (status == 'returned') {
        return const Text('✅ Returned', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)); // Explicit status for final state
      } else if (status == 'cancelled') {
        return const Text('❌ Cancelled', style: TextStyle(color: Colors.red));
      } else {
        return Text(status);
      }
    } else if (isRequester) {
      if (status == 'requested' || status == 'scheduled' || status == 'completed') {
        // Allow user to cancel request unless it's already completed/returned/cancelled
        return TextButton(
          onPressed: isLoading ? null : onCancel,
          child: isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Cancel Request'),
        );
      }
    }
    return const SizedBox();
  }
}