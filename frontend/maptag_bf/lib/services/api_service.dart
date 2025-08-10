import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/address_model.dart';

class ApiService {
  static const String _baseUrl = 'http://10.0.2.2:3000/api'; // Android emulator
  // Use 'http://localhost:3000/api' for iOS simulator
  // Use your actual server URL for production
  
  static const Duration _timeout = Duration(seconds: 30);
  
  static final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Create a new address on the server
  static Future<ApiResponse<Map<String, dynamic>>> createAddress(
    AddressModel address,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/addresses'),
      );

      // Add form fields
      request.fields.addAll({
        'latitude': address.latitude.toString(),
        'longitude': address.longitude.toString(),
        'placeName': address.placeName,
        'category': address.category,
      });

      // Add photo if available
      if (address.photoPath != null && address.photoPath!.isNotEmpty) {
        File imageFile = File(address.photoPath!);
        if (await imageFile.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath('photo', address.photoPath!),
          );
        }
      }

      // Send request
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body);
        return ApiResponse.success(data);
      } else {
        final errorData = json.decode(response.body);
        return ApiResponse.error(
          errorData['error'] ?? 'Erreur serveur inconnue',
          statusCode: response.statusCode,
          details: errorData,
        );
      }
    } on SocketException {
      return ApiResponse.error(
        'Pas de connexion internet',
        isNetworkError: true,
      );
    } on http.ClientException {
      return ApiResponse.error(
        'Erreur de connexion au serveur',
        isNetworkError: true,
      );
    } on FormatException {
      return ApiResponse.error('Réponse serveur invalide');
    } catch (e) {
      return ApiResponse.error(
        'Erreur inattendue: ${e.toString()}',
      );
    }
  }

  /// Get address by code
  static Future<ApiResponse<AddressModel>> getAddress(String code) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/addresses/$code'),
        headers: _headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = AddressModel.fromJson(data);
        return ApiResponse.success(address);
      } else if (response.statusCode == 404) {
        return ApiResponse.error('Adresse non trouvée');
      } else {
        final errorData = json.decode(response.body);
        return ApiResponse.error(
          errorData['error'] ?? 'Erreur serveur',
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      return ApiResponse.error(
        'Pas de connexion internet',
        isNetworkError: true,
      );
    } on http.ClientException {
      return ApiResponse.error(
        'Erreur de connexion',
        isNetworkError: true,
      );
    } on FormatException {
      return ApiResponse.error('Réponse serveur invalide');
    } catch (e) {
      return ApiResponse.error('Erreur: ${e.toString()}');
    }
  }

  /// Search addresses
  static Future<ApiResponse<List<AddressModel>>> searchAddresses({
    String? search,
    String? category,
    double? latitude,
    double? longitude,
    double radius = 1000,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      if (latitude != null && longitude != null) {
        queryParams['lat'] = latitude.toString();
        queryParams['lon'] = longitude.toString();
        queryParams['radius'] = radius.toString();
      }

      final uri = Uri.parse('$_baseUrl/addresses').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addresses = (data['addresses'] as List)
            .map((json) => AddressModel.fromJson(json))
            .toList();
        return ApiResponse.success(addresses, metadata: data['pagination']);
      } else {
        final errorData = json.decode(response.body);
        return ApiResponse.error(
          errorData['error'] ?? 'Erreur de recherche',
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      return ApiResponse.error(
        'Pas de connexion internet',
        isNetworkError: true,
      );
    } on http.ClientException {
      return ApiResponse.error(
        'Erreur de connexion',
        isNetworkError: true,
      );
    } catch (e) {
      return ApiResponse.error('Erreur: ${e.toString()}');
    }
  }

  /// Report duplicate address
  static Future<ApiResponse<Map<String, dynamic>>> reportDuplicate(
    String addressCode,
    String duplicateCode, {
    String? reason,
  }) async {
    try {
      final body = {
        'duplicate_code': duplicateCode,
        if (reason != null) 'reason': reason,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/addresses/$addressCode/report-duplicate'),
        headers: _headers,
        body: json.encode(body),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ApiResponse.success(data);
      } else {
        final errorData = json.decode(response.body);
        return ApiResponse.error(
          errorData['error'] ?? 'Erreur lors du signalement',
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      return ApiResponse.error(
        'Pas de connexion internet',
        isNetworkError: true,
      );
    } catch (e) {
      return ApiResponse.error('Erreur: ${e.toString()}');
    }
  }

  /// Get server health status
  static Future<ApiResponse<Map<String, dynamic>>> getHealthStatus() async {
    try {
      final response = await http.get(
        Uri.parse('${_baseUrl.replaceAll('/api', '')}/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ApiResponse.success(data);
      } else {
        return ApiResponse.error('Serveur indisponible');
      }
    } catch (e) {
      return ApiResponse.error(
        'Serveur inaccessible',
        isNetworkError: true,
      );
    }
  }

  /// Check connectivity to server
  static Future<bool> isServerReachable() async {
    try {
      final response = await getHealthStatus();
      return response.isSuccess;
    } catch (e) {
      return false;
    }
  }
}

class ApiResponse<T> {
  final T? data;
  final String? error;
  final bool isSuccess;
  final int? statusCode;
  final bool isNetworkError;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic>? details;

  ApiResponse._({
    this.data,
    this.error,
    required this.isSuccess,
    this.statusCode,
    this.isNetworkError = false,
    this.metadata,
    this.details,
  });

  factory ApiResponse.success(T data, {Map<String, dynamic>? metadata}) {
    return ApiResponse._(
      data: data,
      isSuccess: true,
      metadata: metadata,
    );
  }

  factory ApiResponse.error(
    String error, {
    int? statusCode,
    bool isNetworkError = false,
    Map<String, dynamic>? details,
  }) {
    return ApiResponse._(
      error: error,
      isSuccess: false,
      statusCode: statusCode,
      isNetworkError: isNetworkError,
      details: details,
    );
  }

  bool get isConflict => statusCode == 409;
  bool get isNotFound => statusCode == 404;
  bool get isBadRequest => statusCode == 400;
  bool get isServerError => statusCode != null && statusCode! >= 500;
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isNetworkError;

  ApiException(
    this.message, {
    this.statusCode,
    this.isNetworkError = false,
  });

  @override
  String toString() => 'ApiException: $message';
}