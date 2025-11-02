import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async'; // REQUIRED for StreamSubscription

import '../../providers/auth_provider.dart';
import '../../utils/date_utils.dart';
import '../../utils/role_helper.dart';
import '../items/widgets/status_button.dart';
import '../items/item_detail_screen.dart';
import '../office/request_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final String? highlightItemId;

  const NotificationsScreen({super.key, this.highlightItemId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Set<String> _loadingDocs = {};
  final ScrollController _requestsScrollController = ScrollController();
  final ScrollController _newItemsScrollController = ScrollController();
  String? _highlightItemId;

  // FIX 1: Store StreamSubscriptions
  StreamSubscription? _requestsSubscription;
  StreamSubscription? _newItemsSubscription;

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _requestsCache = [];
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _newItemsCache = [];

  // Data Caches
  final Map<String, String> _userNamesCache = {};
  final Map<String, String> _itemTitlesCache = {};

  @override
  void initState() {
    super.initState();
    _highlightItemId = widget.highlightItemId;

    // Notification tap (safe to listen without explicit dispose)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final itemId = message.data['itemId']?.toString();
      if (itemId != null && mounted) {
        setState(() {
          _highlightItemId = itemId;
        });
        // We use addPostFrameCallback to ensure the widget has rendered
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHighlightedItem());
      }
    });

    if (_highlightItemId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHighlightedItem());
    }

    // FIX 1: Storing and listening to collection requests stream
    _requestsSubscription = FirebaseFirestore.instance
        .collection('collectionRequests')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _requestsCache
          ..clear()
          ..addAll(snapshot.docs)
          ..sort((a, b) {
            final aTime = (a.data()['requestedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
            final bTime = (b.data()['requestedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
            return bTime.compareTo(aTime);
          });
      });
    });

    // FIX 1: Storing and listening to new items stream
    _newItemsSubscription = FirebaseFirestore.instance
        .collection('items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _newItemsCache
          ..clear()
          ..addAll(snapshot.docs)
          ..sort((a, b) {
            final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
            final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
            return bTime.compareTo(aTime);
          });
      });
    });
  }

  @override
  void dispose() {
    // FIX 1: Cancel stream subscriptions to avoid memory leaks
    _requestsSubscription?.cancel();
    _newItemsSubscription?.cancel();

    _requestsScrollController.dispose();
    _newItemsScrollController.dispose();
    super.dispose();
  }

  // ... (Other helper methods: _fetchRequesterName, _fetchItemTitle, _fetchRequestData, _updateRequestStatus are fine)

  Future<String> _fetchRequesterName(String requesterId) async {
    if (_userNamesCache.containsKey(requesterId)) return _userNamesCache[requesterId]!;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(requesterId).get();
      final name = userDoc.data()?['name'] ?? 'Unknown Requester';
      _userNamesCache[requesterId] = name;
      return name;
    } catch (_) {
      return 'Error fetching name';
    }
  }

  Future<String> _fetchItemTitle(String itemId) async {
    if (_itemTitlesCache.containsKey(itemId)) return _itemTitlesCache[itemId]!;
    try {
      final itemDoc = await FirebaseFirestore.instance.collection('items').doc(itemId).get();
      final title = itemDoc.data()?['title'] ?? 'Untitled Item';
      _itemTitlesCache[itemId] = title;
      return title;
    } catch (_) {
      return 'Error fetching title';
    }
  }

  Future<Map<String, String>> _fetchRequestData(
      bool isAdmin, String requesterId, String itemId) async {
    String requesterName = '';
    if (isAdmin && requesterId.isNotEmpty) {
      requesterName = await _fetchRequesterName(requesterId);
    }
    String itemTitle = await _fetchItemTitle(itemId);
    return {
      'requester': requesterName,
      'title': itemTitle,
    };
  }

  Future<void> _updateRequestStatus(String docId, String status) async {
    setState(() {
      _loadingDocs.add(docId);
    });
    try {
      await FirebaseFirestore.instance.collection('collectionRequests').doc(docId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Request status updated to $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error updating request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() {
        _loadingDocs.remove(docId);
      });
    }
  }

  // NOTE: This scroll logic is prone to breaking if list item height is variable.
  void _scrollToHighlightedItem() {
    int index = _requestsCache.indexWhere((d) => d.id == _highlightItemId);
    if (index >= 0 && _requestsScrollController.hasClients) {
      _requestsScrollController.animateTo(
        index * 120.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      return;
    }
    index = _newItemsCache.indexWhere((d) => d.id == _highlightItemId);
    if (index >= 0 && _newItemsScrollController.hasClients) {
      _newItemsScrollController.animateTo(
        index * 120.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  // ... (_buildCollectionRequestsSection and _buildNewItemsSection are fine)

  Widget _buildCollectionRequestsSection(
      String userId, bool isAdmin, String? verifiedOfficeId) {
    final requests = _requestsCache.where((doc) {
      final data = doc.data();
      if (isAdmin) {
        // Admin views requests for their assigned office
        return (data['verifiedOfficeId'] ?? '') == (verifiedOfficeId ?? '');
      } else {
        // User views requests they made
        return (data['requesterId'] ?? '') == userId;
      }
    }).toList();

    if (requests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          isAdmin ? 'No collection requests for your office.' : 'No collection requests made by you.',
        ),
      );
    }

    return ListView.builder(
      key: const PageStorageKey('collectionRequestsList'),
      controller: _requestsScrollController,
      // FIX: Use a dedicated list scroll controller if possible, or leave this as is if you rely on SingleChildScrollView
      // If the parent is SingleChildScrollView, NeverScrollableScrollPhysics is correct.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), 
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final doc = requests[index];
        final data = doc.data();
        final status = (data['status'] ?? 'requested').toString().toLowerCase();
        final docId = doc.id;
        final highlight = data['itemId'] == _highlightItemId;
        final pickupTime = data['pickupTime'] as Timestamp?;
        final requesterId = data['requesterId'] ?? '';
        final itemId = data['itemId'] ?? '';
        final isRequester = !isAdmin && requesterId == userId;
        final disableActions = status == 'returned' || status == 'cancelled';

        Color? cardColor;
        if (highlight) {
          cardColor = Colors.yellow[100];
        } else if (status == 'scheduled') {
          cardColor = Colors.green[50];
        } else if (status == 'returned') {
          cardColor = Colors.blue[50];
        } else if (status == 'cancelled') {
          cardColor = Colors.red[50];
        }

        return FutureBuilder<Map<String, String>>(
          future: _fetchRequestData(isAdmin, requesterId, itemId),
          builder: (context, snapshot) {
            final requesterName = snapshot.data?['requester'] ?? '';
            final itemTitle = snapshot.data?['title'] ?? '';

            final titleText =
                isAdmin ? 'Requester: $requesterName' : 'Request for: $itemTitle';
            final subtitleText =
                isAdmin ? 'Item: $itemTitle' : 'Status: ${status.toUpperCase()}';

            return Card(
              key: ValueKey(docId),
              color: cardColor,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Icon(
                  Icons.request_page,
                  color: status == 'scheduled'
                      ? Colors.green
                      : status == 'returned'
                          ? Colors.purple
                          : status == 'cancelled'
                              ? Colors.red
                              : Colors.orange,
                ),
                title: Text(titleText),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subtitleText),
                    Text('Requested: ${DateUtilsHelper.formatTime(data['requestedAt'])}'),
                    if (pickupTime != null)
                      Text('Pickup: ${DateUtilsHelper.formatTime(pickupTime)}'),
                  ],
                ),
                trailing: disableActions
                    ? Chip(
                        label: Text(status.toUpperCase(),
                            style: const TextStyle(fontSize: 10)),
                        backgroundColor:
                            status == 'returned' ? Colors.purple[100] : Colors.red[100],
                      )
                    : StatusButton(
                        status: status,
                        isAdmin: isAdmin,
                        isRequester: isRequester,
                        isLoading: _loadingDocs.contains(docId),
                        onApprove: isAdmin
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RequestDetailScreen(
                                      requestId: docId,
                                      itemId: itemId,
                                      requesterId: requesterId,
                                      verifiedOfficeId: data['verifiedOfficeId'] ?? '',
                                      isAdmin: true,
                                    ),
                                  ),
                                )
                            : null,
                        onCancel: isAdmin ? () => _updateRequestStatus(docId, 'cancelled') : null,
                      ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequestDetailScreen(
                        requestId: docId,
                        itemId: itemId,
                        requesterId: requesterId,
                        verifiedOfficeId: data['verifiedOfficeId'] ?? '',
                        isAdmin: isAdmin,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNewItemsSection() {
    if (_newItemsCache.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('No new items reported yet.'),
      );
    }

    return ListView.builder(
      key: const PageStorageKey('newItemsList'),
      controller: _newItemsScrollController,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _newItemsCache.length,
      itemBuilder: (context, index) {
        final data = _newItemsCache[index].data();
        final itemId = _newItemsCache[index].id;
        final highlight = itemId == _highlightItemId;

        return Card(
          key: ValueKey(itemId),
          color: highlight ? Colors.yellow[100] : null,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Icon(
              data['type']?.toString().toLowerCase() == 'lost'
                  ? Icons.report
                  : Icons.find_in_page,
              color: data['type']?.toString().toLowerCase() == 'lost'
                  ? Colors.red
                  : Colors.green,
            ),
            title: Text('${data['title'] ?? 'Item'} (${data['type'] ?? ''})'),
            subtitle: Text(
              'Location: ${data['location'] ?? 'Unknown'}\nReported: ${DateUtilsHelper.formatTime(data['createdAt'])}',
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: itemId)),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.appUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isAdmin = RoleHelper.isAdmin(user.role);
    return Scaffold(
      appBar: AppBar(title: const Text('🔔 Notifications')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '📬 Collection Requests',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            _buildCollectionRequestsSection(user.uid, isAdmin, user.officeId),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '📢 New Items Reported',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            _buildNewItemsSection(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}