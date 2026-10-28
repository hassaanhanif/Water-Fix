class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'customer' | 'supplier' | 'admin'
  final String customerCategory;
  final String cnic;
  final String cnicMasked;
  final bool emailVerified;
  final String approvalStatus; // 'approved' | 'pending_approval' | 'rejected'
  final String rejectionReason;
  final bool isLocked;
  final String lockReason;
  final Map<String, dynamic> preferences;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.customerCategory = 'Household',
    this.cnic = '',
    this.cnicMasked = '',
    this.emailVerified = true,
    this.approvalStatus = 'approved',
    this.rejectionReason = '',
    this.isLocked = false,
    this.lockReason = '',
    this.preferences = const {},
  });

  bool get isSupplier => role == 'supplier';
  bool get isCustomer => role == 'customer';
  bool get isAdmin => role == 'admin';
  bool get isApproved => approvalStatus == 'approved';
  bool get isPendingApproval => approvalStatus == 'pending_approval';
  bool get isRejected => approvalStatus == 'rejected';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'WF';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      role: (json['role'] ?? 'customer').toString(),
      customerCategory: (json['customerCategory'] ?? 'Household').toString(),
      cnic: (json['cnicNumber'] ?? json['cnic'] ?? '').toString(),
      cnicMasked: (json['cnicMasked'] ?? '').toString(),
      emailVerified: json['emailVerified'] == true,
      approvalStatus: (json['approvalStatus'] ?? 'approved').toString(),
      rejectionReason: (json['rejectionReason'] ?? '').toString(),
      isLocked: json['isLocked'] == true,
      lockReason: (json['lockReason'] ?? '').toString(),
      preferences: json['preferences'] is Map
          ? Map<String, dynamic>.from(json['preferences'] as Map)
          : const {},
    );
  }
}

class DeliveryAddressModel {
  final String id;
  final String label;
  final String addressLine;
  final String city;
  final double lat;
  final double lng;
  final bool hasAccurateCoordinates;
  final bool isDefault;

  const DeliveryAddressModel({
    required this.id,
    required this.label,
    required this.addressLine,
    required this.city,
    required this.lat,
    required this.lng,
    this.hasAccurateCoordinates = true,
    this.isDefault = false,
  });

  factory DeliveryAddressModel.fromJson(Map<String, dynamic> json) {
    return DeliveryAddressModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      label: (json['label'] ?? 'Home').toString(),
      addressLine: (json['addressLine'] ?? '').toString(),
      city: (json['city'] ?? 'Islamabad').toString(),
      lat: (json['lat'] as num?)?.toDouble() ?? 33.6938,
      lng: (json['lng'] as num?)?.toDouble() ?? 73.0169,
      hasAccurateCoordinates: json['hasAccurateCoordinates'] != false,
      isDefault: json['isDefault'] == true,
    );
  }
}
