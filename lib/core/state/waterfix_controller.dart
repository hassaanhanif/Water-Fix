import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../config/app_config.dart';
import '../location/location_service.dart';
import '../network/api_client.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/suppliers/models/supplier_models.dart';
import '../../features/bookings/models/booking_model.dart';
import '../../features/tracking/services/order_tracking_service.dart';

final waterFixControllerProvider = ChangeNotifierProvider<WaterFixController>((
  ref,
) {
  return WaterFixController(apiClient: ApiClient());
});

class WaterFixController extends ChangeNotifier {
  final ApiClient apiClient;
  late final SupplierLocationBroadcaster locationBroadcaster;

  UserModel? currentUser;
  Map<String, dynamic>? supplierProfile;
  List<DeliveryAddressModel> savedAddresses = [];

  bool isInitializing = true;
  bool isAuthLoading = false;
  String? authError;
  String? lastAuthErrorCode;

  // Customer discovery state
  String selectedAddressLine = 'Street 7, F-10/3, Islamabad';
  String selectedCity = 'Islamabad';
  double? selectedLat = 33.6938;
  double? selectedLng = 73.0169;
  bool hasAccurateGps = true;
  String? locationWarning;
  int selectedCapacityLiters = 2000;
  String selectedSortBy = 'best_match';

  bool isLoadingSuppliers = false;
  String? suppliersError;
  List<SupplierOfferModel> discoveredSuppliers = [];
  List<SupplierOfferModel> homeTopSuppliers = [];
  List<SupplierOfferModel> ourPicksSuppliers = [];
  bool isLoadingOurPicks = false;
  String? ourPicksError;

  // Backwards compatibility aliases
  List<SupplierOfferModel> get aiPicksSuppliers => ourPicksSuppliers;
  set aiPicksSuppliers(List<SupplierOfferModel> v) => ourPicksSuppliers = v;
  bool get isLoadingAiPicks => isLoadingOurPicks;
  set isLoadingAiPicks(bool v) => isLoadingOurPicks = v;
  String? get aiPicksError => ourPicksError;
  set aiPicksError(String? v) => ourPicksError = v;

  int _searchRequestId = 0;

  // Bookings state
  bool isLoadingBookings = false;
  String? bookingsError;
  List<BookingModel> bookings = [];

  // Notifications state
  List<Map<String, dynamic>> notifications = [];
  int unreadNotificationsCount = 0;

  // Supplier dashboard & wallet state
  bool isLoadingSupplierDashboard = false;
  bool isLoadingWallet = false;
  List<Map<String, dynamic>> supplierListings = [];
  List<BookingModel> supplierOrders = [];
  List<Map<String, dynamic>> supplierReviews = [];
  Map<String, dynamic>? walletSummary;
  List<Map<String, dynamic>> walletCommissionHistory = [];
  List<Map<String, dynamic>> walletPaymentHistory = [];
  List<Map<String, dynamic>> walletLedger = [];
  List<Map<String, dynamic>> walletSettlements = [];

  // Admin dashboard state
  bool isLoadingAdminDashboard = false;
  bool isLoadingAdminSuppliers = false;
  bool isLoadingAdminCustomers = false;
  bool isLoadingAdminPayments = false;
  String? adminError;
  Map<String, dynamic>? adminDashboardSummary;
  List<Map<String, dynamic>> adminRecentPayments = [];
  List<Map<String, dynamic>> adminOverdueSuppliers = [];
  List<Map<String, dynamic>> adminAuditLogs = [];
  List<Map<String, dynamic>> adminSuppliers = [];
  String adminSupplierFilter = 'all';
  String adminSupplierSearch = '';
  List<Map<String, dynamic>> adminCustomers = [];
  String adminCustomerFilter = 'all';
  String adminCustomerSearch = '';
  List<Map<String, dynamic>> adminPayments = [];
  Map<String, dynamic> adminPaymentCounts = {};
  String adminPaymentFilter = 'all';
  String adminPaymentSearch = '';

  // Pending applicant approval states
  bool isLoadingAdminPendingSuppliers = false;
  bool isLoadingAdminPendingCustomers = false;
  List<Map<String, dynamic>> adminPendingSuppliers = [];
  String adminPendingSupplierSearch = '';
  List<Map<String, dynamic>> adminPendingCustomers = [];
  String adminPendingCustomerSearch = '';

  WaterFixController({
    required this.apiClient,
    SupplierLocationBroadcaster? customBroadcaster,
  }) {
    locationBroadcaster =
        customBroadcaster ?? SupplierLocationBroadcaster(apiClient: apiClient);
    locationBroadcaster.addListener(notifyListeners);
  }

  @override
  void dispose() {
    locationBroadcaster.removeListener(notifyListeners);
    locationBroadcaster.dispose();
    super.dispose();
  }

