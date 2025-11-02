import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_constants.dart';
import '../../../models/item_model.dart';
import '../item_detail_screen.dart';
import '../full_screen_image.dart';

class ItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback? onTap;

  // FIX: Use super.key
  const ItemCard({super.key, required this.item, this.onTap});

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.pendingStatus:
        return Colors.orange;
      case AppConstants.verifiedStatus:
        return Colors.green;
      case AppConstants.returnedStatus:
        // FIX: Use a distinct color for 'returned' consistent with previous refactoring (e.g., purple or blue)
        return Colors.purple; 
      case AppConstants.rejectedStatus:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case AppConstants.lostType:
        return Colors.redAccent;
      case AppConstants.foundType:
        return Colors.green; // Adjusted to a primary green tone for better contrast/visibility
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime dateTime) {
    try {
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime.toLocal());
    } catch (_) {
      return dateTime.toLocal().toString().split('.')[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewImage = item.imagePaths?.isNotEmpty == true ? item.imagePaths!.first : null;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ??
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ItemDetailScreen(itemId: item.id),
                ),
              );
            },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with full screen view
              if (previewImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () {
                      if (item.imagePaths != null && item.imagePaths!.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenImage(imageUrls: item.imagePaths!),
                          ),
                        );
                      }
                    },
                    child: Image.network(
                      previewImage,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : Container(
                                  height: 150,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 150,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.image,
                    size: 50,
                    color: Colors.white70,
                  ),
                ),
              const SizedBox(height: 8),

              // Title, Type & Status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (item.type.isNotEmpty)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getTypeColor(item.type),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.type.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(item.status),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Text(
                          item.status.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        if (item.status == AppConstants.returnedStatus) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.check_circle,
                              size: 14, color: Colors.white),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Description
              Text(
                item.description,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Location
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.location,
                      style: const TextStyle(color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Verified Office
              // Ensure we only show item.verifiedOfficeId if the item is verified or returned
              if (item.verifiedOfficeId?.isNotEmpty == true && 
                  (item.status == AppConstants.verifiedStatus || item.status == AppConstants.returnedStatus))
                Row(
                  children: [
                    const Icon(Icons.apartment, size: 16, color: Colors.blueGrey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Verified at Office: ${item.verifiedOfficeId}',
                        style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),

              // Date
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Lost/Found Date: ${_formatDate(item.itemDateTime)}', // Added label for clarity
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}