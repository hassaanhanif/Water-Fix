class SupplierOfferModel {
  final String listingId;
  final String supplierId;
  final String supplierUserId;
  final String businessName;
  final String ownerName;
  final String city;
  final String serviceAreaText;
  final bool isVerified;
  final int capacityLiters;
  final String label;
  final int waterPrice;
  final int deliveryFee;
  final int totalPrice;
  final double distanceKm;
  final bool hasAccurateDistance;
  final double? ratingAverage;
  final int reviewCount;
  final int completedDeliveriesCount;
  final bool hasSufficientHistory;
  final int? onTimePercentage;
  final String reliabilityText;
  final int estimatedArrivalMinutesMin;
  final int estimatedArrivalMinutesMax;
  final int avgArrivalMinutes;
  final String arrivalText;
  final String phone;
  final String deliveryInfo;
  final double recommendationScore;
  final String recommendationExplanation;
  final bool isAiPick;
  final List<String> badges;
  final String? priceComparisonText;
  final double lat;
  final double lng;
  final double serviceRadiusKm;
  final int tankersOwned;
  final int availableWaterLiters;
  final int pricePer1000Liters;
  final String? companyLogo;
  final bool isAiGenerated;

  const SupplierOfferModel({
    required this.listingId,
    required this.supplierId,
    required this.supplierUserId,
    required this.businessName,
    required this.ownerName,
    required this.city,
    required this.serviceAreaText,
    required this.isVerified,
    required this.capacityLiters,
    required this.label,
    required this.waterPrice,
    required this.deliveryFee,
    required this.totalPrice,
    required this.distanceKm,
    this.hasAccurateDistance = true,
    this.ratingAverage,
    this.reviewCount = 0,
    this.completedDeliveriesCount = 0,
    this.hasSufficientHistory = false,
    this.onTimePercentage,
    this.reliabilityText = 'Not enough delivery history',
    this.estimatedArrivalMinutesMin = 35,
    this.estimatedArrivalMinutesMax = 45,
    this.avgArrivalMinutes = 40,
    this.arrivalText = '35–45 min',
    this.phone = '',
    this.deliveryInfo = '',
    this.recommendationScore = 0.0,
    this.recommendationExplanation = 'Recommended because this supplier serves your area, is available for your requested capacity, and offers a competitive price.',
    this.isAiPick = false,
    this.badges = const [],
    this.priceComparisonText,
    this.lat = 33.6938,
    this.lng = 73.0169,
    this.serviceRadiusKm = 15.0,
    this.tankersOwned = 1,
    this.availableWaterLiters = 10000,
    this.pricePer1000Liters = 1800,
    this.companyLogo,
    this.isAiGenerated = false,
  });

  SupplierOfferModel copyWith({
    double? recommendationScore,
    String? recommendationExplanation,
    bool? isAiPick,
    bool? hasAccurateDistance,
    double? distanceKm,
  }) {
    return SupplierOfferModel(
      listingId: listingId,
      supplierId: supplierId,
      supplierUserId: supplierUserId,
      businessName: businessName,
      ownerName: ownerName,
      city: city,
      serviceAreaText: serviceAreaText,
      isVerified: isVerified,
      capacityLiters: capacityLiters,
      label: label,
      waterPrice: waterPrice,
      deliveryFee: deliveryFee,
      totalPrice: totalPrice,
      distanceKm: distanceKm ?? this.distanceKm,
      hasAccurateDistance: hasAccurateDistance ?? this.hasAccurateDistance,
      ratingAverage: ratingAverage,
      reviewCount: reviewCount,
      completedDeliveriesCount: completedDeliveriesCount,
      hasSufficientHistory: hasSufficientHistory,
      onTimePercentage: onTimePercentage,
      reliabilityText: reliabilityText,
      estimatedArrivalMinutesMin: estimatedArrivalMinutesMin,
      estimatedArrivalMinutesMax: estimatedArrivalMinutesMax,
      avgArrivalMinutes: avgArrivalMinutes,
      arrivalText: arrivalText,
      phone: phone,
      deliveryInfo: deliveryInfo,
      recommendationScore: recommendationScore ?? this.recommendationScore,
      recommendationExplanation:
          recommendationExplanation ?? this.recommendationExplanation,
      isAiPick: isAiPick ?? this.isAiPick,
      badges: badges,
      priceComparisonText: priceComparisonText,
      lat: lat,
      lng: lng,
      serviceRadiusKm: serviceRadiusKm,
      tankersOwned: tankersOwned,
      availableWaterLiters: availableWaterLiters,
      pricePer1000Liters: pricePer1000Liters,
      companyLogo: companyLogo,
      isAiGenerated: isAiGenerated,
    );
  }

  factory SupplierOfferModel.fromJson(Map<String, dynamic> json) {
    final distVal = (json['distanceKm'] as num?)?.toDouble();
    final hasAccurate = json['hasAccurateDistance'] == true ||
        (distVal != null && json['hasAccurateDistance'] != false);

    return SupplierOfferModel(
      listingId: (json['listingId'] ?? json['_id'] ?? '').toString(),
      supplierId: (json['supplierId'] ?? '').toString(),
      supplierUserId: (json['supplierUserId'] ?? '').toString(),
      businessName: (json['businessName'] ?? 'Water Supplier').toString(),
      ownerName: (json['ownerName'] ?? '').toString(),
      city: (json['city'] ?? 'Islamabad').toString(),
      serviceAreaText: (json['serviceAreaText'] ?? 'Islamabad').toString(),
      isVerified: json['isVerified'] == true,
      capacityLiters: (json['capacityLiters'] as num?)?.toInt() ?? 2000,
      label: (json['label'] ?? 'Most homes').toString(),
      waterPrice: (json['waterPrice'] as num?)?.toInt() ?? 1550,
      deliveryFee: (json['deliveryFee'] as num?)?.toInt() ?? 250,
      totalPrice: (json['totalPrice'] as num?)?.toInt() ?? 1800,
      distanceKm: distVal ?? 0.0,
      hasAccurateDistance: hasAccurate,
      ratingAverage: (json['ratingAverage'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      completedDeliveriesCount:
          (json['completedDeliveriesCount'] as num?)?.toInt() ?? 0,
      hasSufficientHistory: json['hasSufficientHistory'] == true,
      onTimePercentage: (json['onTimePercentage'] as num?)?.toInt(),
      reliabilityText:
          (json['reliabilityText'] ?? 'Not enough delivery history').toString(),
      estimatedArrivalMinutesMin:
          (json['estimatedArrivalMinutesMin'] as num?)?.toInt() ?? 35,
      estimatedArrivalMinutesMax:
          (json['estimatedArrivalMinutesMax'] as num?)?.toInt() ?? 45,
      avgArrivalMinutes: (json['avgArrivalMinutes'] as num?)?.toInt() ?? 40,
      arrivalText: (json['arrivalText'] ?? '35–45 min').toString(),
      phone: (json['phone'] ?? '').toString(),
      deliveryInfo: (json['deliveryInfo'] ?? '').toString(),
      recommendationScore:
          (json['recommendationScore'] as num?)?.toDouble() ?? 0.0,
      recommendationExplanation:
          (json['recommendationExplanation'] ??
                  'Recommended because this supplier serves your area, is available for your requested capacity, and offers a competitive price.')
              .toString(),
      isAiPick: json['isAiPick'] == true,
      badges: json['badges'] is List
          ? (json['badges'] as List).map((e) => e.toString()).toList()
          : const [],
      priceComparisonText: json['priceComparisonText']?.toString(),
      lat: (json['lat'] as num?)?.toDouble() ?? 33.6938,
      lng: (json['lng'] as num?)?.toDouble() ?? 73.0169,
      serviceRadiusKm: (json['serviceRadiusKm'] as num?)?.toDouble() ?? 20.0,
      tankersOwned: (json['tankersOwned'] as num?)?.toInt() ?? 1,
      availableWaterLiters:
          (json['availableWaterLiters'] as num?)?.toInt() ?? 10000,
      pricePer1000Liters:
          (json['pricePer1000Liters'] as num?)?.toInt() ?? 1800,
      companyLogo: json['companyLogo']?.toString(),
      isAiGenerated: json['isAiGenerated'] == true,
    );
  }
}
