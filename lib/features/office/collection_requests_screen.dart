import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../models/item_model.dart';
import '../items/item_detail_screen.dart';
import '../../common/loading_indicator.dart';
import 'request_detail_screen.dart';

class CollectionRequestsScreen extends StatefulWidget {
  const CollectionRequestsScreen({Key? key}) : super(key: key);
  @override
  State<CollectionRequestsScreen> createState() =>
      _CollectionRequestsScreenState();
}

class _CollectionRequestsScreenState extends State<CollectionRequestsScreen> {
  late Stream<QuerySnapshot> _requestsStream;
  late AuthProvider _authProvider;
  late bool _isOffice;
  final Map<String, String> _userNamesCache = {}; // Cache for user names

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    final appUser = _authProvider.appUser;
    if (appUser == null) return;
    _isOffice = appUser.isAdmin || appUser.role == 'staff';
    _requestsStream = _isOffice
        ? FirebaseFirestore.instance
            .collection('collectionRequests')
            .where('verifiedOfficeId', isEqualTo: appUser.officeId)
            .orderBy('requestedAt', descending: true)
            .snapshots()
        : FirebaseFirestore.instance
            .collection('collectionRequests')
            .where('requesterId', isEqualTo: appUser.uid)
            .orderBy('requestedAt', descending: true)
            .snapshots();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'requested':
        return Colors.orange;
      case 'scheduled':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'returned':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal());
  }

  Future<String> _fetchRequesterName(String requesterId) async {
    if (_userNamesCache.containsKey(requesterId)) {
      return _userNamesCache[requesterId]!;
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(requesterId)
          .get();
      final name = userDoc.data()?['name'] ?? 'Unknown Requester';
      _userNamesCache[requesterId] = name;
      return name;
    } catch (e) {
      return 'Error fetching name';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collection Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _requestsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No collection requests'));
          }
          final requests = snapshot.data!.docs;
          final isAdmin = _authProvider.appUser?.isAdmin ?? false;
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final doc = requests[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final requestId = doc.id;
              final status = data['status'] ?? 'requested';
              final requestedAt = data['requestedAt'] as Timestamp?;
              final pickupTime = data['pickupTime'] as Timestamp?;
              final requesterId = data['requesterId'] ?? '';
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection(AppConstants.itemsCollection)
                    .doc(data['itemId'])
                    .get(),
                builder: (context, itemSnap) {
                  if (!itemSnap.hasData) return const LoadingIndicator();
                  final itemData =
                      itemSnap.data!.data() as Map<String, dynamic>? ?? {};
                  final item = ItemModel.fromMap({
                    'id': itemSnap.data!.id,
                    ...itemData,
                  });
                  return FutureBuilder<String>(
                    // 🛑 FIX: Fetch Requester Name for Admin/Office
                    future: _isOffice && requesterId.isNotEmpty
                        ? _fetchRequesterName(requesterId)
                        : Future.value(item.title),
                    builder: (context, nameSnap) {
                      final nameOrTitle = nameSnap.hasData ? nameSnap.data! : 'Loading...';
                      
                      // 🛑 FIX: Prioritize Requester Name for Admin/Office, Item Title for User
                      final titleText = _isOffice
                          ? 'Requester: ${nameOrTitle}'
                          : item.title; 
                          
                      // 🛑 FIX: Item Title in Subtitle for Admin/Office to aid identification
                      final itemSubtitle = _isOffice ? 'Item: ${item.title}' : '';
                      
                      final disableActions = status == 'returned' || status == 'cancelled';
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        color: disableActions ? Colors.grey[50] : null,
                        child: ListTile(
                          title: Text(titleText),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_isOffice) Text(itemSubtitle),
                              Text('Requested on: ${_formatDate(requestedAt)}'),
                              Text(
                                'Status: ${status.toUpperCase()}',
                                style: TextStyle(
                                    color: _getStatusColor(status),
                                    fontWeight: FontWeight.bold),
                              ),
                              if (pickupTime != null)
                                Text('Pickup: ${_formatDate(pickupTime)}'),
                            ],
                          ),
                          trailing: _isOffice
                              ? (disableActions
                                  ? Chip(
                                      label: Text(status.toUpperCase(),
                                          style: const TextStyle(fontSize: 10)),
                                      backgroundColor: status == 'returned'
                                          ? Colors.purple[100]
                                          : Colors.red[100],
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.schedule,
                                          color: Colors.blue),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => RequestDetailScreen(
                                              requestId: requestId,
                                              itemId: data['itemId'] ?? '',
                                              requesterId: requesterId,
                                              verifiedOfficeId:
                                                  data['verifiedOfficeId'] ?? '',
                                              isAdmin: isAdmin,
                                            ),
                                          ),
                                        );
                                      },
                                    ))
                              : null,
                          // 🛑 FIX: Admin/Office must navigate to RequestDetailScreen even for final status
                          onTap: () {
                            if (_isOffice) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RequestDetailScreen(
                                    requestId: requestId,
                                    itemId: data['itemId'] ?? '',
                                    requesterId: requesterId,
                                    verifiedOfficeId:
                                        data['verifiedOfficeId'] ?? '',
                                    isAdmin: isAdmin,
                                  ),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ItemDetailScreen(itemId: item.id)),
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}