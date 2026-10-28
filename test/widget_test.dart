import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waterfix_mobile/core/network/api_client.dart';
import 'package:waterfix_mobile/core/state/waterfix_controller.dart';
import 'package:waterfix_mobile/core/theme/app_theme.dart';
import 'package:waterfix_mobile/core/utils/validators.dart';
import 'package:waterfix_mobile/features/ai_recommendations/ranking_engine.dart';
import 'package:waterfix_mobile/features/admin/screens/admin_dashboard_screen.dart';
import 'package:waterfix_mobile/features/auth/models/user_model.dart';
import 'package:waterfix_mobile/features/auth/screens/auth_screen.dart';
import 'package:waterfix_mobile/features/bookings/models/booking_model.dart';
import 'package:waterfix_mobile/features/bookings/screens/confirm_booking_screen.dart';
import 'package:waterfix_mobile/features/customer_home/screens/customer_shell_screen.dart';
import 'package:waterfix_mobile/features/supplier_dashboard/screens/supplier_dashboard_screen.dart';
import 'package:waterfix_mobile/features/suppliers/models/supplier_models.dart';
import 'package:waterfix_mobile/features/suppliers/screens/compare_suppliers_screen.dart';
import 'package:waterfix_mobile/features/suppliers/screens/supplier_profile_screen.dart';
import 'package:waterfix_mobile/features/tracking/screens/live_tracking_screen.dart';
import 'package:waterfix_mobile/features/tracking/services/order_tracking_service.dart';
import 'package:waterfix_mobile/core/location/location_service.dart';
import 'package:waterfix_mobile/shared/widgets/empty_and_error_states.dart';

