class AddressModel {
  final String? id;
  final String? code;
  final double latitude;
  final double longitude;
  final String placeName;
  final String category;
  final String? photoPath;
  final String? photoUrl;
  final String? verificationStatus;
  final int? confidenceScore;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AddressModel({
    this.id,
    this.code,
    required this.latitude,
    required this.longitude,
    required this.placeName,
    required this.category,
    this.photoPath,
    this.photoUrl,
    this.verificationStatus,
    this.confidenceScore,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'latitude': latitude,
      'longitude': longitude,
      'placeName': placeName,
      'category': category,
      'photoPath': photoPath,
      'photoUrl': photoUrl,
      'verificationStatus': verificationStatus,
      'confidenceScore': confidenceScore,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'],
      code: json['code'],
      latitude: (json['latitude'] is String) 
          ? double.parse(json['latitude']) 
          : json['latitude'].toDouble(),
      longitude: (json['longitude'] is String) 
          ? double.parse(json['longitude']) 
          : json['longitude'].toDouble(),
      placeName: json['place_name'] ?? json['placeName'],
      category: json['category'] ?? 'Other',
      photoPath: json['photo_path'] ?? json['photoPath'],
      photoUrl: json['building_photo_url'] ?? json['photoUrl'],
      verificationStatus: json['verification_status'] ?? json['verificationStatus'],
      confidenceScore: json['confidence_score'] ?? json['confidenceScore'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : (json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : (json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null),
    );
  }

  Map<String, dynamic> toLocalDb() {
    return {
      'id': id ?? '',
      'code': code ?? '',
      'latitude': latitude,
      'longitude': longitude,
      'place_name': placeName,
      'category': category,
      'photo_path': photoPath,
      'synced': 0,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory AddressModel.fromLocalDb(Map<String, dynamic> map) {
    return AddressModel(
      id: map['id'],
      code: map['code'],
      latitude: map['latitude'].toDouble(),
      longitude: map['longitude'].toDouble(),
      placeName: map['place_name'],
      category: map['category'],
      photoPath: map['photo_path'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  AddressModel copyWith({
    String? id,
    String? code,
    double? latitude,
    double? longitude,
    String? placeName,
    String? category,
    String? photoPath,
    String? photoUrl,
    String? verificationStatus,
    int? confidenceScore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AddressModel(
      id: id ?? this.id,
      code: code ?? this.code,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeName: placeName ?? this.placeName,
      category: category ?? this.category,
      photoPath: photoPath ?? this.photoPath,
      photoUrl: photoUrl ?? this.photoUrl,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'AddressModel(code: $code, placeName: $placeName, category: $category)';
  }
}

enum AddressCategory {
  residence('Résidence'),
  commerce('Commerce'),
  bureau('Bureau'),
  ecole('École'),
  sante('Santé'),
  restaurant('Restaurant'),
  autre('Autre');

  const AddressCategory(this.displayName);
  final String displayName;

  static AddressCategory fromString(String category) {
    switch (category.toLowerCase()) {
      case 'résidence':
      case 'residence':
        return AddressCategory.residence;
      case 'commerce':
        return AddressCategory.commerce;
      case 'bureau':
        return AddressCategory.bureau;
      case 'école':
      case 'ecole':
        return AddressCategory.ecole;
      case 'santé':
      case 'sante':
        return AddressCategory.sante;
      case 'restaurant':
        return AddressCategory.restaurant;
      default:
        return AddressCategory.autre;
    }
  }
}