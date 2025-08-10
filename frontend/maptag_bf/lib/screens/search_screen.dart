import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../models/address_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<AddressModel> _searchResults = [];
  List<AddressModel> _localResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _localResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      // Search locally first
      final localResults = await DatabaseService.instance.searchAddresses(query);
      
      setState(() {
        _localResults = localResults;
      });

      // Then search on server if connected
      final serverResponse = await ApiService.searchAddresses(search: query);
      
      if (serverResponse.isSuccess) {
        setState(() {
          _searchResults = serverResponse.data!;
        });
      } else if (!serverResponse.isNetworkError) {
        // Show error only if it's not a network issue
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de recherche: ${serverResponse.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _showAddressDetails(AddressModel address) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddressDetailsSheet(address: address),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechercher Adresse'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.blue.shade100),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher par nom ou code...',
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
                        _performSearch('');
                      },
                    )
                  : null,
            ),
            onChanged: _performSearch,
            textInputAction: TextInputAction.search,
          ),
          if (_isSearching) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (!_hasSearched) {
      return _buildSearchSuggestions();
    }

    if (_isSearching && _localResults.isEmpty && _searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Recherche en cours...'),
          ],
        ),
      );
    }

    final hasLocalResults = _localResults.isNotEmpty;
    final hasServerResults = _searchResults.isNotEmpty;

    if (!hasLocalResults && !hasServerResults) {
      return _buildNoResults();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (hasLocalResults) ...[
          _buildSectionHeader('Résultats locaux', Icons.phone, Colors.orange),
          ..._localResults.map((address) => _buildAddressCard(address, isLocal: true)),
          if (hasServerResults) const SizedBox(height: 20),
        ],
        if (hasServerResults) ...[
          _buildSectionHeader('Résultats en ligne', Icons.cloud, Colors.blue),
          ..._searchResults.map((address) => _buildAddressCard(address, isLocal: false)),
        ],
      ],
    );
  }

  Widget _buildSearchSuggestions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suggestions de recherche:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSuggestionChip('BF-OUA-', 'Code Ouagadougou'),
          _buildSuggestionChip('BF-BOB-', 'Code Bobo-Dioulasso'),
          _buildSuggestionChip('Commerce', 'Par catégorie'),
          _buildSuggestionChip('Résidence', 'Par catégorie'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Comment rechercher',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text('• Tapez le nom d\'un lieu'),
                Text('• Utilisez un code d\'adresse (ex: BF-OUA-1234-ABCD)'),
                Text('• Recherchez par catégorie'),
                Text('• Les résultats locaux s\'affichent en premier'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          _searchController.text = text;
          _performSearch(text);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(' - $description', style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun résultat trouvé',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez avec d\'autres mots-clés ou un code d\'adresse',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(AddressModel address, {required bool isLocal}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showAddressDetails(address),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(address.category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      _getCategoryIcon(address.category),
                      size: 16,
                      color: _getCategoryColor(address.category),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      address.placeName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (isLocal)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Local',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                address.code ?? 'Code en attente',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.mono,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                address.category,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              if (address.verificationStatus != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _getVerificationIcon(address.verificationStatus!),
                      size: 12,
                      color: _getVerificationColor(address.verificationStatus!),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getVerificationText(address.verificationStatus!),
                      style: TextStyle(
                        fontSize: 10,
                        color: _getVerificationColor(address.verificationStatus!),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
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

  IconData _getVerificationIcon(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return Icons.verified;
      case 'pending':
        return Icons.pending;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Color _getVerificationColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getVerificationText(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return 'Vérifiée';
      case 'pending':
        return 'En attente';
      case 'rejected':
        return 'Rejetée';
      default:
        return 'Inconnue';
    }
  }
}

class _AddressDetailsSheet extends StatelessWidget {
  final AddressModel address;

  const _AddressDetailsSheet({required this.address});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      address.placeName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      address.code ?? 'Code en attente',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.mono,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDetailRow('Catégorie', address.category, Icons.category),
                    _buildDetailRow(
                      'Position',
                      '${address.latitude.toStringAsFixed(6)}, ${address.longitude.toStringAsFixed(6)}',
                      Icons.my_location,
                    ),
                    if (address.verificationStatus != null)
                      _buildDetailRow('Statut', address.verificationStatus!, Icons.verified),
                    if (address.createdAt != null)
                      _buildDetailRow(
                        'Créée le',
                        '${address.createdAt!.day}/${address.createdAt!.month}/${address.createdAt!.year}',
                        Icons.calendar_today,
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Implement share functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Partage non implémenté')),
                              );
                            },
                            icon: const Icon(Icons.share),
                            label: const Text('Partager'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Implement navigation functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Navigation non implémentée')),
                              );
                            },
                            icon: const Icon(Icons.directions),
                            label: const Text('Naviguer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}