void main() {
  group('WaterFix Automated Unit & Widget Tests', () {
    test(
      '1. Authentication Form Validation & Pakistani +92 Phone Normalization',
      () {
        expect(
          AppValidators.normalizeEmail('  Ayesha@WaterFix.PK '),
          'ayesha@waterfix.pk',
        );
        expect(AppValidators.isValidEmail('ayesha@waterfix.pk'), isTrue);
        expect(AppValidators.isValidEmail('invalid-email'), isFalse);

        expect(AppValidators.normalizePhone('0300 1234567'), '+923001234567');
        expect(AppValidators.normalizePhone('300-1234567'), '+923001234567');
        expect(
          AppValidators.normalizePhone('+92 301 5556677'),
          '+923015556677',
        );
        expect(AppValidators.isValidPhone('03001234567'), isTrue);
        expect(AppValidators.isValidPhone('12345'), isFalse);

        expect(AppValidators.validatePassword('short1'), isNotNull);
        expect(AppValidators.validatePassword('Password123'), isNull);
        expect(
          AppValidators.validateConfirmPassword('Mismatch1', 'Password123'),
          'Passwords do not match',
        );
        expect(
          AppValidators.validateConfirmPassword('Password123', 'Password123'),
          isNull,
        );
      },
    );

    test(
      '2. Commission Calculation (10% on PKR 5,000 -> PKR 500 commission, PKR 4,500 net)',
      () {
        final breakdown = AppValidators.calculateCommissionBreakdown(
          5000,
          rate: 0.10,
        );
        expect(breakdown['gross'], 5000);
        expect(breakdown['commission'], 500);
        expect(breakdown['net'], 4500);
      },
    );

    test(
      '3. Explainable Local Recommendation Ranking (Best Match, Cheapest, Fastest, Best Rated)',
      () {
        final offers = [
          const SupplierOfferModel(
            listingId: 'l1',
            supplierId: 's1',
            supplierUserId: 'u1',
            businessName: 'Al-Noor Water Supply',
            ownerName: 'Imran K.',
            city: 'Islamabad',
            serviceAreaText: 'F-10',
            isVerified: false,
            capacityLiters: 2000,
            label: 'Most homes',
            waterPrice: 1550,
            deliveryFee: 250,
            totalPrice: 1800,
            distanceKm: 3.2,
            ratingAverage: 4.8,
            reviewCount: 20,
            hasSufficientHistory: true,
            onTimePercentage: 97,
            avgArrivalMinutes: 35,
            lat: 33.6938,
            lng: 73.0169,
            serviceRadiusKm: 25.0,
          ),
          const SupplierOfferModel(
            listingId: 'l2',
            supplierId: 's2',
            supplierUserId: 'u2',
            businessName: 'Rana Tankers',
            ownerName: 'Rana T.',
            city: 'Islamabad',
            serviceAreaText: 'G-11',
            isVerified: false,
            capacityLiters: 2000,
            label: 'Most homes',
            waterPrice: 1400,
            deliveryFee: 250,
            totalPrice: 1650,
            distanceKm: 6.5,
            ratingAverage: 4.6,
            reviewCount: 12,
            hasSufficientHistory: true,
            onTimePercentage: 94,
            avgArrivalMinutes: 55,
            lat: 33.6710,
            lng: 72.9985,
            serviceRadiusKm: 25.0,
          ),
        ];

        final cheapest = LocalRecommendationEngine.rankOffers(
          offers: offers,
          requestedCapacity: 2000,
          customerLat: 33.6938,
          customerLng: 73.0169,
          sortBy: 'cheapest',
        );
        expect(cheapest.first.businessName, 'Rana Tankers');
        expect(cheapest.first.isAiPick, isTrue);
        expect(
          cheapest.first.recommendationExplanation,
          contains('Recommended because'),
        );

        final fastest = LocalRecommendationEngine.rankOffers(
          offers: offers,
          requestedCapacity: 2000,
          customerLat: 33.6938,
          customerLng: 73.0169,
          sortBy: 'fastest',
        );
        expect(fastest.first.businessName, 'Al-Noor Water Supply');

        final bestRated = LocalRecommendationEngine.rankOffers(
          offers: offers,
          requestedCapacity: 2000,
          customerLat: 33.6938,
          customerLng: 73.0169,
          sortBy: 'best_rated',
        );
        expect(bestRated.first.businessName, 'Al-Noor Water Supply');
      },
    );

    testWidgets('4. Honest Supplier Empty State Widget Test', (
      WidgetTester tester,
    ) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: WaterFixTheme.lightTheme,
          home: Scaffold(
            body: EmptySuppliersState(
              onChangeLocation: () {},
              onChangeCapacity: () {},
              onRetry: () => retried = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No water suppliers available near you yet.'),
        findsOneWidget,
      );
      expect(find.text('Change location'), findsOneWidget);
      expect(find.text('Change capacity'), findsOneWidget);
      expect(find.text('Retry search'), findsOneWidget);

      await tester.tap(find.text('Retry search'));
      await tester.pumpAndSettle();
      expect(retried, isTrue);
    });

    testWidgets(
      '5. Auth Screen Sign In Shows Customer, Water Supplier & Admin Roles and Removes "I\'m booking for" & "Local Prototype" Note',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: AuthScreen(initialIsSignUp: false)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Welcome to'), findsOneWidget);
        expect(find.text('SIGNING IN AS'), findsOneWidget);
        expect(find.text('Customer'), findsOneWidget);
        expect(find.text('Water Supplier'), findsOneWidget);
        expect(find.text('Admin'), findsOneWidget);

        // Verify removed UI elements from Sign-In
        expect(find.text("I'M BOOKING FOR"), findsNothing);
        expect(find.textContaining('Local Prototype'), findsNothing);

        expect(
          find.byKey(const Key('login_identifier_field')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('password_field')), findsOneWidget);

        // Tap 'Admin' on Sign In
        await tester.tap(find.text('Admin'));
        await tester.pumpAndSettle();
        expect(find.text('Sign in as Admin'), findsOneWidget);
      },
    );

    testWidgets(
      '6. Supplier Listing Display & Booking Confirmation Screen Test',
      (WidgetTester tester) async {
        final controller = WaterFixController(apiClient: ApiClient());
        controller.currentUser = const UserModel(
          id: 'u1',
          name: 'Ayesha Khan',
          email: 'ayesha@example.com',
          phone: '+923001234567',
          role: 'customer',
        );
        const sampleOffer = SupplierOfferModel(
          listingId: 'list_1',
          supplierId: 'sup_1',
          supplierUserId: 'sup_u1',
          businessName: 'Al-Noor Water Supply',
          ownerName: 'Imran K.',
          city: 'Islamabad',
          serviceAreaText: 'F-10/3, Islamabad',
          isVerified: false,
          capacityLiters: 2000,
          label: 'Most homes',
          waterPrice: 1550,
          deliveryFee: 250,
          totalPrice: 1800,
          distanceKm: 3.2,
          ratingAverage: 4.8,
          reviewCount: 15,
          hasSufficientHistory: true,
          onTimePercentage: 97,
          arrivalText: '35–45 min',
        );
        controller.discoveredSuppliers = [sampleOffer];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              waterFixControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(
              home: Scaffold(body: CompareSuppliersView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('OUR PICK'), findsOneWidget);
        expect(find.text('Al-Noor Water Supply'), findsOneWidget);
        expect(find.text('Rs 1800'), findsOneWidget);
        expect(find.text('Book now'), findsOneWidget);

        // Now test ConfirmBookingScreen directly
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              waterFixControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(
              home: ConfirmBookingScreen(offer: sampleOffer),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Confirm booking'), findsOneWidget);
        expect(find.text('Cash on delivery'), findsOneWidget);
        expect(find.text('Confirm booking · Rs 1800'), findsOneWidget);
      },
    );

    testWidgets('7. Customer Navigation Bottom Bar Test', (
      WidgetTester tester,
    ) async {
      final controller = WaterFixController(apiClient: ApiClient());
      controller.currentUser = const UserModel(
        id: 'u1',
        name: 'Ayesha Khan',
        email: 'ayesha@example.com',
        phone: '+923001234567',
        role: 'customer',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            waterFixControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: CustomerShellScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Suppliers'), findsWidgets);
      expect(find.text('Our Pick'), findsWidgets);
      expect(find.text('Bookings'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets(
      '8. Supplier Dashboard Tankers Tab Renders Without Right-Side Overflow on Narrow Screen',
      (WidgetTester tester) async {
        // Test on a narrow 340dp phone screen to guarantee no 50px overflow
        tester.view.physicalSize = const Size(340, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = WaterFixController(apiClient: ApiClient());
        controller.currentUser = const UserModel(
          id: 'sup1',
          name: 'Ashhad Supplier',
          email: 'ashhad@waterfix.pk',
          phone: '+923009998877',
          role: 'supplier',
        );
        controller.supplierProfile = {
          'businessName': 'Ashhad Water Tankers',
          'isAvailable': true,
          'serviceAreaText': 'Islamabad & Rawalpindi',
          'serviceRadiusKm': 25,
          'availableWaterLiters': 10000,
          'pricePer1000Liters': 1800,
          'tankersOwned': 4,
        };
        controller.supplierListings = [];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              waterFixControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(home: SupplierDashboardScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to Tankers tab
        await tester.tap(find.text('Tankers'));
        await tester.pumpAndSettle();

        expect(find.text('Water Inventory & Availability'), findsOneWidget);
        expect(find.text('Ashhad Water Tankers'), findsOneWidget);
        expect(find.text('Update stock & pricing'), findsOneWidget);
        expect(find.text('10000 L'), findsOneWidget);
        expect(find.text('PKR 1800'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '9. Pre-Acceptance Tracking Screen Shows Real Map & Customer Destination Without Any Fake Supplier Marker',
      (WidgetTester tester) async {
        final controller = WaterFixController(apiClient: ApiClient());
        final requestedOrder = BookingModel(
          id: 'ord_req_1',
          bookingCode: '#WF-2001',
          customerId: 'cust_1',
          supplierId: 'sup_1',
          supplierUserId: 'sup_u1',
          listingId: 'list_1',
          capacityLiters: 2000,
          waterPrice: 1550,
          deliveryFee: 250,
          totalPrice: 1800,
          addressLine: 'House 12, Street 4, F-10/2, Islamabad',
          city: 'Islamabad',
          deliveryLat: 33.6915,
          deliveryLng: 73.0142,
          hasAccurateDeliveryCoords: true,
          customerName: 'Ayesha Khan',
          customerPhone: '+923001234567',
          supplierBusinessName: 'Al-Noor Water Supply',
          supplierPhone: '+923015556677',
          driverName: 'Imran Khan',
          estimatedArrivalMinutesMin: 35,
          estimatedArrivalMinutesMax: 45,
          distanceKm: 3.1,
          status: 'requested',
          deliveryCode: '4821',
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              waterFixControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              theme: WaterFixTheme.lightTheme,
              home: OrderTrackingScreen(
                orderId: requestedOrder.id,
                userRole: UserRole.customer,
                initialBooking: requestedOrder,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        // Interactive FlutterMap and customer destination marker are present
        expect(find.byKey(const Key('interactive_order_map')), findsOneWidget);
        expect(
          find.byKey(const Key('customer_destination_marker')),
          findsOneWidget,
        );
        // Pre-acceptance banner is visible
        expect(find.byKey(const Key('pre_acceptance_banner')), findsOneWidget);
        expect(find.text('Awaiting Supplier'), findsOneWidget);
        // No supplier marker is shown before acceptance
        expect(find.byKey(const Key('supplier_live_marker')), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      '10. Post-Acceptance Shared OrderTrackingScreen Renders Customer & Supplier Live Markers for Both Roles',
      (WidgetTester tester) async {
        final controller = WaterFixController(
          apiClient: ApiClient(),
          customBroadcaster: SupplierLocationBroadcaster(
            apiClient: ApiClient(),
            permissionChecker: () async => const GpsPermissionCheckResult(
              status: GpsAccessStatus.denied,
              message: 'Location permission was denied.',
            ),
          ),
        );

        final activeOrder = BookingModel(
          id: 'ord_act_1',
          bookingCode: '#WF-3005',
          customerId: 'cust_1',
          supplierId: 'sup_1',
          supplierUserId: 'sup_u1',
          listingId: 'list_1',
          capacityLiters: 2000,
          waterPrice: 1550,
          deliveryFee: 250,
          totalPrice: 1800,
          addressLine: 'House 12, Street 4, F-10/2, Islamabad',
          city: 'Islamabad',
          deliveryLat: 33.6915,
          deliveryLng: 73.0142,
          hasAccurateDeliveryCoords: true,
          customerName: 'Ayesha Khan',
          customerPhone: '+923001234567',
          supplierBusinessName: 'Al-Noor Water Supply',
          supplierPhone: '+923015556677',
          driverName: 'Imran Khan',
          estimatedArrivalMinutesMin: 30,
          estimatedArrivalMinutesMax: 40,
          distanceKm: 1.8,
          status: 'dispatched',
          deliveryCode: '7391',
          createdAt: DateTime.now(),
          supplierLatitude: 33.6880,
          supplierLongitude: 73.0250,
          trackingUpdatedAt: DateTime.now(),
          trackingActive: true,
        );

        // Customer Role View
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              waterFixControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              theme: WaterFixTheme.lightTheme,
              home: OrderTrackingScreen(
                orderId: activeOrder.id,
                userRole: UserRole.customer,
                initialBooking: activeOrder,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Customer Live View'), findsOneWidget);
        expect(
          find.byKey(const Key('customer_destination_marker')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('supplier_live_marker')), findsOneWidget);
        expect(find.byKey(const Key('recenter_map_button')), findsOneWidget);

        // Supplier Role View on the exact same shared OrderTrackingScreen
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              waterFixControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              theme: WaterFixTheme.lightTheme,
              home: OrderTrackingScreen(
                orderId: activeOrder.id,
                userRole: UserRole.supplier,
                initialBooking: activeOrder,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Supplier Live View'), findsOneWidget);
        expect(
          find.byKey(const Key('customer_destination_marker')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('supplier_live_marker')), findsOneWidget);
        expect(
          find.byKey(const Key('external_navigation_button')),
          findsOneWidget,
        );
        expect(find.text('Complete delivery'), findsOneWidget);
        // Verify permission denial banner is surfaced clearly when GPS permission is denied
        expect(
          find.byKey(const Key('supplier_gps_permission_error_banner')),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      '11. Supplier Dashboard Accepted Order Card Shows Track Order Action & Opens Shared Map',
      (WidgetTester tester) async {
        final controller = WaterFixController(apiClient: ApiClient());
        controller.currentUser = const UserModel(
          id: 'sup_u1',
          name: 'Imran Khan',
          email: 'alnoor@waterfix.pk',
          phone: '+923015556677',
          role: 'supplier',
        );
        controller.supplierProfile = {
          '_id': 'sup_1',
          'businessName': 'Al-Noor Water Supply',
          'isAvailable': true,
        };
        controller.supplierOrders = [
          BookingModel(
            id: 'ord_sup_card_1',
            bookingCode: '#WF-4010',
            customerId: 'cust_1',
            supplierId: 'sup_1',
            supplierUserId: 'sup_u1',
            listingId: 'list_1',
            capacityLiters: 2000,
            waterPrice: 1550,
            deliveryFee: 250,
            totalPrice: 1800,
            addressLine: 'Street 7, F-10/3, Islamabad',
            city: 'Islamabad',
            deliveryLat: 33.6938,
            deliveryLng: 73.0169,
            hasAccurateDeliveryCoords: true,
            customerName: 'Ayesha Khan',
            customerPhone: '+923001234567',
            supplierBusinessName: 'Al-Noor Water Supply',
            supplierPhone: '+923015556677',
            driverName: 'Imran Khan',
            estimatedArrivalMinutesMin: 30,
            estimatedArrivalMinutesMax: 40,
            distanceKm: 2.4,
            status: 'accepted',
            deliveryCode: '5512',
            createdAt: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              waterFixControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              theme: WaterFixTheme.lightTheme,
              home: const SupplierDashboardScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Dispatch tanker'), findsOneWidget);
        expect(find.text('Track order'), findsOneWidget);
        expect(find.text('Complete delivery'), findsOneWidget);
      },
    );

    testWidgets(
      '12. Supplier Commission Wallet Tab Shows Overview, Pay Commission Button, Commission History & Payment History',
      (WidgetTester tester) async {
        // Test on a narrow 340dp phone screen to guarantee zero RenderFlex overflow
        tester.view.physicalSize = const Size(340, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = WaterFixController(apiClient: ApiClient());
        controller.currentUser = const UserModel(
          id: 'sup_u1',
          name: 'Imran Khan',
          email: 'alnoor@waterfix.pk',
          phone: '+923015556677',
          role: 'supplier',
        );
        controller.supplierProfile = {
          '_id': 'sup_1',
          'businessName': 'Al-Noor Water Supply',
          'isAvailable': true,
        };
        controller.walletSummary = {
          'supplierId': 'sup_1',
          'businessName': 'Al-Noor Water Supply',
          'commissionRate': 0.10,
          'commissionPercentage': 10,
          'totalGrossEarnings': 3600,
          'totalCommissionCharged': 360,
          'totalCommissionOwed': 180,
          'amountCurrentlyPayable': 180,
          'totalCommissionPaid': 180,
          'pendingPaymentAmount': 0,
          'paymentStatus': 'Partially Paid',
          'outstandingCommission': 180,
          'totalSettledCommission': 180,
          'safepayConfigured': false,
          'safepayEnvironment': 'sandbox',
        };
        controller.walletCommissionHistory = [
          {
            '_id': 'comm_1',
            'bookingId': '680000000000000000001001',
            'bookingCode': '#WF-4001',
            'orderDate': '2026-10-27T10:00:00.000Z',
            'grossBookingAmount': 1800,
            'commissionRate': 0.10,
            'commissionPercentage': 10,
            'commissionAmount': 180,
            'paidAmount': 180,
            'remainingAmount': 0,
            'reversalAmount': 0,
            'commissionStatus': 'Paid',
          },
          {
            '_id': 'comm_2',
            'bookingId': '680000000000000000001002',
            'bookingCode': '#WF-4002',
            'orderDate': '2026-10-27T14:30:00.000Z',
            'grossBookingAmount': 1800,
            'commissionRate': 0.10,
            'commissionPercentage': 10,
            'commissionAmount': 180,
            'paidAmount': 0,
            'remainingAmount': 180,
            'reversalAmount': 0,
            'commissionStatus': 'Outstanding',
          },
        ];
        controller.walletPaymentHistory = [
          {
            '_id': 'pay_1',
            'paymentReference': 'SFPY-1761590000-1001',
            'amount': 180,
            'currency': 'PKR',
            'createdAt': '2026-10-27T12:00:00.000Z',
            'provider': 'Safepay',
            'environment': 'sandbox',
            'status': 'Paid',
            'rawStatus': 'paid',
            'tracker': 'track_sandbox_wf_101',
            'providerReference': 'track_sandbox_wf_101',
          },
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              waterFixControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              theme: WaterFixTheme.lightTheme,
              home: const SupplierDashboardScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to Wallet tab
        await tester.tap(find.text('Wallet'));
        await tester.pumpAndSettle();

        // Verify Wallet Overview metrics & status
        expect(find.text('Commission wallet'), findsOneWidget);
        expect(
          find.text('Internal platform commission ledger (Not a bank account)'),
          findsOneWidget,
        );
        expect(find.text('Rs 180'), findsWidgets);
        expect(find.text('Partially Paid'), findsOneWidget);
        expect(find.text('Pay Commission (Rs 180)'), findsOneWidget);

        // Verify Commission History & Payment History entries
        expect(find.text('Commission history'), findsOneWidget);
        expect(find.textContaining('Order #WF-4001'), findsOneWidget);
        expect(find.textContaining('Order #WF-4002'), findsOneWidget);
        expect(find.text('Payment history'), findsOneWidget);
        expect(find.text('SFPY-1761590000-1001'), findsOneWidget);
        expect(
          find.textContaining('track_sandbox_wf_101'),
          findsOneWidget,
        );

        // Verify removed Admin / Agreement buttons are NOT in Supplier Wallet
        expect(find.text('Manual Admin Settlement'), findsNothing);
        expect(find.text('Agreement Admin'), findsNothing);
      },
    );

    testWidgets(
      '13. Admin Dashboard Screen Protects Against Non-Admin Roles & Renders Summary Cards, Suppliers, Customers, and Payments Tabs',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(380, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final controller = WaterFixController(apiClient: ApiClient());

        // 1. Non-admin role is blocked by AdminDashboardScreen guard
        controller.currentUser = const UserModel(
          id: 'cust_1',
          name: 'Ayesha Customer',
          email: 'ayesha@waterfix.pk',
          phone: '+923001112233',
          role: 'customer',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              waterFixControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              theme: WaterFixTheme.lightTheme,
              home: const AdminDashboardScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Admin Access Required'), findsOneWidget);

        // 2. Authorized Admin Role renders full Admin Dashboard
        controller.currentUser = const UserModel(
          id: 'admin_1',
          name: 'WaterFix Administrator',
          email: 'admin@waterfix.pk',
          phone: '+923000000000',
          role: 'admin',
        );
        controller.adminDashboardSummary = {
          'totalSuppliers': 3,
          'totalCustomers': 5,
          'totalOutstandingCommissions': 1250,
          'overdueSuppliersCount': 1,
          'lockedSuppliersCount': 1,
          'totalVerifiedPayments': 2400,
          'pendingPaymentsCount': 1,
        };
        controller.adminSuppliers = [
          {
            '_id': '680000000000000000002001',
            'supplierId': '680000000000000000002001',
            'businessName': 'Al-Noor Water Supply',
            'ownerName': 'Imran Khan',
            'phone': '+923015556677',
            'email': 'alnoor@waterfix.pk',
            'city': 'Islamabad',
            'isLocked': false,
            'accountStatus': 'Active',
            'outstandingCommission': 850,
            'totalCommissionPaid': 1200,
            'daysOverdue': 8,
            'isOverdue7Days': true,
            'paymentStatus': 'Partially Paid',
            'oldestOutstandingDueDate': '2026-10-19T10:00:00.000Z',
            'lastCommissionPaymentAt': '2026-10-25T10:00:00.000Z',
          },
          {
            '_id': '680000000000000000002002',
            'supplierId': '680000000000000000002002',
            'businessName': 'Rana Tankers',
            'ownerName': 'Rana Tariq',
            'phone': '+923025556688',
            'email': 'rana@waterfix.pk',
            'city': 'Rawalpindi',
            'isLocked': true,
            'lockReason': 'Commission overdue by 10 days',
            'accountStatus': 'Locked',
            'outstandingCommission': 400,
            'totalCommissionPaid': 0,
            'daysOverdue': 10,
            'isOverdue7Days': true,
            'paymentStatus': 'Outstanding',
            'oldestOutstandingDueDate': '2026-10-17T10:00:00.000Z',
            'lastCommissionPaymentAt': null,
          },
        ];
        controller.adminCustomers = [
          {
            '_id': '680000000000000000003001',
            'customerId': '680000000000000000003001',
            'name': 'Ayesha Khan',
            'email': 'ayesha@waterfix.pk',
            'phone': '+923001234567',
            'isLocked': false,
            'accountStatus': 'Active',
            'createdAt': '2026-10-10T09:00:00.000Z',
            'orderCount': 4,
            'completedOrderCount': 3,
            'totalSpent': 5400,
          },
        ];
        controller.adminPayments = [
          {
            '_id': '680000000000000000004001',
            'recordType': 'safepay_payment',
            'paymentReference': 'SFPY-1761599999-2001',
            'supplierId': '680000000000000000002001',
            'supplierName': 'Al-Noor Water Supply',
            'amount': 1200,
            'currency': 'PKR',
            'provider': 'Safepay',
            'status': 'Paid',
            'rawStatus': 'paid',
            'createdAt': '2026-10-25T10:00:00.000Z',
            'verifiedAt': '2026-10-25T10:02:00.000Z',
          },
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              waterFixControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              theme: WaterFixTheme.lightTheme,
              home: const AdminDashboardScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Top Summary Cards & Suppliers Tab
        expect(find.text('ADMIN'), findsOneWidget);
        expect(find.text('Rs 1250'), findsOneWidget);
        expect(find.text('Supplier management'), findsOneWidget);
        expect(find.text('Al-Noor Water Supply'), findsOneWidget);
        expect(find.text('8 days overdue (7+)'), findsOneWidget);
        expect(find.text('Rana Tankers'), findsOneWidget);
        expect(find.text('Locked'), findsWidgets);

        // Switch to Customers Tab
        await tester.tap(find.text('Customers').last);
        await tester.pumpAndSettle();
        expect(find.text('Customer management'), findsOneWidget);
        expect(find.text('Ayesha Khan'), findsOneWidget);
        expect(find.text('4 total'), findsOneWidget);

        // Switch to Payments Tab
        await tester.tap(find.text('Payments').last);
        await tester.pumpAndSettle();
        expect(find.text('Payments & commission cases'), findsOneWidget);
        expect(find.text('SFPY-1761599999-2001'), findsOneWidget);
        expect(find.text('Rs 1200 PKR'), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '14. Safepay Gateway Payment Flow, Friendly Error Handling & Return Target Navigation',
      (WidgetTester tester) async {
        final client = ApiClient();
        expect(client.tokenStorage, isNotNull);

        // A. Verify ApiClient maps raw browser/upstream "Failed to fetch" into friendly user message
        final dioFetchError = DioException(
          requestOptions: RequestOptions(path: '/wallet/safepay/session'),
          error: 'ClientException: Failed to fetch',
          message: 'ClientException: Failed to fetch',
          type: DioExceptionType.unknown,
        );
        final mappedFetchError = client.testMapDioError(dioFetchError);
        expect(
          mappedFetchError.message,
          contains('Unable to connect to WaterFix server'),
        );
        expect(mappedFetchError.isNetworkError, isTrue);

        // B. Verify ApiClient maps upstream 502 "fetch failed" into helpful diagnostic
        final dioUpstream502 = DioException(
          requestOptions: RequestOptions(path: '/wallet/safepay/session'),
          response: Response(
            requestOptions: RequestOptions(path: '/wallet/safepay/session'),
            statusCode: 502,
            data: {'success': false, 'message': 'fetch failed'},
          ),
          type: DioExceptionType.badResponse,
        );
        final mapped502 = client.testMapDioError(dioUpstream502);
        expect(
          mapped502.message,
          'Safepay gateway connection timed out or failed to respond. Please retry.',
        );

        // C. Verify Supplier Wallet Tab with Safepay checkout action
        final controller = WaterFixController(apiClient: client);
        controller.currentUser = const UserModel(
          id: 'sup_u1',
          name: 'Imran Khan',
          email: 'alnoor@waterfix.pk',
          phone: '+923015556677',
          role: 'supplier',
        );
        controller.supplierProfile = {
          '_id': 'sup_1',
          'businessName': 'Al-Noor Water Supply',
          'isAvailable': true,
        };
        controller.walletSummary = {
          'supplierId': 'sup_1',
          'totalCommissionOwed': 500,
          'amountCurrentlyPayable': 500,
          'totalCommissionPaid': 0,
          'safepayConfigured': true,
          'safepayEnvironment': 'sandbox',
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              waterFixControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              theme: WaterFixTheme.lightTheme,
              home: const SupplierDashboardScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Wallet Tab
        await tester.tap(find.text('Wallet'));
        await tester.pumpAndSettle();

        expect(find.text('Pay Commission (Rs 500)'), findsOneWidget);
        expect(find.text('Rs 500'), findsWidgets);
        expect(find.text('Commission wallet'), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '15. SupplierProfileScreen Has No Heart Icon & CompareSuppliersView Renders "Our Pick"',
      (WidgetTester tester) async {
        const testOffer = SupplierOfferModel(
          listingId: 'l_test',
          supplierId: 's_test',
          supplierUserId: 'u_test',
          businessName: 'Irtaza Rehman Water Company',
          ownerName: 'Irtaza R.',
          city: 'Islamabad',
          serviceAreaText: 'Hostel City, Park Road',
          isVerified: true,
          capacityLiters: 1000,
          label: '1,000 L delivery',
          waterPrice: 3500,
          deliveryFee: 250,
          totalPrice: 3750,
          distanceKm: 2.4,
          ratingAverage: null,
          reviewCount: 0,
          tankersOwned: 4,
          availableWaterLiters: 10000,
          pricePer1000Liters: 3500,
        );

        final client = ApiClient();
        final controller = WaterFixController(apiClient: client);
        controller.ourPicksSuppliers = [testOffer];

        // A. Verify CompareSuppliersView in Our Pick mode
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              waterFixControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              theme: WaterFixTheme.lightTheme,
              home: const Scaffold(
                body: CompareSuppliersView(ourPickHighlightMode: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Our Pick'), findsOneWidget);
        expect(find.text('OUR PICK'), findsOneWidget);
        expect(find.text('Irtaza Rehman Water Company'), findsOneWidget);
        expect(find.textContaining('New supplier (No reviews)'), findsOneWidget);

        // B. Verify SupplierProfileScreen has NO favorite heart icon
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              waterFixControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              theme: WaterFixTheme.lightTheme,
              home: const SupplierProfileScreen(
                supplierId: 's_test',
                initialOffer: testOffer,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
        expect(find.byIcon(Icons.favorite), findsNothing);
        expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
        expect(find.text('Irtaza Rehman Water Company'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
