import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waterfix_mobile/core/utils/validators.dart';
import 'package:waterfix_mobile/features/auth/screens/verify_email_otp_screen.dart';
import 'package:waterfix_mobile/features/auth/screens/pending_approval_screen.dart';
import 'package:waterfix_mobile/features/bookings/screens/confirm_booking_screen.dart';
import 'package:waterfix_mobile/features/suppliers/models/supplier_models.dart';

void main() {
  group('WaterFix Email OTP, CNIC & Admin Approval Flutter Tests', () {
    test('1. CNIC Validator checks length, digits, and formats cleanly', () {
      expect(AppValidators.isValidCnic('35201-1234567-1'), isTrue);
      expect(AppValidators.isValidCnic('3520112345671'), isTrue);
      expect(AppValidators.isValidCnic('35201-123456-1'), isFalse);
      expect(AppValidators.isValidCnic(''), isFalse);
      expect(AppValidators.isValidCnic(null), isFalse);

      expect(
        AppValidators.normalizeCnic('35201-1234567-1'),
        '35201-1234567-1',
      );
      expect(
        AppValidators.normalizeCnic('3520112345671'),
        '35201-1234567-1',
      );

      expect(
        AppValidators.maskCnic('35201-1234567-1'),
        '35201-*******-1',
      );
      expect(
        AppValidators.maskCnic('3520112345671'),
        '35201-*******-1',
      );

      expect(AppValidators.validateCnic(null), isNotNull);
      expect(AppValidators.validateCnic('12345'), isNotNull);
      expect(AppValidators.validateCnic('35201-1234567-1'), isNull);
    });

    testWidgets('2. VerifyEmailOtpScreen renders title, PIN input, and actions',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: VerifyEmailOtpScreen(email: 'test@waterfix.pk'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verify Your Email'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('test@waterfix.pk'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('otp_pin_input')), findsOneWidget);
      expect(find.text('Verify Code'), findsOneWidget);
      expect(find.textContaining('Resend code in'), findsOneWidget);
    });

    testWidgets('3. PendingApprovalScreen renders status and actions',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PendingApprovalScreen(email: 'pending@waterfix.pk'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Awaiting Admin Approval'), findsOneWidget);
      expect(find.text('Check Approval Status'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.text('Email Verified'), findsOneWidget);
      expect(find.text('Yes (Verified)'), findsOneWidget);
    });

    testWidgets('4. ConfirmBookingScreen enforces 500 L to 10,000 L quantity bounds',
        (tester) async {
      final mockOffer = SupplierOfferModel(
        listingId: 'list_123',
        supplierId: 'sup_123',
        supplierUserId: 'usr_123',
        businessName: 'Irtaza Rehman Water Company',
        ownerName: 'Irtaza Rehman',
        city: 'Islamabad',
        serviceAreaText: 'Hostel City, Park Road (Near COMSATS)',
        isVerified: false,
        capacityLiters: 1000,
        label: 'Standard Tanker',
        waterPrice: 3500,
        deliveryFee: 250,
        totalPrice: 3750,
        distanceKm: 2.5,
        pricePer1000Liters: 3500,
        tankersOwned: 4,
        availableWaterLiters: 50000,
        serviceRadiusKm: 20,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ConfirmBookingScreen(offer: mockOffer),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Locate custom quantity field
      final qtyInput = find.byType(TextFormField);
      expect(qtyInput, findsOneWidget);

      // Enter excessive quantity > 10,000 L
      await tester.enterText(qtyInput, '15000');
      await tester.pumpAndSettle();

      expect(find.text('Maximum order quantity is 10,000 L'), findsWidgets);

      // Enter under minimum quantity < 500 L
      await tester.enterText(qtyInput, '200');
      await tester.pumpAndSettle();

      expect(find.text('Minimum order quantity is 500 L'), findsWidgets);

      // Enter valid quantity within bounds (e.g. 2,500 L)
      await tester.enterText(qtyInput, '2500');
      await tester.pumpAndSettle();

      expect(find.text('Maximum order quantity is 10,000 L'), findsNothing);
      expect(find.text('Minimum order quantity is 500 L'), findsNothing);
      expect(find.textContaining('Confirm booking · Rs'), findsOneWidget);
    });
  });
}