  bool get isAuthenticated => currentUser != null;
  bool get isSupplier => currentUser?.isSupplier == true;
  bool get isAdmin => currentUser?.isAdmin == true;

  Future<void> restoreSession() async {
    isInitializing = true;
    notifyListeners();
    try {
      final token = await apiClient.tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        isInitializing = false;
        notifyListeners();
        return;
      }
      final res = await apiClient.get('/auth/me');
      final data = res['data'] as Map<String, dynamic>;
      currentUser = UserModel.fromJson(
        Map<String, dynamic>.from(data['user'] as Map),
      );
      if (data['supplierProfile'] is Map) {
        supplierProfile = Map<String, dynamic>.from(
          data['supplierProfile'] as Map,
        );
      }
      if (data['addresses'] is List) {
        savedAddresses = (data['addresses'] as List)
            .map(
              (e) => DeliveryAddressModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
        if (savedAddresses.isNotEmpty) {
          final def = savedAddresses.firstWhere(
            (a) => a.isDefault,
            orElse: () => savedAddresses.first,
          );
          selectedAddressLine = def.addressLine;
          selectedCity = def.city;
          selectedLat = def.lat;
          selectedLng = def.lng;
        }
      }
      if (currentUser!.isAdmin) {
        await refreshAllAdminData();
      } else if (currentUser!.isSupplier) {
        await fetchSupplierDashboard();
        await fetchWallet();
      } else {
        await refreshCustomerHomeData();
      }
      await fetchNotifications();
    } catch (_) {
      await apiClient.tokenStorage.clearTokens();
      currentUser = null;
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String identifier,
    required String password,
    String? role,
  }) async {
    isAuthLoading = true;
    authError = null;
    notifyListeners();
    try {
      final payload = <String, dynamic>{
        'identifier': identifier.trim(),
        'password': password,
      };
      if (role != null) {
        payload['role'] = role;
      }
      final res = await apiClient.post('/auth/login', data: payload);
      final data = Map<String, dynamic>.from(res['data'] as Map);
      await apiClient.tokenStorage.saveTokens(
        accessToken: data['accessToken'].toString(),
        refreshToken: data['refreshToken'].toString(),
      );
      currentUser = UserModel.fromJson(
        Map<String, dynamic>.from(data['user'] as Map),
      );
      if (data['supplierProfile'] is Map) {
        supplierProfile = Map<String, dynamic>.from(
          data['supplierProfile'] as Map,
        );
      }
      if (currentUser!.isAdmin) {
        await refreshAllAdminData();
      } else if (currentUser!.isSupplier) {
        await fetchSupplierDashboard();
        await fetchWallet();
      } else {
        await refreshCustomerHomeData();
      }
      await fetchNotifications();
      return true;
    } on ApiException catch (e) {
      authError = e.message;
      lastAuthErrorCode = e.code;
      return false;
    } catch (e) {
      authError = e.toString();
      lastAuthErrorCode = null;
      return false;
    } finally {
      isAuthLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    required String role,
    String cnic = '',
    String customerCategory = 'Household',
    String? businessName,
    String? city,
    String? serviceAreaText,
    double? lat,
    double? lng,
    int? serviceRadiusKm,
    int? tankersOwned,
    int? availableWaterLiters,
    int? pricePer1000Liters,
    String? companyLogo,
    String? deliveryInfo,
    List<Map<String, dynamic>>? initialListings,
  }) async {
    isAuthLoading = true;
    authError = null;
    notifyListeners();
    try {
      final payload = <String, dynamic>{
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
        'confirmPassword': confirmPassword,
        'role': role,
        'customerCategory': customerCategory,
      };
      if (cnic.trim().isNotEmpty) payload['cnic'] = cnic.trim();
      if (businessName != null) payload['businessName'] = businessName.trim();
      if (city != null) payload['city'] = city.trim();
      if (serviceAreaText != null) {
        payload['serviceAreaText'] = serviceAreaText.trim();
      }
      if (lat != null) payload['lat'] = lat;
      if (lng != null) payload['lng'] = lng;
      if (serviceRadiusKm != null) payload['serviceRadiusKm'] = serviceRadiusKm;
      if (tankersOwned != null) payload['tankersOwned'] = tankersOwned;
      if (availableWaterLiters != null) {
        payload['availableWaterLiters'] = availableWaterLiters;
      }
      if (pricePer1000Liters != null) {
        payload['pricePer1000Liters'] = pricePer1000Liters;
      }
      if (companyLogo != null) payload['companyLogo'] = companyLogo;
      if (deliveryInfo != null) payload['deliveryInfo'] = deliveryInfo.trim();
      if (initialListings != null) payload['listings'] = initialListings;

      final res = await apiClient.post('/auth/register', data: payload);

      final data = Map<String, dynamic>.from(res['data'] as Map);
      // In production, tokens are NOT issued until OTP verification succeeds.
      // If tokens are returned (e.g. in test runner), save only when verified.
      if (data['accessToken'] != null &&
          data['accessToken'].toString().isNotEmpty &&
          data['emailVerified'] == true) {
        await apiClient.tokenStorage.saveTokens(
          accessToken: data['accessToken'].toString(),
          refreshToken: data['refreshToken'].toString(),
        );
        currentUser = UserModel.fromJson(
          Map<String, dynamic>.from(data['user'] as Map),
        );
        if (data['supplierProfile'] is Map) {
          supplierProfile = Map<String, dynamic>.from(
            data['supplierProfile'] as Map,
          );
        }
        if (currentUser!.isAdmin) {
          await refreshAllAdminData();
        } else if (currentUser!.isSupplier) {
          await fetchSupplierDashboard();
          await fetchWallet();
        } else {
          await refreshCustomerHomeData();
        }
        await fetchNotifications();
      }
      return true;
    } on ApiException catch (e) {
      authError = e.message;
      lastAuthErrorCode = e.code;
      return false;
    } catch (e) {
      authError = e.toString();
      lastAuthErrorCode = null;
      return false;
    } finally {
      isAuthLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyEmailOtp(String otp, {String? email}) async {
    isAuthLoading = true;
    authError = null;
    notifyListeners();
    try {
      final targetEmail = email ?? currentUser?.email;
      if (targetEmail == null || targetEmail.isEmpty) {
        authError = 'Email address is missing.';
        return false;
      }
      final res = await apiClient.post(
        '/auth/verify-email-otp',
        data: {
          'email': targetEmail.trim(),
          'otp': otp.trim(),
        },
      );
      final data = Map<String, dynamic>.from(res['data'] as Map);
      if (data['accessToken'] != null && data['accessToken'].toString().isNotEmpty) {
        await apiClient.tokenStorage.saveTokens(
          accessToken: data['accessToken'].toString(),
          refreshToken: data['refreshToken'].toString(),
        );
      }
      if (data['user'] is Map) {
        currentUser = UserModel.fromJson(
          Map<String, dynamic>.from(data['user'] as Map),
        );
      } else if (currentUser != null) {
        currentUser = UserModel(
          id: currentUser!.id,
          name: currentUser!.name,
          email: currentUser!.email,
          phone: currentUser!.phone,
          role: currentUser!.role,
          customerCategory: currentUser!.customerCategory,
          cnic: currentUser!.cnic,
          cnicMasked: currentUser!.cnicMasked,
          emailVerified: true,
          approvalStatus: (data['approvalStatus'] ?? currentUser!.approvalStatus).toString(),
          rejectionReason: (data['rejectionReason'] ?? currentUser!.rejectionReason).toString(),
          isLocked: currentUser!.isLocked,
          lockReason: currentUser!.lockReason,
          preferences: currentUser!.preferences,
        );
      }
      if (data['supplierProfile'] is Map) {
        supplierProfile = Map<String, dynamic>.from(
          data['supplierProfile'] as Map,
        );
      }
      return true;
    } on ApiException catch (e) {
      authError = e.message;
      lastAuthErrorCode = e.code;
      return false;
    } catch (e) {
      authError = e.toString();
      lastAuthErrorCode = null;
      return false;
    } finally {
      isAuthLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> resendEmailOtp({String? email}) async {
    final targetEmail = email ?? currentUser?.email;
    if (targetEmail == null || targetEmail.isEmpty) {
      throw Exception('Email address is missing.');
    }
    final res = await apiClient.post(
      '/auth/resend-email-otp',
      data: {'email': targetEmail.trim()},
    );
    return Map<String, dynamic>.from(res);
  }

  Future<void> fetchAccountStatus() async {
    try {
      final res = await apiClient.get('/auth/status');
      final data = Map<String, dynamic>.from(res['data'] as Map);
      if (currentUser != null) {
        currentUser = UserModel(
          id: currentUser!.id,
          name: currentUser!.name,
          email: currentUser!.email,
          phone: currentUser!.phone,
          role: currentUser!.role,
          customerCategory: currentUser!.customerCategory,
          cnic: currentUser!.cnic,
          cnicMasked: currentUser!.cnicMasked,
          emailVerified: data['emailVerified'] == true,
          approvalStatus: (data['approvalStatus'] ?? currentUser!.approvalStatus).toString(),
          rejectionReason: (data['rejectionReason'] ?? currentUser!.rejectionReason).toString(),
          isLocked: currentUser!.isLocked,
          lockReason: currentUser!.lockReason,
          preferences: currentUser!.preferences,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    await locationBroadcaster.stopAllBroadcasting();
    try {
      final refresh = await apiClient.tokenStorage.getRefreshToken();
      await apiClient.post('/auth/logout', data: {'refreshToken': refresh});
    } catch (_) {}
    await apiClient.tokenStorage.clearTokens();
    currentUser = null;
    supplierProfile = null;
    bookings = [];
    notifications = [];
    unreadNotificationsCount = 0;
    adminDashboardSummary = null;
    adminSuppliers = [];
    adminCustomers = [];
    adminPayments = [];
    notifyListeners();
  }

  Future<void> refreshCustomerHomeData() async {
    await Future.wait([discoverSuppliers(), fetchBookings(), fetchAddresses()]);
  }

  void setCapacity(int liters) {
    selectedCapacityLiters = liters;
    notifyListeners();
    final reqId = ++_searchRequestId;
    discoverSuppliers(requestId: reqId);
    fetchOurPicksRecommendations(requestId: reqId);
  }

  void setSortBy(String sortBy) {
    selectedSortBy = sortBy;
    notifyListeners();
    final reqId = ++_searchRequestId;
    discoverSuppliers(requestId: reqId);
    fetchOurPicksRecommendations(requestId: reqId);
  }

  Future<void> useCurrentGpsLocation() async {
    final result = await LocationService.getCurrentLocation(
      fallbackAddress: selectedAddressLine,
    );
    if (result.lat != null && result.lng != null) {
      selectedLat = result.lat;
      selectedLng = result.lng;
      selectedAddressLine = result.addressText;
      hasAccurateGps = true;
      locationWarning = null;
    } else {
      hasAccurateGps = false;
      locationWarning = result.warningMessage;
    }
    notifyListeners();
    final reqId = ++_searchRequestId;
    await Future.wait([
      discoverSuppliers(requestId: reqId),
      fetchOurPicksRecommendations(requestId: reqId),
    ]);
  }

  Future<void> setManualLocation({
    required String addressLine,
    String city = 'Islamabad',
    double? lat,
    double? lng,
    bool saveToAccount = false,
  }) async {
    selectedAddressLine = addressLine.trim();
    selectedCity = city.trim();
    if (lat != null && lng != null) {
      selectedLat = lat;
      selectedLng = lng;
      hasAccurateGps = true;
      locationWarning = null;
    } else {
      selectedLat = null;
      selectedLng = null;
      hasAccurateGps = false;
      locationWarning =
          'Manual address without exact GPS coordinates: exact map delivery pin is unavailable until GPS or map location is selected.';
    }
    notifyListeners();

    if (saveToAccount && isAuthenticated) {
      try {
        await apiClient.post(
          '/addresses',
          data: {
            'label': 'Saved',
            'addressLine': selectedAddressLine,
            'city': selectedCity,
            'lat': selectedLat,
            'lng': selectedLng,
            'hasAccurateCoordinates': hasAccurateGps,
            'isDefault': true,
          },
        );
        await fetchAddresses();
      } catch (_) {}
    }

    final reqId = ++_searchRequestId;
    await Future.wait([
      discoverSuppliers(requestId: reqId),
      fetchOurPicksRecommendations(requestId: reqId),
    ]);
  }

  Future<void> fetchAddresses() async {
    if (!isAuthenticated) return;
    try {
      final res = await apiClient.get('/addresses');
      if (res['data'] is List) {
        savedAddresses = (res['data'] as List)
            .map(
              (e) => DeliveryAddressModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> deleteAddress(String id) async {
    await apiClient.delete('/addresses/$id');
    await fetchAddresses();
  }

  Future<void> discoverSuppliers({int? requestId}) async {
    isLoadingSuppliers = true;
    suppliersError = null;
    notifyListeners();
    try {
      final res = await apiClient.get(
        '/suppliers/discover',
        queryParameters: {
          'capacityLiters': selectedCapacityLiters,
          'lat': selectedLat,
          'lng': selectedLng,
          'sortBy': selectedSortBy,
        },
      );
      if (requestId != null && requestId != _searchRequestId) return;
      final data = Map<String, dynamic>.from(res['data'] as Map);
      final list = (data['suppliers'] as List)
          .map(
            (e) => SupplierOfferModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
      discoveredSuppliers = list;

      final allRes = await apiClient.get(
        '/suppliers/discover',
        queryParameters: {
          'lat': selectedLat,
          'lng': selectedLng,
          'sortBy': 'best_match',
        },
      );
      if (requestId != null && requestId != _searchRequestId) return;
      final allData = Map<String, dynamic>.from(allRes['data'] as Map);
      homeTopSuppliers = (allData['suppliers'] as List)
          .map(
            (e) => SupplierOfferModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } on ApiException catch (e) {
      if (requestId != null && requestId != _searchRequestId) return;
      suppliersError = e.message;
    } catch (e) {
      if (requestId != null && requestId != _searchRequestId) return;
      suppliersError = e.toString();
    } finally {
      if (requestId == null || requestId == _searchRequestId) {
        isLoadingSuppliers = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchOurPicksRecommendations({int? capacity, int? requestId}) async {
    isLoadingOurPicks = true;
    ourPicksError = null;
    notifyListeners();
    try {
      final res = await apiClient.get(
        '/ai/recommendations',
        queryParameters: {
          'capacityLiters': capacity ?? selectedCapacityLiters,
          'lat': selectedLat,
          'lng': selectedLng,
          'sortBy': selectedSortBy,
        },
      );
      if (requestId != null && requestId != _searchRequestId) return;
      final data = Map<String, dynamic>.from(res['data'] as Map);
      ourPicksSuppliers = (data['suppliers'] as List)
          .map(
            (e) => SupplierOfferModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    } on ApiException catch (e) {
      if (requestId != null && requestId != _searchRequestId) return;
      ourPicksError = e.message;
    } catch (e) {
      if (requestId != null && requestId != _searchRequestId) return;
      ourPicksError = e.toString();
    } finally {
      if (requestId == null || requestId == _searchRequestId) {
        isLoadingOurPicks = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchAiRecommendations({int? capacity}) =>
      fetchOurPicksRecommendations(capacity: capacity);

  Future<Map<String, dynamic>> fetchSupplierPublicDetail(
    String supplierId,
  ) async {
    final res = await apiClient.get(
      '/suppliers/$supplierId',
      queryParameters: {'lat': selectedLat, 'lng': selectedLng},
    );
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<BookingModel> createBooking({
    required SupplierOfferModel offer,
    required String idempotencyKey,
    int? customWaterQuantity,
    int? customExpectedTotal,
    String? replacedFromBookingId,
  }) async {
    final qty = customWaterQuantity ?? offer.capacityLiters;
    final total = customExpectedTotal ?? offer.totalPrice;

    final payload = <String, dynamic>{
      'listingId': offer.listingId,
      'supplierId': offer.supplierId,
      'capacityLiters': qty,
      'waterQuantityLiters': qty,
      'expectedTotalPrice': total,
      'idempotencyKey': idempotencyKey,
      'customerPhone': currentUser?.phone ?? '',
      'deliveryAddress': {
        'addressLine': selectedAddressLine,
        'city': selectedCity,
        'lat': hasAccurateGps ? selectedLat : null,
        'lng': hasAccurateGps ? selectedLng : null,
        'hasAccurateCoordinates': hasAccurateGps,
      },
    };
    if (replacedFromBookingId != null) {
      payload['replacedFromBookingId'] = replacedFromBookingId;
    }

    final res = await apiClient.post('/bookings', data: payload);
    final booking = BookingModel.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
    await fetchBookings();
    await fetchNotifications();
    return booking;
  }

  Future<void> fetchBookings() async {
    if (!isAuthenticated) return;
    isLoadingBookings = true;
    bookingsError = null;
    notifyListeners();
    try {
      final res = await apiClient.get('/bookings');
      final list = (res['data'] as List)
          .map(
            (e) => BookingModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      bookings = list;
      if (isSupplier) {
        supplierOrders = list;
      }
    } on ApiException catch (e) {
      bookingsError = e.message;
    } catch (e) {
      bookingsError = e.toString();
    } finally {
      isLoadingBookings = false;
      notifyListeners();
    }
  }

  Future<BookingModel> updateBookingStatus({
    required String bookingId,
    required String status,
    String? reason,
    String? deliveryCode,
  }) async {
    final payload = <String, dynamic>{'status': status};
    if (reason != null) payload['reason'] = reason;
    if (deliveryCode != null) payload['deliveryCode'] = deliveryCode;

    final res = await apiClient.post(
      '/bookings/$bookingId/status',
      data: payload,
    );
    final updated = BookingModel.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );

    if (isSupplier) {
      if (['accepted', 'dispatched', 'arriving'].contains(status)) {
        // Start or ensure real GPS tracking is active for this order
        locationBroadcaster.startBroadcastingForOrder(bookingId);
      } else if ([
        'delivered',
        'cancelled',
        'rejected',
        'failed',
        'expired',
      ].contains(status)) {
        await locationBroadcaster.stopBroadcastingForOrder(
          bookingId,
          notifyBackend: false,
        );
      }
    }

    await fetchBookings();
    if (isSupplier) {
      await fetchSupplierDashboard();
      await fetchWallet();
    }
    await fetchNotifications();
    return updated;
  }

  Future<List<SupplierOfferModel>> fetchAlternativesForBooking(
    String bookingId,
  ) async {
    final res = await apiClient.get('/bookings/$bookingId/alternatives');
    final data = Map<String, dynamic>.from(res['data'] as Map);
    return (data['alternatives'] as List)
        .map(
          (e) =>
              SupplierOfferModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> submitReview({
    required String bookingId,
    required int rating,
    required List<String> tags,
    required String comment,
  }) async {
    await apiClient.post(
      '/reviews',
      data: {
        'bookingId': bookingId,
        'rating': rating,
        'tags': tags,
        'comment': comment,
      },
    );
    await fetchBookings();
    await discoverSuppliers();
  }

  Future<void> saveSchedulePreferences({
    required String mode,
    required List<String> repeatDays,
    required String deliveryWindow,
    required int quantityLiters,
  }) async {
    final res = await apiClient.put(
      '/auth/me',
      data: {
        'preferences': {
          'scheduleMode': mode,
          'repeatDays': repeatDays,
          'deliveryWindow': deliveryWindow,
          'scheduleQuantityLiters': quantityLiters,
          'scheduleActive': true,
        },
      },
    );
    final data = Map<String, dynamic>.from(res['data'] as Map);
    currentUser = UserModel.fromJson(
      Map<String, dynamic>.from(data['user'] as Map),
    );
    notifyListeners();
  }

  Future<void> updateCustomerProfile({
    required String name,
    required String phone,
    String? customerCategory,
  }) async {
    final payload = <String, dynamic>{'name': name, 'phone': phone};
    if (customerCategory != null) {
      payload['customerCategory'] = customerCategory;
    }
    final res = await apiClient.put('/auth/me', data: payload);
    final data = Map<String, dynamic>.from(res['data'] as Map);
    currentUser = UserModel.fromJson(
      Map<String, dynamic>.from(data['user'] as Map),
    );
    notifyListeners();
  }

  Future<void> fetchNotifications() async {
    if (!isAuthenticated) return;
    try {
      final res = await apiClient.get('/notifications');
      final data = Map<String, dynamic>.from(res['data'] as Map);
      notifications = (data['notifications'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      unreadNotificationsCount = (data['unreadCount'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllNotificationsRead() async {
    await apiClient.post('/notifications/read-all');
    await fetchNotifications();
  }

  Future<void> fetchSupplierDashboard() async {
    if (!isSupplier) return;
    isLoadingSupplierDashboard = true;
    notifyListeners();
    try {
      final res = await apiClient.get('/suppliers/me');
      final data = Map<String, dynamic>.from(res['data'] as Map);
      supplierProfile = Map<String, dynamic>.from(data['profile'] as Map);
      supplierListings = (data['listings'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      supplierOrders = (data['bookings'] as List)
          .map(
            (e) => BookingModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      supplierReviews = (data['reviews'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
    } finally {
      isLoadingSupplierDashboard = false;
      notifyListeners();
    }
  }

  Future<void> updateSupplierProfileData(Map<String, dynamic> updates) async {
    final res = await apiClient.put('/suppliers/me', data: updates);
    supplierProfile = Map<String, dynamic>.from(res['data'] as Map);
    notifyListeners();
  }

  Future<void> createSupplierListing(Map<String, dynamic> payload) async {
    await apiClient.post('/suppliers/listings', data: payload);
    await fetchSupplierDashboard();
  }

  Future<void> updateSupplierListing(
    String listingId,
    Map<String, dynamic> payload,
  ) async {
    await apiClient.put('/suppliers/listings/$listingId', data: payload);
    await fetchSupplierDashboard();
  }

  Future<void> deleteSupplierListing(String listingId) async {
    await apiClient.delete('/suppliers/listings/$listingId');
    await fetchSupplierDashboard();
  }

  Future<void> fetchWallet() async {
    if (!isSupplier) return;
    isLoadingWallet = true;
    notifyListeners();
    try {
      final res = await apiClient.get('/wallet');
      final data = Map<String, dynamic>.from(res['data'] as Map);
      walletSummary = Map<String, dynamic>.from(data['summary'] as Map);
      walletCommissionHistory =
          ((data['commissionHistory'] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
      walletPaymentHistory = ((data['paymentHistory'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      walletLedger = ((data['ledger'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      walletSettlements = ((data['settlements'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
    } finally {
      isLoadingWallet = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> initiateSafepayCommissionPayment({
    int? amount,
    String returnTarget = 'wallet',
  }) async {
    final payload = <String, dynamic>{
      'currency': 'PKR',
      'returnTarget': returnTarget,
      'clientBaseUrl': AppConfig.apiBaseUrl,
    };
    if (kIsWeb) {
      try {
        payload['clientOrigin'] = Uri.base.origin;
      } catch (_) {}
    }
    if (amount != null) {
      payload['amount'] = amount;
    }
    final res = await apiClient.post('/wallet/safepay/session', data: payload);
    final data = Map<String, dynamic>.from(res['data'] as Map);
    await fetchWallet();
    return data;
  }

  Future<Map<String, dynamic>> verifySafepayCommissionPayment({
    required String paymentReference,
    String? tracker,
    String? sig,
  }) async {
    final payload = <String, dynamic>{'paymentReference': paymentReference};
    if (tracker != null && tracker.trim().isNotEmpty) {
      payload['tracker'] = tracker.trim();
    }
    if (sig != null && sig.trim().isNotEmpty) {
      payload['sig'] = sig.trim();
    }
    final res = await apiClient.post('/wallet/safepay/verify', data: payload);
    final data = Map<String, dynamic>.from(res['data'] as Map);
    await fetchWallet();
    await fetchSupplierDashboard();
    await fetchNotifications();
    return data;
  }

  Future<Map<String, dynamic>> cancelSafepayCommissionPayment({
    required String paymentReference,
    String status = 'cancelled',
    String? reason,
  }) async {
    final payload = <String, dynamic>{
      'paymentReference': paymentReference,
      'status': status,
    };
    if (reason != null && reason.trim().isNotEmpty) {
      payload['reason'] = reason.trim();
    }
    final res = await apiClient.post('/wallet/safepay/cancel', data: payload);
    final data = Map<String, dynamic>.from(res['data'] as Map);
    await fetchWallet();
    return data;
  }

  Future<Map<String, dynamic>> fetchAdminCommissionOverview({
    required String adminAuthorizationKey,
  }) async {
    final res = await apiClient.get(
      '/wallet/admin/overview',
      queryParameters: {'adminKey': adminAuthorizationKey.trim()},
    );
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<void> recordAuthorizedSettlement({
    required int amount,
    required String adminAuthorizationKey,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'amount': amount,
      'adminAuthorizationKey': adminAuthorizationKey,
    };
    if (notes != null) payload['notes'] = notes;
    await apiClient.post('/wallet/settle', data: payload);
    await fetchWallet();
    await fetchSupplierDashboard();
    await fetchNotifications();
  }

  // ---------------------------------------------------------------------------
  // Admin Dashboard & Management APIs (Restricted to role == 'admin')
  // ---------------------------------------------------------------------------

  Future<void> refreshAllAdminData() async {
    if (!isAdmin) return;
    await Future.wait([
      fetchAdminDashboard(),
      fetchAdminPendingSuppliers(),
      fetchAdminPendingCustomers(),
      fetchAdminSuppliers(),
      fetchAdminCustomers(),
      fetchAdminPayments(),
    ]);
  }

  Future<void> fetchAdminDashboard() async {
    if (!isAdmin) return;
    isLoadingAdminDashboard = true;
    adminError = null;
    notifyListeners();
    try {
      final res = await apiClient.get('/admin/dashboard');
      final data = Map<String, dynamic>.from(res['data'] as Map);
      adminDashboardSummary = Map<String, dynamic>.from(
        (data['summary'] as Map?) ?? const {},
      );
      adminRecentPayments = ((data['recentPayments'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      adminOverdueSuppliers = ((data['overdueSuppliers'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      adminAuditLogs = ((data['recentAuditLogs'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } on ApiException catch (e) {
      adminError = e.message;
    } catch (e) {
      adminError = e.toString();
    } finally {
      isLoadingAdminDashboard = false;
      notifyListeners();
    }
  }

  Future<void> fetchAdminSuppliers({String? filter, String? search}) async {
    if (!isAdmin) return;
    if (filter != null) adminSupplierFilter = filter;
    if (search != null) adminSupplierSearch = search;
    isLoadingAdminSuppliers = true;
    notifyListeners();
    try {
      final res = await apiClient.get(
        '/admin/suppliers',
        queryParameters: {
          'filter': adminSupplierFilter,
          'search': adminSupplierSearch,
        },
      );
      final data = Map<String, dynamic>.from(res['data'] as Map);
      adminSuppliers = ((data['suppliers'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } on ApiException catch (e) {
      adminError = e.message;
    } catch (e) {
      adminError = e.toString();
    } finally {
      isLoadingAdminSuppliers = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> fetchAdminSupplierDetail(
    String supplierId,
  ) async {
    final res = await apiClient.get('/admin/suppliers/$supplierId');
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<Map<String, dynamic>> setSupplierAccountLock({
    required String supplierId,
    required bool locked,
    String? reason,
  }) async {
    final payload = <String, dynamic>{'locked': locked};
    if (reason != null && reason.trim().isNotEmpty) {
      payload['reason'] = reason.trim();
    }
    final res = await apiClient.patch(
      '/admin/suppliers/$supplierId/lock',
      data: payload,
    );
    await Future.wait([fetchAdminDashboard(), fetchAdminSuppliers()]);
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<void> fetchAdminCustomers({String? filter, String? search}) async {
    if (!isAdmin) return;
    if (filter != null) adminCustomerFilter = filter;
    if (search != null) adminCustomerSearch = search;
    isLoadingAdminCustomers = true;
    notifyListeners();
    try {
      final res = await apiClient.get(
        '/admin/customers',
        queryParameters: {
          'filter': adminCustomerFilter,
          'search': adminCustomerSearch,
        },
      );
      final data = Map<String, dynamic>.from(res['data'] as Map);
      adminCustomers = ((data['customers'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } on ApiException catch (e) {
      adminError = e.message;
    } catch (e) {
      adminError = e.toString();
    } finally {
      isLoadingAdminCustomers = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> fetchAdminCustomerDetail(
    String customerId,
  ) async {
    final res = await apiClient.get('/admin/customers/$customerId');
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<Map<String, dynamic>> setCustomerAccountLock({
    required String customerId,
    required bool locked,
    String? reason,
  }) async {
    final payload = <String, dynamic>{'locked': locked};
    if (reason != null && reason.trim().isNotEmpty) {
      payload['reason'] = reason.trim();
    }
    final res = await apiClient.patch(
      '/admin/customers/$customerId/lock',
      data: payload,
    );
    await Future.wait([fetchAdminDashboard(), fetchAdminCustomers()]);
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<void> fetchAdminPayments({String? filter, String? search}) async {
    if (!isAdmin) return;
    if (filter != null) adminPaymentFilter = filter;
    if (search != null) adminPaymentSearch = search;
    isLoadingAdminPayments = true;
    notifyListeners();
    try {
      final res = await apiClient.get(
        '/admin/payments',
        queryParameters: {
          'filter': adminPaymentFilter,
          'search': adminPaymentSearch,
        },
      );
      final data = Map<String, dynamic>.from(res['data'] as Map);
      adminPayments = ((data['items'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (data['counts'] is Map) {
        adminPaymentCounts = Map<String, dynamic>.from(data['counts'] as Map);
      }
    } on ApiException catch (e) {
      adminError = e.message;
    } catch (e) {
      adminError = e.toString();
    } finally {
      isLoadingAdminPayments = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> fetchAdminPaymentDetail(String paymentId) async {
    final res = await apiClient.get('/admin/payments/$paymentId');
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<void> fetchAdminPendingSuppliers([String? search]) async {
    if (!isAdmin) return;
    if (search != null) adminPendingSupplierSearch = search;
    isLoadingAdminPendingSuppliers = true;
    notifyListeners();
    try {
      final res = await apiClient.get(
        '/admin/pending-suppliers',
        queryParameters: {'search': adminPendingSupplierSearch},
      );
      final data = Map<String, dynamic>.from(res['data'] as Map);
      adminPendingSuppliers = ((data['pendingSuppliers'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } on ApiException catch (e) {
      adminError = e.message;
    } catch (e) {
      adminError = e.toString();
    } finally {
      isLoadingAdminPendingSuppliers = false;
      notifyListeners();
    }
  }

  Future<void> fetchAdminPendingCustomers([String? search]) async {
    if (!isAdmin) return;
    if (search != null) adminPendingCustomerSearch = search;
    isLoadingAdminPendingCustomers = true;
    notifyListeners();
    try {
      final res = await apiClient.get(
        '/admin/pending-customers',
        queryParameters: {'search': adminPendingCustomerSearch},
      );
      final data = Map<String, dynamic>.from(res['data'] as Map);
      adminPendingCustomers = ((data['pendingCustomers'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } on ApiException catch (e) {
      adminError = e.message;
    } catch (e) {
      adminError = e.toString();
    } finally {
      isLoadingAdminPendingCustomers = false;
      notifyListeners();
    }
  }

  Future<bool> approveSupplier(String supplierId) async {
    try {
      await apiClient.post('/admin/suppliers/$supplierId/approve');
      await Future.wait([
        fetchAdminDashboard(),
        fetchAdminPendingSuppliers(),
        fetchAdminSuppliers(),
      ]);
      return true;
    } catch (e) {
      adminError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectSupplier(String supplierId, String reason) async {
    try {
      await apiClient.post(
        '/admin/suppliers/$supplierId/reject',
        data: {'reason': reason},
      );
      await Future.wait([
        fetchAdminDashboard(),
        fetchAdminPendingSuppliers(),
      ]);
      return true;
    } catch (e) {
      adminError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> approveCustomer(String customerId) async {
    try {
      await apiClient.post('/admin/customers/$customerId/approve');
      await Future.wait([
        fetchAdminDashboard(),
        fetchAdminPendingCustomers(),
        fetchAdminCustomers(),
      ]);
      return true;
    } catch (e) {
      adminError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectCustomer(String customerId, String reason) async {
    try {
      await apiClient.post(
        '/admin/customers/$customerId/reject',
        data: {'reason': reason},
      );
      await Future.wait([
        fetchAdminDashboard(),
        fetchAdminPendingCustomers(),
      ]);
      return true;
    } catch (e) {
      adminError = e.toString();
      notifyListeners();
      return false;
    }
  }
}
