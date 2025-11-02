import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/auth_provider.dart';
import '../../models/item_model.dart';
import '../../core/app_constants.dart';
import '../items/add_item_screen.dart';
import '../items/widgets/item_card.dart';
import '../auth/login_screen.dart';
import '../auth/profile_screen.dart';
import 'notifications_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  int _currentIndex = 0;
  String _selectedTypeFilter = 'All';

  // NEW: State for the search query
  String _searchQuery = '';

  // Helper for Search Query change
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  // NEW: Search Input Widget
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

  Stream<List<ItemModel>> _itemsStream() {
    return FirebaseFirestore.instance
        .collection(AppConstants.itemsCollection)
        .orderBy(AppConstants.dateTimeField, descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return ItemModel.fromMap(data);
            }).toList());
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

  // UPDATED: Filter items by both type and search query
  Widget _buildTabContent(List<ItemModel> items, String? userId) {
    // 1. Filter by Type
    final typeFiltered = _selectedTypeFilter == 'All'
        ? items
        : items.where((i) => i.type == _selectedTypeFilter).toList();

    // 2. Filter by Search Query
    final searchFiltered = typeFiltered.where((item) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery;
      return item.title.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query) ||
          item.location.toLowerCase().contains(query);
    }).toList();

    // Determine the list based on the current tab
    final listToShow = _currentIndex == 1
        ? searchFiltered.where((i) => i.userId == userId).toList()
        : searchFiltered;

    final tabs = [
      // 0: All Items
      RefreshIndicator(
        onRefresh: () async => Future.delayed(const Duration(milliseconds: 300)),
        child: listToShow.isEmpty
            ? const Center(
                child: Text('No items match the current filters or search query.'))
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: listToShow.length,
                itemBuilder: (_, i) => ItemCard(item: listToShow[i]),
              ),
      ),
      // 1: My Items
      RefreshIndicator(
        onRefresh: () async => Future.delayed(const Duration(milliseconds: 300)),
        child: listToShow.isEmpty
            ? const Center(
                child: Text('You have not reported any items or none match the search.'))
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: listToShow.length,
                itemBuilder: (_, i) => ItemCard(item: listToShow[i]),
              ),
      ),
      // 2: Report/Add Item
      Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Report Lost/Found Item'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddItemScreen()),
            );
          },
        ),
      ),
    ];

    return tabs[_currentIndex];
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userId = auth.appUser?.uid;

    if (auth.appUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<List<ItemModel>>(
      stream: _itemsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('❌ Error loading items: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final items = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: const Text('CampusTrack User'),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications),
                tooltip: 'Notifications',
                onPressed: () {
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.person),
                tooltip: 'Profile',
                onPressed: () {
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
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
              Expanded(child: _buildTabContent(items, userId)),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) {
              if (i == 2) {
                Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const AddItemScreen()));
              } else {
                setState(() {
                  _currentIndex = i;
                  _searchQuery = '';
                });
              }
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.feed), label: 'All Items'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'My Items'),
              BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Report'),
            ],
          ),
        );
      },
    );
  }
}
