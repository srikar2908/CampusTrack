import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/items_provider.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_strings.dart';
import '../../../common/app_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeProviders());
  }

  void _initializeProviders() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);

    authProvider.fetchCurrentUser().then((_) {
      if (authProvider.appUser != null && mounted) {
        itemsProvider.init(userId: authProvider.appUser!.uid);
      }
    });
  }

  Future<void> _editField(BuildContext context, String fieldName, String currentValue,
      Function(String) onSave) async {
    final controller = TextEditingController(text: currentValue);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit $fieldName'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: fieldName,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onSave(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Consumer2<AuthProvider, ItemsProvider>(
          builder: (context, authProvider, itemsProvider, child) {
            final user = authProvider.appUser;

            if (user == null) {
              if (authProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              return const Center(child: Text('No user found. Please log in.'));
            }

            final userItems = itemsProvider.items;
            final totalItems = userItems.length;
            final verifiedItems = userItems
                .where((i) => i.status == AppConstants.verifiedStatus)
                .length;
            final returnedItems = userItems
                .where((i) => i.status == AppConstants.returnedStatus)
                .length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Icon(Icons.account_circle, size: 80, color: Colors.blueGrey),
                ),
                const Divider(height: 32),

                // === Editable Name ===
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('Name: ${user.name}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editField(context, 'Name', user.name, (newValue) async {
                        await authProvider.updateUser({'name': newValue});
                        setState(() {}); // Refresh UI
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Email (non-editable)
                Text('Email: ${user.email}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),

                // Role
                Text('Role: ${user.role.isNotEmpty ? user.role : 'N/A'}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),

                // === Editable Phone Number ===
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Phone: ${user.phoneNumber.isNotEmpty ? user.phoneNumber : 'N/A'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editField(context, 'Phone Number', user.phoneNumber,
                          (newValue) async {
                        await authProvider.updateUser({'phoneNumber': newValue});
                        setState(() {});
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Office ID (only for office admins)
                if (user.role == AppConstants.officeAdminRole)
                  Text(
                    'Office ID: ${user.officeId.isNotEmpty ? user.officeId : 'N/A'}',
                    style: const TextStyle(fontSize: 16),
                  ),

                const Divider(height: 32),

                // === Item Stats ===
                const Text('Your Item Stats:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Total reported: $totalItems', style: const TextStyle(fontSize: 16)),
                Text('Verified: $verifiedItems',
                    style: const TextStyle(fontSize: 16, color: Colors.green)),
                Text('Returned: $returnedItems',
                    style: const TextStyle(fontSize: 16, color: Colors.purple)),

                const SizedBox(height: 30),

                // === Logout Button ===
                AppButton(
                  label: AppStrings.logout,
                  onPressed: authProvider.isLoading
                      ? null
                      : () async {
                          itemsProvider.clear();
                          await authProvider.logout();
                          Navigator.of(context)
                              .pushNamedAndRemoveUntil('/login', (route) => false);
                        },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
