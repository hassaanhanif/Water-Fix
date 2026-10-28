class BookingModel {
  final String id;
  final String bookingCode;
  final String customerId;
  final String supplierId;
  final String supplierUserId;
  final String listingId;
  final int capacityLiters;
  final int waterPrice;
  final int deliveryFee;
  final int totalPrice;
  final String addressLine;
  final String city;
  final double? deliveryLat;
  final double? deliveryLng;
  final bool hasAccurateDeliveryCoords;
  final String customerName;
  final String customerPhone;
  final String supplierBusinessName;
  final String supplierPhone;
  final String driverName;
  final int estimatedArrivalMinutesMin;
  final int estimatedArrivalMinutesMax;
  final double distanceKm;
  final String status;
  final String? cancelledBy;
  final String cancellationReason;
  final String deliveryCode;
  final bool isReviewed;
  final int? reviewRating;
  final bool commissionRecorded;
  final int commissionAmount;
  final DateTime createdAt;

  // Embedded tracking snapshot from backend if present
  final double? supplierLatitude;
  final double? supplierLongitude;
  final double? supplierHeading;
  final double? supplierSpeed;
  final double? supplierAccuracy;
  final DateTime? trackingUpdatedAt;
  final bool trackingActive;

  const BookingModel({
    required this.id,
    required this.bookingCode,
    required this.customerId,
    required this.supplierId,
    required this.supplierUserId,
    required this.listingId,
    required this.capacityLiters,
    required this.waterPrice,
    required this.deliveryFee,
    required this.totalPrice,
    required this.addressLine,
    required this.city,
    this.deliveryLat,
    this.deliveryLng,
    this.hasAccurateDeliveryCoords = true,
    required this.customerName,
    required this.customerPhone,
    required this.supplierBusinessName,
    required this.supplierPhone,
    required this.driverName,
    required this.estimatedArrivalMinutesMin,
    required this.estimatedArrivalMinutesMax,
    required this.distanceKm,
    required this.status,
    this.cancelledBy,
    this.cancellationReason = '',
    required this.deliveryCode,
    this.isReviewed = false,
    this.reviewRating,
    this.commissionRecorded = false,
    this.commissionAmount = 0,
    required this.createdAt,
    this.supplierLatitude,
    this.supplierLongitude,
    this.supplierHeading,
    this.supplierSpeed,
    this.supplierAccuracy,
    this.trackingUpdatedAt,
    this.trackingActive = false,
  });

  double get lat => deliveryLat ?? 0.0;
  double get lng => deliveryLng ?? 0.0;

  bool get hasDeliveryCoordinates =>
      deliveryLat != null && deliveryLng != null && hasAccurateDeliveryCoords;

  bool get hasSupplierCoordinates =>
      status != 'requested' &&
      supplierLatitude != null &&
      supplierLongitude != null;

  bool get isActive =>
      ['requested', 'accepted', 'dispatched', 'arriving'].contains(status);

  bool get isPostAcceptanceActive =>
      ['accepted', 'dispatched', 'arriving'].contains(status);

  bool get isCancelledBySupplier =>
      (status == 'cancelled' || status == 'rejected') &&
      cancelledBy == 'supplier';

  bool get canCustomerCancel => ['requested', 'accepted'].contains(status);

  String get driverInitials {
    final parts = driverName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'DR';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get formattedDeliveryCode {
    return deliveryCode.split('').join(' ');
  }

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final addr = json['deliveryAddress'] is Map
        ? Map<String, dynamic>.from(json['deliveryAddress'] as Map)
        : <String, dynamic>{};
    final track = json['tracking'] is Map
        ? Map<String, dynamic>.from(json['tracking'] as Map)
        : <String, dynamic>{};

    final parsedLat = (addr['lat'] as num?)?.toDouble();
    final parsedLng = (addr['lng'] as num?)?.toDouble();
    final hasAccurateCoords =
        parsedLat != null &&
        parsedLng != null &&
        addr['hasAccurateCoordinates'] != false;

    final statusStr = (json['status'] ?? 'requested').toString();
    final isPreAccept = statusStr == 'requested';

    return BookingModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      bookingCode: (json['bookingCode'] ?? '#WF-1000').toString(),
      customerId: (json['customerId'] ?? '').toString(),
      supplierId: (json['supplierId'] ?? '').toString(),
      supplierUserId: (json['supplierUserId'] ?? '').toString(),
      listingId: (json['listingId'] ?? '').toString(),
      capacityLiters: (json['capacityLiters'] as num?)?.toInt() ?? 2000,
      waterPrice: (json['waterPrice'] as num?)?.toInt() ?? 1550,
      deliveryFee: (json['deliveryFee'] as num?)?.toInt() ?? 250,
      totalPrice: (json['totalPrice'] as num?)?.toInt() ?? 1800,
      addressLine: (addr['addressLine'] ?? '').toString(),
      city: (addr['city'] ?? 'Islamabad').toString(),
      deliveryLat: parsedLat,
      deliveryLng: parsedLng,
      hasAccurateDeliveryCoords: hasAccurateCoords,
      customerName: (json['customerName'] ?? 'Customer').toString(),
      customerPhone: (json['customerPhone'] ?? '').toString(),
      supplierBusinessName: (json['supplierBusinessName'] ?? 'Water Supplier')
          .toString(),
      supplierPhone: (json['supplierPhone'] ?? '').toString(),
      driverName: (json['driverName'] ?? 'Driver').toString(),
      estimatedArrivalMinutesMin:
          (json['estimatedArrivalMinutesMin'] as num?)?.toInt() ?? 35,
      estimatedArrivalMinutesMax:
          (json['estimatedArrivalMinutesMax'] as num?)?.toInt() ?? 45,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 3.2,
      status: statusStr,
      cancelledBy: json['cancelledBy']?.toString(),
      cancellationReason: (json['cancellationReason'] ?? '').toString(),
      deliveryCode: (json['deliveryCode'] ?? '4821').toString(),
      isReviewed: json['isReviewed'] == true,
      reviewRating: (json['reviewRating'] as num?)?.toInt(),
      commissionRecorded: json['commissionRecorded'] == true,
      commissionAmount: (json['commissionAmount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      supplierLatitude: isPreAccept
          ? null
          : (track['latitude'] as num?)?.toDouble(),
      supplierLongitude: isPreAccept
          ? null
          : (track['longitude'] as num?)?.toDouble(),
      supplierHeading: isPreAccept
          ? null
          : (track['heading'] as num?)?.toDouble(),
      supplierSpeed: isPreAccept ? null : (track['speed'] as num?)?.toDouble(),
      supplierAccuracy: isPreAccept
          ? null
          : (track['accuracy'] as num?)?.toDouble(),
      trackingUpdatedAt: !isPreAccept && track['updatedAt'] != null
          ? DateTime.tryParse(track['updatedAt'].toString())
          : null,
      trackingActive: !isPreAccept && track['trackingActive'] == true,
    );
  }
}
