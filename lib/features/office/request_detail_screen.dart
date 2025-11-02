import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';

class RequestDetailScreen extends StatefulWidget {
  final String requestId;
  final String itemId;
  final String requesterId;
  final String verifiedOfficeId;
  final bool isAdmin;
  const RequestDetailScreen({
    required this.requestId,
    required this.itemId,
    required this.requesterId,
    required this.verifiedOfficeId,
    required this.isAdmin,
    super.key,
  });

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  DateTime? _pickedDateTime;
  final TextEditingController _notesController = TextEditingController();
  bool _loading = false;
  Uint8List? _idImageBytes;
  final FirestoreService _fs = FirestoreService();
  final ImagePicker _picker = ImagePicker();
  
  // State for fetched request data
  String _currentStatus = 'loading';
  Timestamp? _currentPickupTime;
  String? _idCardUrl;
  
  // 🛑 FIX: State for fetched user data (Name, Email, Phone)
  String? _requesterName;
  String? _requesterEmail;
  String? _requesterPhone;

  @override
  void initState() {
    super.initState();
    _fetchRequestAndUserData();
  }

  Future<void> _fetchRequestAndUserData() async {
    setState(() => _loading = true);
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('collectionRequests')
          .doc(widget.requestId)
          .get();
      final data = requestDoc.data();
      if (data != null) {
        _currentStatus = data['status'] ?? 'requested';
        _currentPickupTime = data['pickupTime'] as Timestamp?;
        _idCardUrl = data['idCardUrl'];
        _notesController.text = data['notes'] ?? '';
      }
      
      // 🛑 FIX: Fetch full requester details
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.requesterId)
          .get();
      final userData = userDoc.data();
      _requesterName = userData?['name'] ?? 'Unknown Requester';
      _requesterEmail = userData?['email'];
      _requesterPhone = userData?['phoneNumber'];
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load request details: $e')),
        );
      }
      _currentStatus = 'error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 🛠️ CHANGE 1: Use 'hh:mm a' format for 12-hour display
  String _format(DateTime dt) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return 'N/A';
    final dt = ts.toDate().toLocal();
    return _format(dt);
  }

  // PICK DATE & TIME
  Future<void> _pickDateTime() async {
    if (!mounted) return;
    
    final now = DateTime.now();
    
    // Use the currently scheduled time or tomorrow morning as the initial date
    final initialDate = (_currentPickupTime?.toDate().toLocal() ?? now)
        .isBefore(now) 
        ? now.add(const Duration(days: 1))
        : (_currentPickupTime?.toDate().toLocal() ?? now);

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 1)), // Allow today
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null) return;

    if (!mounted) return;

    final initialTime = TimeOfDay.fromDateTime(_currentPickupTime?.toDate().toLocal() ?? now);
    
    // 🛠️ CHANGE 2: Set use24HourFormat to false to ensure 12-hour picker on all platforms
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime, 
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      }
    );
    if (time == null) return;

    setState(() {
      _pickedDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  // SCHEDULE PICKUP (Admin)
  Future<void> _schedulePickup() async {
    if (_pickedDateTime == null && _currentStatus != 'scheduled') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick date & time first')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final fullNote =
          "${_notesController.text.trim()}${_notesController.text.trim().isEmpty ? "" : ". "}Bring your ID card for verification.";
      
      final selectedPickupTime = _pickedDateTime ?? _currentPickupTime?.toDate().toLocal();
      
      if (selectedPickupTime == null && _currentStatus != 'scheduled') {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pickup time must be set.')),
            );
        }
        return;
      }
      
      await _fs.updateCollectionRequestStatus(
        requestId: widget.requestId,
        status: 'scheduled',
        pickupTime: selectedPickupTime, 
        notes: fullNote,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pickup scheduled successfully')),
        );
        Navigator.of(context).pop(true); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to schedule: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // CAPTURE ID CARD (Admin Only)
  Future<void> _captureIdCard() async {
    try {
      final picked =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 75);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _idImageBytes = bytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID card captured successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing ID card: $e')),
        );
      }
    }
  }

  // MARK AS RETURNED
  Future<void> _markAsReturned() async {
    if (_idImageBytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture ID card photo first')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await _fs.markRequestAsReturnedWithId(
        requestId: widget.requestId,
        itemId: widget.itemId,
        idImageBytes: _idImageBytes!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item marked as returned successfully')),
        );
        Navigator.of(context).pop(true); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to mark as returned: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // CANCEL COLLECTION REQUEST
  Future<void> _cancelRequest() async {
    if (!mounted) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: const Text('Do you want to cancel this collection request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);

    try {
      await _fs.updateCollectionRequestStatus(
        requestId: widget.requestId,
        status: 'cancelled',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request cancelled successfully')),
        );
        Navigator.of(context).pop(true); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to cancel: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // UI
  @override
  Widget build(BuildContext context) {
    if (_loading && _currentStatus == 'loading') {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    final isFinalStatus =
        _currentStatus == 'returned' || _currentStatus == 'cancelled';

    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Request ID: ${widget.requestId}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            // Common Details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Requester: ${_requesterName ?? '...'}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    // 🛑 FIX: Show requester contact details for Admin/Office
                    if (widget.isAdmin) ...[
                      Text('Email: ${_requesterEmail ?? 'N/A'}'),
                      Text('Phone: ${_requesterPhone ?? 'N/A'}'),
                      const SizedBox(height: 8),
                    ],
                    Text('Status: ${_currentStatus.toUpperCase()}',
                        style: TextStyle(
                            color: isFinalStatus ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold)),
                    if (_currentPickupTime != null)
                      Text('Scheduled Pickup: ${_formatTimestamp(_currentPickupTime)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // READ-ONLY Summary for Final Statuses
            if (isFinalStatus) ...[
              const Divider(height: 30, thickness: 1),
              Text(
                'Request Finalized: ${_currentStatus.toUpperCase()}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              if (_idCardUrl != null && _currentStatus == 'returned')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ID Card Proof (Collected)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Image.network(
                        _idCardUrl!,
                        height: 250,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 50),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 30, thickness: 1),
            ],
            // Action buttons (Conditional Rendering)
            if (widget.isAdmin && !isFinalStatus) ...[
              // PICK DATE & TIME
              ElevatedButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _pickedDateTime == null
                      ? 'Pick/Reschedule date & time'
                      : _format(_pickedDateTime!),
                ),
              ),
              const SizedBox(height: 16),
              // NOTES
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes for Requester (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              // SCHEDULE PICKUP
              ElevatedButton(
                onPressed: _loading ? null : _schedulePickup,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Schedule Pickup'),
              ),
              const SizedBox(height: 20),
              const Divider(height: 30, thickness: 1),
              // ADMIN RETURN ITEM SECTION
              const Text(
                'Return Item (Admin Only)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // CAPTURE ID CARD
              OutlinedButton.icon(
                icon: const Icon(Icons.credit_card, color: Colors.blue),
                label: const Text('Capture ID Card Photo'),
                onPressed: _loading ? null : _captureIdCard,
              ),
              if (_idImageBytes != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _idImageBytes!,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              // MARK AS RETURNED
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: _loading ? null : _markAsReturned,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Mark as Returned'),
              ),
            ],
            const SizedBox(height: 30),
            // CANCEL REQUEST (Always available if not final, for both admin and user)
            if (!isFinalStatus)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _loading ? null : _cancelRequest,
                child: const Text('Cancel Request'),
              ),
          ],
        ),
      ),
    );
  }
}