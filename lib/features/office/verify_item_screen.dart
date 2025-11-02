import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/items_provider.dart';
import '../../utils/role_helper.dart';
import '../../common/app_button.dart';
import '../items/widgets/item_card.dart';

class VerifyItemScreen extends StatefulWidget {
  final ItemModel item;
  // FIX: Updated constructor to use super.key
  const VerifyItemScreen({super.key, required this.item}); 

  @override
  State<VerifyItemScreen> createState() => _VerifyItemScreenState();
}

class _VerifyItemScreenState extends State<VerifyItemScreen> {
  bool _loading = false;

  Future<void> _updateItemStatus(String status, String successMessage) async {
    // Note: Provider.of(context, listen: false) is fine here before the first await
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);
    if (auth.appUser == null) return;

    setState(() => _loading = true);

    try {
      await itemsProvider.updateItemStatus(
        itemId: widget.item.id,
        status: status,
        verifiedBy: auth.appUser!.uid,
        verifiedOfficeId: auth.appUser!.officeId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );

      // This navigation is safe after the mounted check
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to update: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildActionButtons() {
    final item = widget.item;
    // Note: Provider.of(context, listen: false) is safe here inside build method
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isAuthorized =
        auth.appUser != null && RoleHelper.isAdmin(auth.appUser!.role);

    if (!isAuthorized) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'You are not authorized to modify this item.',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      );
    }

    switch (item.status) {
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Approve',
                onPressed: _loading
                    ? null
                    : () =>
                        _updateItemStatus('verified', '✅ Item approved successfully'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: 'Reject',
                onPressed: _loading
                    ? null
                    : () async {
                        // FIX: Added mounted check after showDialog
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Confirm Rejection'),
                            content: const Text(
                                'Are you sure you want to reject this item?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Reject'),
                              ),
                            ],
                          ),
                        );
                        
                        // Check mounted before using context/state afterward
                        if (!mounted) return;

                        if (confirm == true) {
                          _updateItemStatus(
                              'rejected', '❌ Item rejected successfully');
                        }
                      },
              ),
            ),
          ],
        );
      case 'verified':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '✅ Item verified, awaiting collection request',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        );
      case 'returned':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '✅ Item already returned',
            style: TextStyle(color: Colors.green),
            textAlign: TextAlign.center,
          ),
        );
      case 'rejected':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '❌ Item rejected',
            style: TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        );
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Assuming ItemCard is a display widget and doesn't update status
            ItemCard(item: item), 
            const SizedBox(height: 20),
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildActionButtons(),
          ],
        ),
      ),
    );
  }
}