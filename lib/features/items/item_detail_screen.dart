import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/app_constants.dart';
import '../../../models/item_model.dart';
import '../../../providers/auth_provider.dart';
import '../../common/app_button.dart';
import 'full_screen_image.dart';
import '../office/verify_item_screen.dart';
import '../../services/firestore_service.dart';
import '../office/request_detail_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final String itemId;
  const ItemDetailScreen({required this.itemId, super.key});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _itemStream;
  Stream<List<Map<String, dynamic>>>? _myRequestStream;
  Map<String, dynamic>? _myRequestData;
  String? _myRequestId;
  final FirestoreService _fs = FirestoreService();
  bool _isDeleting = false; // New state for delete loading

  @override
  void initState() {
    super.initState();
    _itemStream = FirebaseFirestore.instance
        .collection(AppConstants.itemsCollection)
        .doc(widget.itemId)
        .snapshots();
  }

  Future<void> _handleVerifyScreen(ItemModel item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VerifyItemScreen(item: item)),
    );
    if (mounted && result == true) setState(() {});
  }

  Future<void> _handleRequestToCollect(ItemModel item) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final appUser = auth.appUser;
    if (appUser == null) return;
    try {
      final requestId = await _fs.addCollectionRequest(
        itemId: item.id,
        requesterId: appUser.uid,
        verifiedOfficeId: item.verifiedOfficeId ?? item.officeId,
      );
      if (mounted) {
        // Force a rebuild to update the request status
        setState(() {
          _myRequestId = requestId;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request sent to office/admin')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    }
  }

  // 🔑 NEW METHOD: Handles the deletion confirmation and execution
  Future<void> _confirmAndDeleteItem(ItemModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text(
              'Are you sure you want to delete this lost item report? This action cannot be undone and will remove the item from the public list.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Yes, Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() => _isDeleting = true);
      try {
        // Assuming your FirestoreService has a deleteItem method
        await _fs.deleteItem(item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report successfully deleted.')),
          );
          // Navigate back to the previous screen (the list) after deletion
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete report: $e')),
          );
          setState(() => _isDeleting = false);
        }
      }
    }
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return 'N/A';
    final dt = ts.toDate().toLocal();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  // Helper to determine if the user can send a new request
  bool _canSendNewRequest(ItemModel item, Map<String, dynamic>? latestRequest) {
    // 1. Check if the item is eligible (Found & Verified)
    final eligibleItem = (item.type.toLowerCase() == 'found') && (item.status == 'verified');
    if (!eligibleItem) return false;

    // 2. Check the status of the latest request
    if (latestRequest == null) return true; // No request yet, allow it.

    final status = latestRequest['status'] ?? 'requested';
    // Allow re-request only if the previous request was CANCELLED or RETURNED.
    return status == 'cancelled' || status == 'returned';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final appUser = auth.appUser;

    if (appUser != null) {
      // Logic to find the latest request for this item by the current user
      _myRequestStream = _fs.streamRequestsForUser(appUser.uid).map((requests) {
        final itemRequests =
            requests.where((r) => r['itemId'] == widget.itemId).toList();
        if (itemRequests.isNotEmpty) {
          itemRequests.sort((a, b) => (b['requestedAt'] as Timestamp)
              .compareTo(a['requestedAt'] as Timestamp));
          _myRequestData = itemRequests.first;
          _myRequestId = _myRequestData?['id'];
        } else {
          _myRequestData = null;
          _myRequestId = null;
        }
        return itemRequests;
      });
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _itemStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!.data()!;
        final item = ItemModel.fromMap({'id': snapshot.data!.id, ...data});
        final isOffice = appUser != null &&
            (appUser.isOfficeAdmin ||
                (item.officeId.isNotEmpty && item.officeId == appUser.officeId));
        final isAdmin = appUser?.isOfficeAdmin ?? false;
        final isUser = appUser != null && !isOffice;
        
        // 🔑 NEW CHECK: Check if the current user is the original uploader
        final isUploader = appUser != null && item.userId == appUser.uid;
        
        // 🔑 NEW CHECK: Determine if the delete button should be visible
        final canDeleteLostReport = isUploader && item.type.toLowerCase() == 'lost';

        final canRequest = isUser && _canSendNewRequest(item, _myRequestData);

        return Scaffold(
          appBar: AppBar(title: Text(item.title)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ... Image gallery (unchanged) ...
                if (item.imagePaths?.isNotEmpty == true)
                  SizedBox(
                    height: 250,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: item.imagePaths!.length,
                      itemBuilder: (context, index) {
                        final imageUrl = item.imagePaths![index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FullScreenImage(
                                      imageUrls: item.imagePaths!,
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                              },
                              child: Image.network(
                                imageUrl,
                                width: MediaQuery.of(context).size.width * 0.7,
                                height: 250,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) =>
                                    progress == null
                                        ? child
                                        : Container(
                                            width: MediaQuery.of(context).size.width * 0.7,
                                            height: 250,
                                            color: Colors.grey[300],
                                            child: const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          ),
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                    width: MediaQuery.of(context).size.width * 0.7,
                                    height: 250,
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.broken_image,
                                      size: 50,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    height: 250,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, size: 50),
                  ),
                const SizedBox(height: 16),
                // Item info (unchanged)
                Text('📝 Description: ${item.description}'),
                Text('📦 Type: ${item.type}'),
                Text('📍 Location: ${item.location}'),
                Text(
                  '📅 Reported on: ${DateFormat('dd MMM yyyy, hh:mm a').format(item.itemDateTime.toLocal())}',
                ),
                const SizedBox(height: 12),
                // Status chip (unchanged)
                Chip(
                  label: Text(
                    item.status.toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: item.status == 'returned' ? Colors.purple : Colors.grey,
                ),
                const SizedBox(height: 16),
                // Reporter Details (unchanged)
                if (item.userId.isNotEmpty)
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection(AppConstants.usersCollection)
                        .doc(item.userId)
                        .snapshots(),
                    builder: (context, userSnap) {
                      if (!userSnap.hasData || !userSnap.data!.exists) {
                        return const Text('Reporter details not available');
                      }
                      final userData = userSnap.data!.data()!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const Text(
                            '👤 Reporter Details',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text('Name: ${userData['name'] ?? 'N/A'}'),
                          Text('Email: ${userData['email'] ?? 'N/A'}'),
                          if ((userData['phoneNumber'] as String?)?.isNotEmpty ?? false)
                            Text('Phone: ${userData['phoneNumber']}'),
                          const Divider(),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 16),
                
                // 🛑 COLLECTED USER (RETURNED ITEM) SECTION
                if (item.status == 'returned' && item.returnedRequestId != null)
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection(AppConstants.collectionRequestsCollection)
                        .doc(item.returnedRequestId)
                        .snapshots(),
                    builder: (context, reqSnap) {
                      if (!reqSnap.hasData || !reqSnap.data!.exists)
                        return const SizedBox.shrink();
                      final requestData = reqSnap.data!.data()!;
                      final collectedUserId = requestData['requesterId'] as String?;
                      final idCardUrl = requestData['idCardUrl'] as String?;
                      final pickupTime = requestData['pickupTime'] as Timestamp?;
                      if (collectedUserId == null) return const SizedBox.shrink();
                      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection(AppConstants.usersCollection)
                            .doc(collectedUserId)
                            .snapshots(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData || !userSnap.data!.exists)
                            return const SizedBox.shrink();
                          final collectedUserData = userSnap.data!.data()!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              const Text(
                                '🛡 Collected By',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple),
                              ),
                              const SizedBox(height: 8),
                              // These details are visible to Admin/Office/User when the item is returned
                              Text('Collector Name: ${collectedUserData['name'] ?? 'N/A'}'),
                              Text('Collector Email: ${collectedUserData['email'] ?? 'N/A'}'),
                              if ((collectedUserData['phoneNumber'] as String?)?.isNotEmpty ?? false)
                                Text('Collector Phone: ${collectedUserData['phoneNumber']}'),
                              Text('Returned At: ${_formatTimestamp(item.returnedAt != null ? Timestamp.fromDate(item.returnedAt!) : null)}'),
                              if (pickupTime != null)
                                Text('Scheduled Pickup: ${_formatTimestamp(pickupTime)}'),
                              // ID Card visibility restricted only to Admin
                              if (isAdmin && (idCardUrl?.isNotEmpty ?? false))
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('ID Card Photo (Admin Only):',
                                          style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Image.network(
                                        idCardUrl!,
                                        height: 200,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.broken_image, size: 50),
                                      ),
                                    ],
                                  ),
                                ),
                              const Divider(),
                            ],
                          );
                        },
                      );
                    },
                  ),
                const SizedBox(height: 16),

                // 🛑 OFFICE/ADMIN BUTTON (VERIFY ITEM)
                if (isOffice && 
                    item.type.toLowerCase() == 'found' &&
                    item.status != 'returned') 
                  AppButton(
                    label: 'Go to Verify Screen',
                    onPressed: () => _handleVerifyScreen(item),
                  ),

                // 🔑 NEW: DELETE BUTTON FOR ORIGINAL UPLOADER OF LOST ITEM
                if (canDeleteLostReport) 
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: AppButton(
                      label: 'Delete Lost Report',
                      onPressed: _isDeleting ? null : () => _confirmAndDeleteItem(item),
                      isLoading: _isDeleting,
                      color: Colors.red,
                    ),
                  ),

                // 🛑 USER REQUEST SECTION
                if (isUser && item.type.toLowerCase() == 'found')
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _myRequestStream,
                    builder: (context, reqSnap) {
                      final latestRequest = _myRequestData;
                      final status = latestRequest?['status'] ?? 'none';
                      final pickupTs = latestRequest?['pickupTime'] as Timestamp?;
                      final notes = latestRequest?['notes'] as String?;

                      // 1. Terminal State: Item is already collected/returned.
                      if (item.status == 'returned') { 
                        return const AppButton(
                          label: 'Item Already Collected', 
                          onPressed: null,
                          color: Colors.purple,
                        );
                      }
                      
                      // 2. Non-actionable State: Item is pending/rejected, hide user actions.
                      if (item.status != 'verified') { 
                          return const SizedBox.shrink(); 
                      }

                      // 3. Actionable State: Show Request/Re-request buttons
                      if (canRequest) {
                        return _buildRequestArea(item);
                      }
                      
                      // 4. Ongoing State: Pickup is scheduled
                      if (status == 'scheduled') {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppButton(label: 'Pickup Scheduled', onPressed: null),
                            const SizedBox(height: 8),
                            Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: const Icon(Icons.calendar_today, color: Colors.green),
                                title: const Text('Pickup Scheduled'),
                                subtitle: Text(
                                    'When: ${_formatTimestamp(pickupTs)}\nNotes: ${notes ?? '—'}'),
                                onTap: () {
                                  if (_myRequestId != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RequestDetailScreen(
                                            requestId: _myRequestId!,
                                            itemId: item.id,
                                            requesterId: appUser.uid,
                                            verifiedOfficeId: item.verifiedOfficeId ?? '',
                                            isAdmin: false,
                                          ),
                                        ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      }
                      
                      // 5. Pending State: Waiting for office action
                      if (status == 'requested' || status == 'completed') {
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppButton(label: 'Requested (Pending Office Action)', onPressed: null),
                                const SizedBox(height: 8),
                                const Text('Waiting for office to schedule pickup.'),
                              ],
                          );
                      }
                      
                      // Fallback
                      return const SizedBox.shrink(); 
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // _buildRequestArea handles the 'Request' or 'Re-request' buttons.
  Widget _buildRequestArea(ItemModel item) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final appUser = auth.appUser;
    if (appUser == null) return const SizedBox.shrink();

    // The parent ensures item is 'found' and 'verified'.

    final status = _myRequestData?['status'];

    String label;
    Function()? onPressed;

    if (status == 'cancelled') {
      label = 'Re-request to Collect';
      onPressed = () => _handleRequestToCollect(item);
    } else { // This handles 'none' (first request)
      label = 'Request to Collect';
      onPressed = () => _handleRequestToCollect(item);
    }

    return AppButton(
      label: label,
      onPressed: onPressed,
    );
  }
}