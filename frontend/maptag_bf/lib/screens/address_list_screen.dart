import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/address_model.dart';

class AddressListScreen extends StatefulWidget {
  const AddressListScreen({super.key});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  List<AddressModel> _addresses = [];
  List<AddressModel> _filteredAddresses = [];
  bool _isLoading = true;
  String _selectedFilter = 'Toutes';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filterOptions = [
    'Toutes',
    'Synchronisées',
    'Non synchronisées',
    'Résidence',
    'Commerce',
    'Bureau',
    'École',
    'Santé',
    'Restaurant',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final addresses = await DatabaseService.instance.getAllAddresses();
      setState(() {
        _addresses = addresses;
        _filteredAddresses = addresses;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    List<AddressModel> filtered = List.from(_addresses);

    // Apply category/sync filter
    if (_selectedFilter != 'Toutes') {
      if (_selectedFilter == 'Synchronisées') {
        filtered = filtered.where((addr) => addr.code != null && addr.code!.isNotEmpty).toList();
      } else if (_selectedFilter == 'Non synchronisées') {
        filtered = filtered.where((addr) => addr.code == null || addr.code!.isEmpty).toList();
      } else {
        filtered = filtered.where((addr) => addr.category == _selectedFilter).toList();
      }
    }

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase().trim();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((addr) {
        return addr.placeName.toLowerCase().contains(searchQuery) ||
               (addr.code?.toLowerCase().contains(searchQuery) ?? false) ||
               addr.category.toLowerCase().contains(searchQuery);
      }).toList();
    }

    setState(() {
      _filteredAddresses = filtered;
    });
  }

  void _showAddressOptions(AddressModel address) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Voir détails'),
              onTap: () {
                Navigator.pop(context);
                _showAddressDetails(address);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Partager'),
              onTap: () {
                Navigator.pop(context);
                _shareAddress(address);
              },
            ),
            if (address.code != null && address.code!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.qr_code),
                title: const Text('Voir QR Code'),
                onTap: () {
                  Navigator.pop(context);
                  _showQRCode(address);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.pop(context);
                _editAddress(address);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteAddress(address);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddressDetails(AddressModel address) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(address.placeName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Code', address.code ?? 'En attente'),
            _buildDetailRow('Catégorie', address.category),
            _buildDetailRow('Position', '${address.latitude.toStringAsFixed(6)}, ${address.longitude.toStringAsFixed(6)}'),
            if (address.createdAt != null)
              _buildDetailRow('Créée le', '${address.createdAt!.day}/${address.createdAt!.month}/${address.createdAt!.year}'),
            _buildDetailRow('Synchronisée', (address.code != null && address.code!.isNotEmpty) ? 'Oui' : 'Non'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _shareAddress(AddressModel address) {
    final shareText = address.code != null && address.code!.isNotEmpty
        ? 'Adresse MapTag BF: ${address.placeName}\nCode: ${address.code}\nhttps://maptag.bf/${address.code}'
        : 'Adresse MapTag BF: ${address.placeName}\nPosition: ${address.latitude}, ${address.longitude}';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Partage: $shareText'),
        action: SnackBarAction(
          label: 'Copier',
          onPressed: () {
            // TODO: Implement clipboard copy
          },
        ),
      ),
    );
  }

  void _showQRCode(AddressModel address) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Affichage QR Code non implémenté')),
    );
  }

  void _editAddress(AddressModel address) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Modification non implémentée')),
    );
  }

  void _confirmDeleteAddress(AddressModel address) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'adresse'),
        content: Text('Voulez-vous vraiment supprimer "${address.placeName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAddress(address);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAddress(AddressModel address) async {
    try {
      if (address.id != null) {
        await DatabaseService.instance.deleteAddress(address.id!);
        await _loadAddresses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Adresse supprimée'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Adresses'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAddresses,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterAndSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAddresses.isEmpty
                    ? _buildEmptyState()
                    : _buildAddressList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.orange.shade100),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                      },
                    )
                  : null,
            ),
            onChanged: (value) => _applyFilters(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filterOptions.length,
              itemBuilder: (context, index) {
                final filter = _filterOptions[index];
                final isSelected = _selectedFilter == filter;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                      _applyFilters();
                    },
                    backgroundColor: Colors.white,
                    selectedColor: Colors.orange.shade100,
                    checkmarkColor: Colors.orange,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _addresses.isEmpty ? 'Aucune adresse créée' : 'Aucun résultat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _addresses.isEmpty 
                  ? 'Créez votre première adresse pour commencer'
                  : 'Modifiez vos filtres ou votre recherche',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (_addresses.isEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.add_location),
                label: const Text('Créer une adresse'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddressList() {
    return RefreshIndicator(
      onRefresh: _loadAddresses,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredAddresses.length,
        itemBuilder: (context, index) {
          final address = _filteredAddresses[index];
          return _buildAddressCard(address);
        },
      ),
    );
  }

  Widget _buildAddressCard(AddressModel address) {
    final isSynced = address.code != null && address.code!.isNotEmpty;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showAddressOptions(address),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(address.category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _getCategoryIcon(address.category),
                      color: _getCategoryColor(address.category),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address.placeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          address.code ?? 'Code en attente',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSynced ? Colors.green.shade100 : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSynced ? Icons.cloud_done : Icons.cloud_upload,
                              size: 12,
                              color: isSynced ? Colors.green.shade700 : Colors.orange.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isSynced ? 'Sync' : 'Local',
                              style: TextStyle(
                                fontSize: 10,
                                color: isSynced ? Colors.green.shade700 : Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        Icons.more_vert,
                        color: Colors.grey.shade400,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(
                    label: Text(
                      address.category,
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: _getCategoryColor(address.category).withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: _getCategoryColor(address.category),
                      fontSize: 10,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  if (address.createdAt != null)
                    Text(
                      '${address.createdAt!.day}/${address.createdAt!.month}/${address.createdAt!.year}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'résidence':
      case 'residence':
        return Colors.blue;
      case 'commerce':
        return Colors.green;
      case 'bureau':
        return Colors.purple;
      case 'école':
      case 'ecole':
        return Colors.orange;
      case 'santé':
      case 'sante':
        return Colors.red;
      case 'restaurant':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'résidence':
      case 'residence':
        return Icons.home;
      case 'commerce':
        return Icons.store;
      case 'bureau':
        return Icons.business;
      case 'école':
      case 'ecole':
        return Icons.school;
      case 'santé':
      case 'sante':
        return Icons.local_hospital;
      case 'restaurant':
        return Icons.restaurant;
      default:
        return Icons.location_on;
    }
  }
}