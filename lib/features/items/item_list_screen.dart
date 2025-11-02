import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/items_provider.dart';
import '../../../providers/auth_provider.dart';
import 'widgets/item_card.dart';

class ItemListScreen extends StatefulWidget {
  const ItemListScreen({Key? key}) : super(key: key);

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _refreshItems() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final itemsProvider = Provider.of<ItemsProvider>(context, listen: false);

      await itemsProvider.fetchItems(
        userId: auth.appUser?.role == 'user' ? auth.appUser?.uid : null,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '❌ Failed to load items. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_refreshItems);
  }

  @override
  Widget build(BuildContext context) {
    final itemsProvider = Provider.of<ItemsProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Lost & Found Items')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _refreshItems,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshItems,
                  child: itemsProvider.items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 200),
                            Center(child: Text('No items reported yet.')),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: itemsProvider.items.length,
                          itemBuilder: (_, index) {
                            final item = itemsProvider.items[index];
                            return ItemCard(item: item);
                          },
                        ),
                ),
      floatingActionButton: authProvider.appUser != null &&
              authProvider.appUser!.role == 'user'
          ? FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, '/add_item'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
