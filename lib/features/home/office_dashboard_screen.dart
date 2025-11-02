import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/items_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/app_constants.dart';
import '../auth/login_screen.dart';
import '../items/widgets/item_card.dart';
import '../auth/profile_screen.dart';
import '../items/item_detail_screen.dart';
import 'notifications_screen.dart';
import '../../../services/firestore_service.dart';

class OfficeDashboardScreen extends StatefulWidget {
  const OfficeDashboardScreen({super.key});

  @override
  State<OfficeDashboardScreen> createState() => _OfficeDashboardScreenState();
}

class _OfficeDashboardScreenState extends State<OfficeDashboardScreen> {
  int _currentIndex = 0;
  String _selectedTypeFilter = 'All';
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadItems());
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await Provider.of<ItemsProvider>(context, listen: false).fetchItems();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to load items: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query.toLowerCase());
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 16, right: 16, bottom: 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search items by title, location, or description...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildItemsList(List items, String? typeFilter) {
    final typeFiltered =
        typeFilter == 'All' ? items : items.where((i) => i.type == typeFilter).toList();

    final searchFiltered = typeFiltered.where((item) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery;
      return item.title.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query) ||
          item.location.toLowerCase().contains(query);
    }).toList();

    if (searchFiltered.isEmpty) {
      return const Center(
          child: Text('No items match the current filters or search query.'));
    }

    return RefreshIndicator(
      onRefresh: _loadItems,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: searchFiltered.length,
        itemBuilder: (_, i) {
          final item = searchFiltered[i];
          return ItemCard(
            item: item,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ItemDetailScreen(itemId: item.id),
                ),
              ).then((_) async => await _loadItems());
            },
          );
        },
      ),
    );
  }

  FilterChip _buildFilterChip(String label, String type, Color selectedColor) {
    return FilterChip(
      label: Text(label),
      selected: _selectedTypeFilter == type,
      onSelected: (_) => setState(() => _selectedTypeFilter = type),
      selectedColor: selectedColor,
      backgroundColor: Colors.white,
      labelStyle: const TextStyle(color: Colors.black),
    );
  }

  Widget _buildReportTab(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.share),
        label: const Text('Generate & Share Excel Report'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        onPressed: () async {
          if (!mounted) return;
          final messenger = ScaffoldMessenger.of(context);

          messenger.showSnackBar(
            const SnackBar(
              content:
                  Text('⏳ Generating Excel report and preparing share dialog...'),
              duration: Duration(seconds: 15),
              backgroundColor: Colors.blue,
            ),
          );

          try {
            await FirestoreService().exportAndShareExcel();
            if (!mounted) return;
            messenger.removeCurrentSnackBar();
            messenger.showSnackBar(
              const SnackBar(
                content:
                    Text('✅ Excel report ready! Please select a sharing app.'),
                duration: Duration(seconds: 5),
              ),
            );
          } catch (e) {
            if (!mounted) return;
            messenger.removeCurrentSnackBar();
            String errorMessage = 'Failed to generate report.';
            if (e.toString().contains('Storage permission not granted')) {
              errorMessage = 'Storage permission required to save the report.';
            } else if (e.toString().contains('Failed to generate Excel file')) {
              errorMessage = 'Error: Could not create the Excel file.';
            }
            messenger.showSnackBar(
              SnackBar(content: Text('❌ $errorMessage')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final itemsProvider = Provider.of<ItemsProvider>(context);

    if (auth.appUser == null || _isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final allItems = itemsProvider.items;
    final verifiedAndReturnedItems =
        allItems.where((i) => i.status == 'verified' || i.status == 'returned').toList();

    final tabs = [
      _buildItemsList(allItems, _selectedTypeFilter),
      _buildItemsList(verifiedAndReturnedItems, _selectedTypeFilter),
      _buildReportTab(context),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusTrack Office'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_currentIndex != 2) _buildSearchBar(),
          if (_currentIndex != 2)
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFilterChip('All', 'All', Colors.blue),
                  const SizedBox(width: 12),
                  _buildFilterChip('Lost', AppConstants.lostType, Colors.redAccent),
                  const SizedBox(width: 12),
                  _buildFilterChip('Found', AppConstants.foundType, Colors.green),
                ],
              ),
            ),
          Expanded(child: tabs[_currentIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() {
          _currentIndex = i;
          if (i == 2) _searchQuery = '';
        }),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'All Items'),
          BottomNavigationBarItem(icon: Icon(Icons.verified), label: 'Verified'),
          BottomNavigationBarItem(icon: Icon(Icons.share), label: 'Share Report'),
        ],
      ),
    );
  }
}
