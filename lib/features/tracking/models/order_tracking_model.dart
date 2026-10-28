import 'package:latlong2/latlong.dart';

import '../../bookings/models/booking_model.dart';

enum UserRole { customer, supplier }

class RouteGeometryResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;

  const RouteGeometryResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

class OrderTrackingModel {
  final String orderId;
  final String supplierId;
  final String supplierUserId;
  final String customerId;
  final double? latitude;
  final double? longitude;
  final double? heading;
  final double? speed;
  final double? accuracy;
  final DateTime? updatedAt;
  final bool trackingActive;
  final String orderStatus;
  final String deliveryAddressLine;
  final String deliveryCity;
  final double? deliveryLat;
  final double? deliveryLng;
  final bool hasAccurateDeliveryCoordinates;
  final BookingModel? booking;

  const OrderTrackingModel({
    required this.orderId,
    required this.supplierId,
    required this.supplierUserId,
    required this.customerId,
    this.latitude,
    this.longitude,
    this.heading,
    this.speed,
    this.accuracy,
    this.updatedAt,
    required this.trackingActive,
    required this.orderStatus,
    required this.deliveryAddressLine,
    this.deliveryCity = 'Islamabad',
    this.deliveryLat,
    this.deliveryLng,
    this.hasAccurateDeliveryCoordinates = true,
    this.booking,
  });

  bool get isPreAcceptance => orderStatus == 'requested';

  bool get isPostAcceptanceActive =>
      ['accepted', 'dispatched', 'arriving'].contains(orderStatus);

  bool get isCompleted => orderStatus == 'delivered';

  bool get isCancelledOrRejected =>
      ['cancelled', 'rejected', 'expired', 'failed'].contains(orderStatus);

  bool get hasSupplierCoordinates =>
      !isPreAcceptance && latitude != null && longitude != null;

  bool get hasCustomerCoordinates =>
      deliveryLat != null &&
      deliveryLng != null &&
      hasAccurateDeliveryCoordinates;

  LatLng? get supplierLatLng =>
      hasSupplierCoordinates ? LatLng(latitude!, longitude!) : null;

  LatLng? get customerLatLng =>
      hasCustomerCoordinates ? LatLng(deliveryLat!, deliveryLng!) : null;

  bool isLocationStale([DateTime? referenceTime]) {
    if (!trackingActive || !isPostAcceptanceActive) return false;
    if (updatedAt == null) return false;
    final now = referenceTime ?? DateTime.now();
    return now.difference(updatedAt!).inSeconds > 45;
  }

  String formatLastUpdated([DateTime? referenceTime]) {
    if (isPreAcceptance) {
      return 'Waiting for supplier acceptance';
    }
    if (updatedAt == null) {
      if (isPostAcceptanceActive) {
        return 'Waiting for supplier GPS fix...';
      }
      return 'No GPS updates recorded';
    }
    final now = referenceTime ?? DateTime.now();
    final diffSec = now.difference(updatedAt!).inSeconds;
    if (diffSec < 5) {
      return 'Updated just now';
    }
    if (diffSec < 60) {
      return 'Updated ${diffSec}s ago';
    }
    final diffMin = now.difference(updatedAt!).inMinutes;
    if (diffMin < 60) {
      return 'Updated ${diffMin}m ago';
    }
    final diffHr = now.difference(updatedAt!).inHours;
    return 'Updated ${diffHr}h ago';
  }

  factory OrderTrackingModel.fromBooking(BookingModel b) {
    final isPre = b.status == 'requested';
    return OrderTrackingModel(
      orderId: b.id,
      supplierId: b.supplierId,
      supplierUserId: b.supplierUserId,
      customerId: b.customerId,
      latitude: isPre ? null : b.supplierLatitude,
      longitude: isPre ? null : b.supplierLongitude,
      heading: isPre ? null : b.supplierHeading,
      speed: isPre ? null : b.supplierSpeed,
      accuracy: isPre ? null : b.supplierAccuracy,
      updatedAt: isPre ? null : b.trackingUpdatedAt,
      trackingActive: !isPre && b.trackingActive && b.isPostAcceptanceActive,
      orderStatus: b.status,
      deliveryAddressLine: b.addressLine,
      deliveryCity: b.city,
      deliveryLat: b.deliveryLat,
      deliveryLng: b.deliveryLng,
      hasAccurateDeliveryCoordinates: b.hasAccurateDeliveryCoords,
      booking: b,
    );
  }

  factory OrderTrackingModel.fromJson(
    Map<String, dynamic> json, {
    BookingModel? fallbackBooking,
  }) {
    final bookingModel = json['booking'] is Map
        ? BookingModel.fromJson(Map<String, dynamic>.from(json['booking'] as Map))
        : fallbackBooking;

    final addr = json['deliveryAddress'] is Map
        ? Map<String, dynamic>.from(json['deliveryAddress'] as Map)
        : <String, dynamic>{};

    final statusStr =
        (json['orderStatus'] ?? bookingModel?.status ?? 'requested').toString();
    final isPre = statusStr == 'requested';

    final delivLat =
        (addr['lat'] as num?)?.toDouble() ?? bookingModel?.deliveryLat;
    final delivLng =
        (addr['lng'] as num?)?.toDouble() ?? bookingModel?.deliveryLng;
    final hasAccurateDeliv =
        delivLat != null &&
        delivLng != null &&
        (addr['hasAccurateCoordinates'] != false);

    return OrderTrackingModel(
      orderId: (json['orderId'] ?? bookingModel?.id ?? '').toString(),
      supplierId:
          (json['supplierId'] ?? bookingModel?.supplierId ?? '').toString(),
      supplierUserId:
          (json['supplierUserId'] ?? bookingModel?.supplierUserId ?? '')
              .toString(),
      customerId:
          (json['customerId'] ?? bookingModel?.customerId ?? '').toString(),
      latitude: isPre ? null : (json['latitude'] as num?)?.toDouble(),
      longitude: isPre ? null : (json['longitude'] as num?)?.toDouble(),
      heading: isPre ? null : (json['heading'] as num?)?.toDouble(),
      speed: isPre ? null : (json['speed'] as num?)?.toDouble(),
      accuracy: isPre ? null : (json['accuracy'] as num?)?.toDouble(),
      updatedAt: !isPre && json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      trackingActive: !isPre && json['trackingActive'] == true,
      orderStatus: statusStr,
      deliveryAddressLine:
          (addr['addressLine'] ?? bookingModel?.addressLine ?? '').toString(),
      deliveryCity:
          (addr['city'] ?? bookingModel?.city ?? 'Islamabad').toString(),
      deliveryLat: delivLat,
      deliveryLng: delivLng,
      hasAccurateDeliveryCoordinates: hasAccurateDeliv,
      booking: bookingModel,
    );
  }
}
