import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../models/address_model.dart';

class CreateAddressScreen extends StatefulWidget {
  const CreateAddressScreen({super.key});

  @override
  State<CreateAddressScreen> createState() => _CreateAddressScreenState();
}

class _CreateAddressScreenState extends State<CreateAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _placeNameController = TextEditingController();
  final _notesController = TextEditingController();
  
  Position? _currentPosition;
  File? _selectedImage;
  String _selectedCategory = 'Résidence';
  bool _isLoading = false;
  bool _isGettingLocation = false;
  LocationValidationResult? _locationValidation;

  final List<String> _categories = [
    'Résidence',
    'Commerce',
    'Bureau',
    'École',
    'Santé',
    'Restaurant',
    'Autre'
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _placeNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationValidation = null;
    });

    try {
      final position = await LocationService.getCurrentPosition();
      final validation = LocationService.validateCoordinates(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _currentPosition = position;
        _locationValidation = validation;
        _isGettingLocation = false;
      });

      if (!validation.isValid && validation.error != null) {
        _showLocationError(validation.error!);
      } else if (validation.warning != null) {
        _showLocationWarning(validation.warning!);
      }
    } catch (e) {
      setState(() {
        _isGettingLocation = false;
      });

      if (e is LocationException) {
        _showLocationError(e.message);
      } else {
        _showLocationError('Erreur de géolocalisation: $e');
      }
    }
  }

  void _showLocationError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreur de géolocalisation'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _getCurrentLocation();
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  void _showLocationWarning(String warning) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(warning),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _takePicture() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur avec la caméra: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur avec la galerie: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _takePicture();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAddress() async {
    if (!_formKey.currentState!.validate() || _currentPosition == null) {
      return;
    }

    if (_locationValidation != null && !_locationValidation!.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Position invalide: ${_locationValidation!.error}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final address = AddressModel(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        placeName: _placeNameController.text.trim(),
        category: _selectedCategory,
        photoPath: _selectedImage?.path,
      );

      // Save locally first
      await DatabaseService.instance.insertAddress(address);

      // Try to sync with server
      final apiResponse = await ApiService.createAddress(address);

      if (apiResponse.isSuccess) {
        // Update local record with server response
        final serverData = apiResponse.data!;
        await DatabaseService.instance.markAddressSynced(
          address.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          serverData['address']['code'],
        );

        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Adresse créée: ${serverData['address']['code']}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (apiResponse.isConflict) {
        // Handle duplicate case
        _showDuplicateDialog(apiResponse.details);
      } else if (apiResponse.isNetworkError) {
        // Saved locally but not synced
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Adresse sauvegardée localement. Sera synchronisée plus tard.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        throw Exception(apiResponse.error);
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
          _isLoading = false;
        });
      }
    }
  }

  void _showDuplicateDialog(Map<String, dynamic>? duplicateData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adresse similaire trouvée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Une adresse similaire existe déjà à proximité:'),
            const SizedBox(height: 8),
            if (duplicateData != null && duplicateData['duplicates'] != null) ...[
              for (var duplicate in duplicateData['duplicates'])
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        duplicate['place_name'] ?? 'Lieu inconnu',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Distance: ${duplicate['distance_meters'].toStringAsFixed(0)}m'),
                      if (duplicate['code'] != null) Text('Code: ${duplicate['code']}'),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            const Text('Voulez-vous continuer malgré tout?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Force creation despite duplicate
              _forceCreateAddress();
            },
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  Future<void> _forceCreateAddress() async {
    // Implementation for forcing address creation
    // This would typically involve a different API endpoint
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Création forcée non implémentée pour le moment'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une Adresse'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isGettingLocation
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Obtention de votre position...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLocationCard(),
                    const SizedBox(height: 20),
                    _buildPlaceNameField(),
                    const SizedBox(height: 16),
                    _buildCategoryDropdown(),
                    const SizedBox(height: 16),
                    _buildNotesField(),
                    const SizedBox(height: 20),
                    _buildPhotoSection(),
                    const SizedBox(height: 32),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLocationCard() {
    if (_currentPosition == null) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.location_off, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              const Text(
                'Position non disponible',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final isValid = _locationValidation?.isValid ?? true;
    final cardColor = isValid ? Colors.green.shade50 : Colors.orange.shade50;
    final iconColor = isValid ? Colors.green : Colors.orange;

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: iconColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Position actuelle',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        LocationService.formatCoordinates(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        LocationService.getAccuracyDescription(_currentPosition!.accuracy),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualiser position',
                ),
              ],
            ),
            if (_locationValidation?.warning != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationValidation!.warning!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceNameField() {
    return TextFormField(
      controller: _placeNameController,
      decoration: const InputDecoration(
        labelText: 'Nom du lieu *',
        hintText: 'Ex: Maison de famille Ouédraogo',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.place),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Le nom du lieu est requis';
        }
        if (value.trim().length < 3) {
          return 'Le nom doit contenir au moins 3 caractères';
        }
        return null;
      },
      textCapitalization: TextCapitalization.words,
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Catégorie',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.category),
      ),
      items: _categories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(category),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategory = value!;
        });
      },
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      decoration: const InputDecoration(
        labelText: 'Notes (optionnel)',
        hintText: 'Informations supplémentaires...',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.notes),
      ),
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photo du bâtiment',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _selectedImage != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Aucune photo sélectionnée',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _takePicture,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Prendre Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickImageFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Galerie'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading || _currentPosition == null ? null : _submitAddress,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        child: _isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Création en cours...'),
                ],
              )
            : const Text(
                'Créer l\'Adresse',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}