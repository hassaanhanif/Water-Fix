import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/waterfix_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/waterfix_buttons.dart';
import '../../../shared/widgets/waterfix_logo.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedTab = 0; // 0: Suppliers, 1: New suppliers, 2: Customers, 3: New customers, 4: Payments

  final _supplierSearchCtrl = TextEditingController();
  final _pendingSupplierSearchCtrl = TextEditingController();
  final _customerSearchCtrl = TextEditingController();
  final _pendingCustomerSearchCtrl = TextEditingController();
  final _paymentSearchCtrl = TextEditingController();
  final Set<String> _revealedCnics = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final ctrl = ref.read(waterFixControllerProvider);
      if (ctrl.isAdmin) {
        ctrl.refreshAllAdminData();
      }
    });
  }

  @override
  void dispose() {
    _supplierSearchCtrl.dispose();
    _pendingSupplierSearchCtrl.dispose();
    _customerSearchCtrl.dispose();
    _pendingCustomerSearchCtrl.dispose();
    _paymentSearchCtrl.dispose();
    super.dispose();
  }

  String _formatShortDate(dynamic raw) {
    if (raw == null) return '—';
    final str = raw.toString();
    if (str.isEmpty) return '—';
    final dt = DateTime.tryParse(str)?.toLocal();
    if (dt == null) return str;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[dt.month - 1];
    return '$m ${dt.day}, ${dt.year}';
  }

  String _formatDateTime(dynamic raw) {
    if (raw == null) return '—';
    final str = raw.toString();
    if (str.isEmpty) return '—';
    final dt = DateTime.tryParse(str)?.toLocal();
    if (dt == null) return str;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[dt.month - 1];
    final hr = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m ${dt.day}, ${dt.year} · $hr:$min';
  }

  String _shortId(dynamic raw) {
    final s = (raw ?? '').toString();
    if (s.isEmpty) return 'N/A';
    return s.length > 8 ? '#${s.substring(s.length - 8)}' : '#$s';
  }

  Widget _buildAccountStatusBadge(bool isLocked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isLocked
            ? WaterFixColors.coralAlertBg
            : const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLocked ? Icons.lock_rounded : Icons.check_circle_outline_rounded,
            size: 12,
            color: isLocked
                ? WaterFixColors.coralAlertText
                : const Color(0xFF15803D),
          ),
          const SizedBox(width: 4),
          Text(
            isLocked ? 'Locked' : 'Active',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isLocked
                  ? WaterFixColors.coralAlertText
                  : const Color(0xFF15803D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusPill(String status) {
    final lower = status.toLowerCase();
    Color bg;
    Color fg;
    if (lower == 'paid' || lower == 'settled') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (lower == 'partially paid' || lower == 'partially_paid') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    } else if (lower == 'pending') {
      bg = WaterFixColors.skyBlueLight;
      fg = WaterFixColors.deepBrandBlue;
    } else if (lower == 'failed' ||
        lower == 'cancelled' ||
        lower == 'expired' ||
        lower == 'outstanding') {
      bg = WaterFixColors.coralAlertBg;
      fg = WaterFixColors.coralAlertText;
    } else {
      bg = const Color(0xFFEBEBE6);
      fg = WaterFixColors.primaryBlack;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildOverdueBadge(int daysOverdue) {
    if (daysOverdue <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFEBEBE6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          '0 days overdue',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: WaterFixColors.textSecondary,
          ),
        ),
      );
    }

    final isSevere = daysOverdue >= 7;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isSevere
            ? WaterFixColors.coralAlertBg
            : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSevere
              ? WaterFixColors.coralAlertText.withValues(alpha: 0.4)
              : const Color(0xFFB45309).withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        '$daysOverdue ${daysOverdue == 1 ? "day" : "days"} overdue${isSevere ? " (7+)" : ""}',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: isSevere
              ? WaterFixColors.coralAlertText
              : const Color(0xFFB45309),
        ),
      ),
    );
  }

  Future<void> _showLockConfirmationDialog({
    required BuildContext context,
    required WaterFixController controller,
    required String targetType, // 'supplier' | 'customer'
    required String targetId,
    required String targetName,
    required bool lockAccount,
    int? daysOverdue,
    int? outstandingCommission,
    VoidCallback? onUpdated,
  }) async {
    final defaultReason = lockAccount
        ? (targetType == 'supplier'
              ? ((daysOverdue ?? 0) >= 7
                    ? 'Commission overdue by $daysOverdue days (Rs ${outstandingCommission ?? 0} unpaid)'
                    : 'Administrative lock due to unpaid commission / policy compliance')
              : 'Administrative customer account lock')
        : (targetType == 'supplier'
              ? 'Commission settled / account restored by administrator'
              : 'Customer account restored by administrator');

    final reasonCtrl = TextEditingController(text: defaultReason);
    bool isSubmitting = false;
    String? errorMsg;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: WaterFixColors.scaffoldBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(
                lockAccount ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                color: lockAccount
                    ? WaterFixColors.coralAlertText
                    : const Color(0xFF15803D),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lockAccount
                      ? 'Lock ${targetType == "supplier" ? "Supplier" : "Customer"}'
                      : 'Unlock ${targetType == "supplier" ? "Supplier" : "Customer"}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lockAccount
                      ? (targetType == 'supplier'
                            ? 'Locking "$targetName" will block them from accepting new customer bookings, publishing tanker listings, or appearing in customer search. They will still be able to sign in and pay their outstanding commission via Safepay.'
                            : 'Locking "$targetName" will block them from placing new water tanker bookings until unlocked.')
                      : 'Unlocking "$targetName" will immediately restore their account to Active status.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: WaterFixColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'AUDIT REASON (RECORDED IN ADMIN LOG)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: WaterFixColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Enter reason for locking/unlocking...',
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorMsg!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: WaterFixColors.coralAlertText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: lockAccount
                    ? WaterFixColors.coralAlertText
                    : WaterFixColors.primaryBlack,
                foregroundColor: Colors.white,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() {
                        isSubmitting = true;
                        errorMsg = null;
                      });
                      try {
                        if (targetType == 'supplier') {
                          await controller.setSupplierAccountLock(
                            supplierId: targetId,
                            locked: lockAccount,
                            reason: reasonCtrl.text.trim(),
                          );
                        } else {
                          await controller.setCustomerAccountLock(
                            customerId: targetId,
                            locked: lockAccount,
                            reason: reasonCtrl.text.trim(),
                          );
                        }
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        onUpdated?.call();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                lockAccount
                                    ? '$targetName has been locked.'
                                    : '$targetName has been unlocked.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorMsg = e.toString().replaceFirst('Exception: ', '');
                        });
                      }
                    },
              child: Text(
                isSubmitting
                    ? 'Saving...'
                    : (lockAccount ? 'Confirm Lock' : 'Confirm Unlock'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRejectApplicantDialog({
    required BuildContext context,
    required WaterFixController controller,
    required String targetType, // 'supplier' | 'customer'
    required String targetId,
    required String targetName,
  }) async {
    final reasonCtrl = TextEditingController(
      text: 'CNIC or credentials could not be verified by administration',
    );
    bool isSubmitting = false;
    String? errorMsg;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: WaterFixColors.scaffoldBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.cancel_outlined,
                color: WaterFixColors.coralAlertText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reject ${targetType == "supplier" ? "Supplier" : "Customer"}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rejecting "$targetName" will decline their registration. A notification email will be sent with the specified reason.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: WaterFixColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'REJECTION REASON (SENT TO APPLICANT)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: WaterFixColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter reason for rejection...',
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorMsg!,
                    style: const TextStyle(
                      color: WaterFixColors.coralAlertText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: WaterFixColors.coralAlertText,
                foregroundColor: Colors.white,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() {
                        isSubmitting = true;
                        errorMsg = null;
                      });
                      final reason = reasonCtrl.text.trim();
                      bool success = false;
                      if (targetType == 'supplier') {
                        success = await controller.rejectSupplier(targetId, reason);
                      } else {
                        success = await controller.rejectCustomer(targetId, reason);
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? '$targetName registration was rejected.'
                                  : (controller.adminError ?? 'Failed to reject applicant.'),
                            ),
                          ),
                        );
                      }
                    },
              child: Text(isSubmitting ? 'Rejecting...' : 'Confirm Rejection'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupplierDetailSheet(
    BuildContext context,
    WaterFixController controller,
    Map<String, dynamic> initialSupplier,
  ) {
    final supplierId = (initialSupplier['_id'] ?? initialSupplier['supplierId'])
        .toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: WaterFixColors.scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.86,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) {
            return FutureBuilder<Map<String, dynamic>>(
              future: controller.fetchAdminSupplierDetail(supplierId),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 40,
                          color: WaterFixColors.coralAlertText,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load supplier details: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final data = snapshot.data!;
                final sup = Map<String, dynamic>.from(
                  (data['supplier'] as Map?) ?? initialSupplier,
                );
                final commHistory =
                    ((data['commissionHistory'] as List?) ?? const [])
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList();
                final payHistory =
                    ((data['paymentHistory'] as List?) ?? const [])
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList();
                final auditLogs = ((data['auditLogs'] as List?) ?? const [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();

                final bName = (sup['businessName'] ?? 'Supplier').toString();
                final oName = (sup['ownerName'] ?? '').toString();
                final phone = (sup['phone'] ?? '').toString();
                final email = (sup['email'] ?? '').toString();
                final city = (sup['city'] ?? 'Islamabad').toString();
                final isLocked = sup['isLocked'] == true;
                final lockReason = (sup['lockReason'] ?? '').toString();
                final owed = (sup['outstandingCommission'] as num?)?.toInt() ?? 0;
                final paid = (sup['totalCommissionPaid'] as num?)?.toInt() ?? 0;
                final daysOverdue = (sup['daysOverdue'] as num?)?.toInt() ?? 0;
                final payStatus = (sup['paymentStatus'] ?? 'Paid').toString();
                final oldestDue = _formatShortDate(
                  sup['oldestOutstandingDueDate'],
                );
                final lastPaid = _formatShortDate(
                  sup['lastCommissionPaymentAt'],
                );

                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: WaterFixColors.cardBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: WaterFixColors.primaryBlack,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${_shortId(supplierId)} · Owner: $oName',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                              Text(
                                '$phone · $email · $city',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildAccountStatusBadge(isLocked),
                      ],
                    ),
                    if (isLocked && lockReason.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: WaterFixColors.coralAlertBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Lock Reason: $lockReason',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: WaterFixColors.coralAlertText,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLocked
                                  ? WaterFixColors.primaryBlack
                                  : WaterFixColors.coralAlertText,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _showLockConfirmationDialog(
                                context: context,
                                controller: controller,
                                targetType: 'supplier',
                                targetId: supplierId,
                                targetName: bName,
                                lockAccount: !isLocked,
                                daysOverdue: daysOverdue,
                                outstandingCommission: owed,
                              );
                            },
                            icon: Icon(
                              isLocked
                                  ? Icons.lock_open_rounded
                                  : Icons.lock_outline_rounded,
                              size: 18,
                            ),
                            label: Text(
                              isLocked
                                  ? 'Unlock Supplier Account'
                                  : 'Lock Supplier Account',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Commission & Overdue Summary Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: WaterFixColors.primaryBlack,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'COMMISSION & OVERDUE SUMMARY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white70,
                                ),
                              ),
                              _buildPaymentStatusPill(payStatus),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 18,
                            runSpacing: 10,
                            children: [
                              _buildDarkMetric('Outstanding', 'Rs $owed'),
                              _buildDarkMetric('Total Paid', 'Rs $paid'),
                              _buildDarkMetric(
                                'Days Overdue',
                                '$daysOverdue days',
                              ),
                              _buildDarkMetric('Oldest Unpaid Due', oldestDue),
                              _buildDarkMetric('Last Payment', lastPaid),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Commission Ledger History
                    Text(
                      'Commission Ledger (${commHistory.length})',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (commHistory.isEmpty)
                      const Text(
                        'No commission entries recorded for this supplier.',
                        style: TextStyle(color: WaterFixColors.textSecondary),
                      )
                    else
                      ...commHistory.map((item) {
                        final code = (item['bookingCode'] ?? 'N/A').toString();
                        final orderDate = _formatShortDate(item['orderDate']);
                        final dueDate = _formatShortDate(item['dueDate']);
                        final commAmt =
                            (item['commissionAmount'] as num?)?.toInt() ?? 0;
                        final remAmt =
                            (item['remainingAmount'] as num?)?.toInt() ?? 0;
                        final status = (item['commissionStatus'] ?? 'Outstanding')
                            .toString();
                        final itemOverdue =
                            (item['daysOverdue'] as num?)?.toInt() ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: WaterFixColors.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: WaterFixColors.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Order $code · Rs $commAmt',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  _buildPaymentStatusPill(status),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Order Date: $orderDate · Due Date: $dueDate · Remaining: Rs $remAmt',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                              if (remAmt > 0 && itemOverdue > 0) ...[
                                const SizedBox(height: 4),
                                _buildOverdueBadge(itemOverdue),
                              ],
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 18),
                    Text(
                      'Payment History (${payHistory.length})',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (payHistory.isEmpty)
                      const Text(
                        'No commission payments recorded yet.',
                        style: TextStyle(color: WaterFixColors.textSecondary),
                      )
                    else
                      ...payHistory.map((p) {
                        final ref = (p['paymentReference'] ?? '').toString();
                        final amt = (p['amount'] as num?)?.toInt() ?? 0;
                        final st = (p['status'] ?? 'Pending').toString();
                        final prov = (p['provider'] ?? 'Safepay').toString();
                        final created = _formatDateTime(p['createdAt']);
                        final verified = _formatDateTime(p['verifiedAt']);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: WaterFixColors.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: WaterFixColors.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$ref · Rs $amt',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  _buildPaymentStatusPill(st),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Provider: $prov · Created: $created\nVerified: $verified',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 18),
                    Text(
                      'Admin Audit History (${auditLogs.length})',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (auditLogs.isEmpty)
                      const Text(
                        'No lock/unlock administrative actions recorded for this supplier.',
                        style: TextStyle(color: WaterFixColors.textSecondary),
                      )
                    else
                      ...auditLogs.map((log) {
                        final action = (log['action'] ?? '').toString();
                        final adminName = (log['adminName'] ?? 'Admin')
                            .toString();
                        final reason = (log['reason'] ?? '').toString();
                        final date = _formatDateTime(log['createdAt']);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: WaterFixColors.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: WaterFixColors.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${action.toUpperCase()} by $adminName',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Reason: $reason\nTimestamp: $date',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showCustomerDetailSheet(
    BuildContext context,
    WaterFixController controller,
    Map<String, dynamic> initialCustomer,
  ) {
    final customerId = (initialCustomer['_id'] ?? initialCustomer['customerId'])
        .toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: WaterFixColors.scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.5,
          maxChildSize: 0.94,
          builder: (ctx, scrollController) {
            return FutureBuilder<Map<String, dynamic>>(
              future: controller.fetchAdminCustomerDetail(customerId),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Failed to load customer details: ${snapshot.error}',
                    ),
                  );
                }

                final data = snapshot.data!;
                final cust = Map<String, dynamic>.from(
                  (data['customer'] as Map?) ?? initialCustomer,
                );
                final bookings = ((data['bookings'] as List?) ?? const [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
                final auditLogs = ((data['auditLogs'] as List?) ?? const [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();

                final name = (cust['name'] ?? 'Customer').toString();
                final email = (cust['email'] ?? '').toString();
                final phone = (cust['phone'] ?? '').toString();
                final isLocked = cust['isLocked'] == true;
                final lockReason = (cust['lockReason'] ?? '').toString();
                final regDate = _formatShortDate(cust['createdAt']);
                final orderCount =
                    (cust['orderCount'] as num?)?.toInt() ?? bookings.length;
                final totalSpent = (cust['totalSpent'] as num?)?.toInt() ?? 0;

                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: WaterFixColors.cardBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${_shortId(customerId)} · Joined: $regDate',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                              Text(
                                '$phone · $email',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildAccountStatusBadge(isLocked),
                      ],
                    ),
                    if (isLocked && lockReason.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: WaterFixColors.coralAlertBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Lock Reason: $lockReason',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: WaterFixColors.coralAlertText,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLocked
                            ? WaterFixColors.primaryBlack
                            : WaterFixColors.coralAlertText,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showLockConfirmationDialog(
                          context: context,
                          controller: controller,
                          targetType: 'customer',
                          targetId: customerId,
                          targetName: name,
                          lockAccount: !isLocked,
                        );
                      },
                      icon: Icon(
                        isLocked
                            ? Icons.lock_open_rounded
                            : Icons.lock_outline_rounded,
                        size: 18,
                      ),
                      label: Text(
                        isLocked
                            ? 'Unlock Customer Account'
                            : 'Lock Customer Account',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Order History ($orderCount orders · Rs $totalSpent delivered)',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (bookings.isEmpty)
                      const Text(
                        'This customer has not placed any bookings yet.',
                        style: TextStyle(color: WaterFixColors.textSecondary),
                      )
                    else
                      ...bookings.map((b) {
                        final code = (b['bookingCode'] ?? '').toString();
                        final cap = (b['capacityLiters'] as num?)?.toInt() ?? 0;
                        final price = (b['totalPrice'] as num?)?.toInt() ?? 0;
                        final status = (b['status'] ?? 'requested').toString();
                        final supName = (b['supplierBusinessName'] ?? '')
                            .toString();
                        final date = _formatShortDate(b['createdAt']);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: WaterFixColors.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: WaterFixColors.cardBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$code · $cap L · Rs $price',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'Supplier: $supName · $date',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: WaterFixColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildPaymentStatusPill(status.toUpperCase()),
                            ],
                          ),
                        );
                      }),
                    if (auditLogs.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Admin Audit History',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...auditLogs.map((log) {
                        final action = (log['action'] ?? '').toString();
                        final adminName = (log['adminName'] ?? 'Admin')
                            .toString();
                        final reason = (log['reason'] ?? '').toString();
                        final date = _formatDateTime(log['createdAt']);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: WaterFixColors.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: WaterFixColors.cardBorder),
                          ),
                          child: Text(
                            '${action.toUpperCase()} by $adminName — $reason ($date)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showPaymentDetailSheet(
    BuildContext context,
    WaterFixController controller,
    Map<String, dynamic> item,
  ) {
    final recordId = (item['_id'] ?? item['paymentReference']).toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: WaterFixColors.scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (ctx, scrollController) {
            return FutureBuilder<Map<String, dynamic>>(
              future: controller.fetchAdminPaymentDetail(recordId),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Failed to load payment details: ${snapshot.error}',
                    ),
                  );
                }

                final data = snapshot.data!;
                final payment = Map<String, dynamic>.from(
                  (data['payment'] as Map?) ?? item,
                );
                final relatedCommissions =
                    ((data['relatedCommissions'] as List?) ?? const [])
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList();

                final ref = (payment['paymentReference'] ?? '').toString();
                final sName = (payment['supplierName'] ?? 'Supplier')
                    .toString();
                final sId = (payment['supplierId'] ?? '').toString();
                final amt = (payment['amount'] as num?)?.toInt() ?? 0;
                final status = (payment['status'] ?? 'Pending').toString();
                final prov = (payment['provider'] ?? 'Safepay').toString();
                final tracker =
                    (payment['tracker'] ?? payment['providerReference'] ?? '—')
                        .toString();
                final created = _formatDateTime(payment['createdAt']);
                final verified = _formatDateTime(payment['verifiedAt']);
                final notes = (payment['notes'] ?? '').toString();

                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: WaterFixColors.cardBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            ref,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _buildPaymentStatusPill(status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: WaterFixColors.cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: WaterFixColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amount: Rs $amt PKR',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: WaterFixColors.deepBrandBlue,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Supplier: $sName (${_shortId(sId)})'),
                          Text('Provider: $prov'),
                          Text('Provider Tracker / Reference: $tracker'),
                          Text('Created At: $created'),
                          Text('Verified Timestamp: $verified'),
                          if (notes.isNotEmpty) Text('Notes: $notes'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Related Commission Ledger Entries (${relatedCommissions.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (relatedCommissions.isEmpty)
                      const Text(
                        'No related commission charge entries.',
                        style: TextStyle(color: WaterFixColors.textSecondary),
                      )
                    else
                      ...relatedCommissions.map((c) {
                        final code = (c['bookingCode'] ?? 'N/A').toString();
                        final cAmt =
                            (c['commissionAmount'] as num?)?.toInt() ?? 0;
                        final pAmt = (c['paidAmount'] as num?)?.toInt() ?? 0;
                        final due = _formatShortDate(
                          c['dueDate'] ?? c['orderDate'],
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: WaterFixColors.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: WaterFixColors.cardBorder),
                          ),
                          child: Text(
                            'Order $code · Commission: Rs $cAmt · Paid: Rs $pAmt · Due: $due',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDarkMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection(WaterFixController controller) {
    final summary = controller.adminDashboardSummary;
    final totalSuppliers = (summary?['totalSuppliers'] as num?)?.toInt() ?? 0;
    final totalCustomers = (summary?['totalCustomers'] as num?)?.toInt() ?? 0;
    final totalOutstanding =
        (summary?['totalOutstandingCommissions'] as num?)?.toInt() ?? 0;
    final overdue7Count =
        (summary?['overdueSuppliersCount'] as num?)?.toInt() ?? 0;
    final lockedSuppliers =
        (summary?['lockedSuppliersCount'] as num?)?.toInt() ?? 0;
    final verifiedPayments =
        (summary?['totalVerifiedPayments'] as num?)?.toInt() ?? 0;
    final pendingPayments =
        (summary?['pendingPaymentsCount'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.adminError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: WaterFixColors.coralAlertBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: WaterFixColors.coralAlertText,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.adminError!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: WaterFixColors.coralAlertText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: controller.refreshAllAdminData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),

        // Dark Admin Hero Summary Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: WaterFixColors.primaryBlack,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'PLATFORM COMMISSION & ACCOUNT OVERVIEW',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  if (controller.isLoadingAdminDashboard)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: WaterFixColors.skyBlue,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AdminStatTile(
                      label: 'Suppliers',
                      value: '$totalSuppliers',
                      subtitle: '$lockedSuppliers Locked',
                      accentColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AdminStatTile(
                      label: 'Customers',
                      value: '$totalCustomers',
                      subtitle: 'Registered',
                      accentColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AdminStatTile(
                      label: 'Overdue (7+d)',
                      value: '$overdue7Count',
                      subtitle: 'Suppliers',
                      accentColor: overdue7Count > 0
                          ? const Color(0xFFFCA5A5)
                          : WaterFixColors.skyBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _AdminStatTile(
                      label: 'Outstanding Comm.',
                      value: 'Rs $totalOutstanding',
                      subtitle: 'Unpaid total',
                      accentColor: WaterFixColors.skyBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AdminStatTile(
                      label: 'Locked Suppliers',
                      value: '$lockedSuppliers',
                      subtitle: 'Restricted',
                      accentColor: lockedSuppliers > 0
                          ? const Color(0xFFFCA5A5)
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AdminStatTile(
                      label: 'Recent Payments',
                      value: 'Rs $verifiedPayments',
                      subtitle: '$pendingPayments pending',
                      accentColor: const Color(0xFF86EFAC),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuppliersTab(
    BuildContext context,
    WaterFixController controller,
  ) {
    final suppliers = controller.adminSuppliers;
    final currentFilter = controller.adminSupplierFilter;

    const filters = [
      {'key': 'all', 'label': 'All suppliers'},
      {'key': 'active', 'label': 'Active suppliers'},
      {'key': 'locked', 'label': 'Locked suppliers'},
      {'key': 'outstanding', 'label': 'Outstanding commissions'},
      {'key': 'overdue_7_days', 'label': 'Overdue 7+ days'},
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        _buildSummarySection(controller),
        const SizedBox(height: 18),
        const Text(
          'Supplier management',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: WaterFixColors.primaryBlack,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('admin_supplier_search_field'),
          controller: _supplierSearchCtrl,
          onChanged: (v) => controller.fetchAdminSuppliers(search: v),
          decoration: InputDecoration(
            hintText: 'Search supplier name, ID, phone, email, city...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _supplierSearchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _supplierSearchCtrl.clear();
                      controller.fetchAdminSuppliers(search: '');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((f) {
              final key = f['key']!;
              final label = f['label']!;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SelectablePillChip(
                  label: label,
                  isSelected: currentFilter == key,
                  onTap: () => controller.fetchAdminSuppliers(filter: key),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        if (controller.isLoadingAdminSuppliers && suppliers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (suppliers.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: WaterFixColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: WaterFixColors.cardBorder),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 36,
                  color: WaterFixColors.textSecondary,
                ),
                SizedBox(height: 8),
                Text(
                  'No matching suppliers found',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Try clearing your search query or switching filter tabs.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: WaterFixColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ...suppliers.map((s) {
            final id = (s['_id'] ?? s['supplierId']).toString();
            final bName = (s['businessName'] ?? 'Supplier').toString();
            final oName = (s['ownerName'] ?? '').toString();
            final phone = (s['phone'] ?? '').toString();
            final email = (s['email'] ?? '').toString();
            final city = (s['city'] ?? 'Islamabad').toString();
            final isLocked = s['isLocked'] == true;
            final lockReason = (s['lockReason'] ?? '').toString();
            final owed = (s['outstandingCommission'] as num?)?.toInt() ?? 0;
            final paid = (s['totalCommissionPaid'] as num?)?.toInt() ?? 0;
            final daysOverdue = (s['daysOverdue'] as num?)?.toInt() ?? 0;
            final payStatus = (s['paymentStatus'] ?? 'Paid').toString();
            final oldestDue = _formatShortDate(s['oldestOutstandingDueDate']);
            final lastPaid = _formatShortDate(s['lastCommissionPaymentAt']);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => _showSupplierDetailSheet(context, controller, s),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: WaterFixColors.cardBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isLocked
                          ? WaterFixColors.coralAlertText.withValues(alpha: 0.4)
                          : WaterFixColors.cardBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: WaterFixColors.primaryBlack,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ID: ${_shortId(id)} · $oName · $city',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: WaterFixColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '$phone · $email',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: WaterFixColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildAccountStatusBadge(isLocked),
                              const SizedBox(height: 4),
                              _buildPaymentStatusPill(payStatus),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          _buildInfoPair('Outstanding', 'Rs $owed'),
                          _buildInfoPair('Total Paid', 'Rs $paid'),
                          _buildInfoPair('Oldest Due Date', oldestDue),
                          _buildInfoPair('Last Payment', lastPaid),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildOverdueBadge(daysOverdue),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _showSupplierDetailSheet(
                                  context,
                                  controller,
                                  s,
                                ),
                                child: const Text(
                                  'Details',
                                  style: TextStyle(fontSize: 12.5),
                                ),
                              ),
                              const SizedBox(width: 4),
                              OutlinedButton.icon(
                                key: Key('supplier_lock_btn_$id'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isLocked
                                      ? WaterFixColors.primaryBlack
                                      : WaterFixColors.coralAlertText,
                                  side: BorderSide(
                                    color: isLocked
                                        ? WaterFixColors.primaryBlack
                                        : WaterFixColors.coralAlertText,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                ),
                                onPressed: () => _showLockConfirmationDialog(
                                  context: context,
                                  controller: controller,
                                  targetType: 'supplier',
                                  targetId: id,
                                  targetName: bName,
                                  lockAccount: !isLocked,
                                  daysOverdue: daysOverdue,
                                  outstandingCommission: owed,
                                ),
                                icon: Icon(
                                  isLocked
                                      ? Icons.lock_open_rounded
                                      : Icons.lock_outline_rounded,
                                  size: 15,
                                ),
                                label: Text(
                                  isLocked ? 'Unlock' : 'Lock',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (isLocked && lockReason.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Locked: $lockReason',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: WaterFixColors.coralAlertText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPendingSuppliersTab(
    BuildContext context,
    WaterFixController controller,
  ) {
    final pending = controller.adminPendingSuppliers;
    final isLoading = controller.isLoadingAdminPendingSuppliers;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'New suppliers',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: WaterFixColors.primaryBlack,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F4C81).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${pending.length} awaiting review',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F4C81),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Suppliers with verified email awaiting CNIC review and fleet verification.',
          style: TextStyle(
            fontSize: 13,
            color: WaterFixColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _pendingSupplierSearchCtrl,
          onChanged: (v) => controller.fetchAdminPendingSuppliers(v),
          decoration: InputDecoration(
            hintText: 'Search pending supplier name, CNIC, phone, email...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _pendingSupplierSearchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _pendingSupplierSearchCtrl.clear();
                      controller.fetchAdminPendingSuppliers('');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        if (isLoading && pending.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (pending.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: WaterFixColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: WaterFixColors.cardBorder),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 40,
                  color: Color(0xFF16A34A),
                ),
                SizedBox(height: 10),
                Text(
                  'No pending supplier registrations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'All supplier applications have been reviewed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: WaterFixColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ...pending.map((s) {
            final id = (s['_id'] ?? s['supplierId']).toString();
            final bName = (s['businessName'] ?? 'Supplier').toString();
            final oName = (s['ownerName'] ?? '').toString();
            final phone = (s['phone'] ?? '').toString();
            final email = (s['email'] ?? '').toString();
            final city = (s['city'] ?? 'Islamabad').toString();
            final area = (s['serviceAreaText'] ?? '').toString();
            final cnicRaw = (s['cnicNumber'] ?? '').toString();
            final cnicMasked = (s['cnicMasked'] ?? '').toString();
            final isRevealed = _revealedCnics.contains(id);
            final displayCnic = isRevealed ? cnicRaw : (cnicMasked.isNotEmpty ? cnicMasked : cnicRaw);
            final fleet = (s['tankerFleetSize'] as num?)?.toInt() ?? 1;
            final price = (s['pricePer1000Liters'] as num?)?.toInt() ?? 0;
            final radius = (s['deliveryRadiusKm'] as num?)?.toInt() ?? 0;
            final appliedDate = _formatDateTime(s['createdAt']);

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WaterFixColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: WaterFixColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bName,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: WaterFixColors.primaryBlack,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Owner: $oName · Applied: $appliedDate',
                              style: const TextStyle(
                                fontSize: 12,
                                color: WaterFixColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Pending CNIC',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // CNIC Inspection Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          size: 18,
                          color: Color(0xFF0F4C81),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PAKISTANI CNIC',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                              Text(
                                displayCnic,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: WaterFixColors.primaryBlack,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: isRevealed ? 'Hide CNIC' : 'View full CNIC',
                          icon: Icon(
                            isRevealed
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: const Color(0xFF0F4C81),
                          ),
                          onPressed: () {
                            setState(() {
                              if (isRevealed) {
                                _revealedCnics.remove(id);
                              } else {
                                _revealedCnics.add(id);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Details wrap
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _buildApplicantChip(Icons.phone_outlined, phone),
                      _buildApplicantChip(Icons.email_outlined, email),
                      _buildApplicantChip(Icons.location_on_outlined, area.isNotEmpty ? area : city),
                      _buildApplicantChip(Icons.local_shipping_outlined, '$fleet tankers'),
                      _buildApplicantChip(Icons.water_drop_outlined, 'Rs $price/1000L'),
                      _buildApplicantChip(Icons.radar_outlined, '$radius km radius'),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            final ok = await controller.approveSupplier(id);
                            if (context.mounted && ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Supplier "$bName" has been approved.'),
                                  backgroundColor: const Color(0xFF16A34A),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: const Text(
                            'Approve Supplier',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEE2E2),
                          foregroundColor: const Color(0xFFDC2626),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _showRejectApplicantDialog(
                          context: context,
                          controller: controller,
                          targetType: 'supplier',
                          targetId: id,
                          targetName: bName,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text(
                          'Reject',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCustomersTab(
    BuildContext context,
    WaterFixController controller,
  ) {
    final customers = controller.adminCustomers;
    final currentFilter = controller.adminCustomerFilter;

    const filters = [
      {'key': 'all', 'label': 'All customers'},
      {'key': 'active', 'label': 'Active customers'},
      {'key': 'locked', 'label': 'Locked customers'},
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        _buildSummarySection(controller),
        const SizedBox(height: 18),
        const Text(
          'Customer management',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: WaterFixColors.primaryBlack,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('admin_customer_search_field'),
          controller: _customerSearchCtrl,
          onChanged: (v) => controller.fetchAdminCustomers(search: v),
          decoration: InputDecoration(
            hintText: 'Search customer name, ID, phone, email...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _customerSearchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _customerSearchCtrl.clear();
                      controller.fetchAdminCustomers(search: '');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((f) {
              final key = f['key']!;
              final label = f['label']!;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SelectablePillChip(
                  label: label,
                  isSelected: currentFilter == key,
                  onTap: () => controller.fetchAdminCustomers(filter: key),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        if (controller.isLoadingAdminCustomers && customers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (customers.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: WaterFixColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: WaterFixColors.cardBorder),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.people_outline_rounded,
                  size: 36,
                  color: WaterFixColors.textSecondary,
                ),
                SizedBox(height: 8),
                Text(
                  'No matching customers found',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          )
        else
          ...customers.map((c) {
            final id = (c['_id'] ?? c['customerId']).toString();
            final name = (c['name'] ?? 'Customer').toString();
            final email = (c['email'] ?? '').toString();
            final phone = (c['phone'] ?? '').toString();
            final isLocked = c['isLocked'] == true;
            final lockReason = (c['lockReason'] ?? '').toString();
            final regDate = _formatShortDate(c['createdAt']);
            final orderCount = (c['orderCount'] as num?)?.toInt() ?? 0;
            final completedCount =
                (c['completedOrderCount'] as num?)?.toInt() ?? 0;
            final totalSpent = (c['totalSpent'] as num?)?.toInt() ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => _showCustomerDetailSheet(context, controller, c),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: WaterFixColors.cardBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isLocked
                          ? WaterFixColors.coralAlertText.withValues(alpha: 0.4)
                          : WaterFixColors.cardBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ID: ${_shortId(id)} · Joined: $regDate',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: WaterFixColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '$phone · $email',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: WaterFixColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildAccountStatusBadge(isLocked),
                        ],
                      ),
                      const Divider(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Wrap(
                            spacing: 14,
                            runSpacing: 6,
                            children: [
                              _buildInfoPair('Orders', '$orderCount total'),
                              _buildInfoPair(
                                'Delivered',
                                '$completedCount (Rs $totalSpent)',
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _showCustomerDetailSheet(
                                  context,
                                  controller,
                                  c,
                                ),
                                child: const Text('History'),
                              ),
                              OutlinedButton.icon(
                                key: Key('customer_lock_btn_$id'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isLocked
                                      ? WaterFixColors.primaryBlack
                                      : WaterFixColors.coralAlertText,
                                  side: BorderSide(
                                    color: isLocked
                                        ? WaterFixColors.primaryBlack
                                        : WaterFixColors.coralAlertText,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                ),
                                onPressed: () => _showLockConfirmationDialog(
                                  context: context,
                                  controller: controller,
                                  targetType: 'customer',
                                  targetId: id,
                                  targetName: name,
                                  lockAccount: !isLocked,
                                ),
                                icon: Icon(
                                  isLocked
                                      ? Icons.lock_open_rounded
                                      : Icons.lock_outline_rounded,
                                  size: 15,
                                ),
                                label: Text(
                                  isLocked ? 'Unlock' : 'Lock',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (isLocked && lockReason.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Locked: $lockReason',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: WaterFixColors.coralAlertText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPendingCustomersTab(
    BuildContext context,
    WaterFixController controller,
  ) {
    final pending = controller.adminPendingCustomers;
    final isLoading = controller.isLoadingAdminPendingCustomers;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'New customers',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: WaterFixColors.primaryBlack,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F4C81).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${pending.length} awaiting review',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F4C81),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Customer accounts with verified email awaiting CNIC approval before placing orders.',
          style: TextStyle(
            fontSize: 13,
            color: WaterFixColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _pendingCustomerSearchCtrl,
          onChanged: (v) => controller.fetchAdminPendingCustomers(v),
          decoration: InputDecoration(
            hintText: 'Search pending customer name, CNIC, phone, email...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _pendingCustomerSearchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _pendingCustomerSearchCtrl.clear();
                      controller.fetchAdminPendingCustomers('');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        if (isLoading && pending.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (pending.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: WaterFixColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: WaterFixColors.cardBorder),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 40,
                  color: Color(0xFF16A34A),
                ),
                SizedBox(height: 10),
                Text(
                  'No pending customer registrations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'All customer applications have been reviewed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: WaterFixColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ...pending.map((c) {
            final id = (c['_id'] ?? c['customerId']).toString();
            final name = (c['name'] ?? 'Customer').toString();
            final phone = (c['phone'] ?? '').toString();
            final email = (c['email'] ?? '').toString();
            final category = (c['customerCategory'] ?? 'Household').toString();
            final cnicRaw = (c['cnicNumber'] ?? '').toString();
            final cnicMasked = (c['cnicMasked'] ?? '').toString();
            final isRevealed = _revealedCnics.contains(id);
            final displayCnic = isRevealed ? cnicRaw : (cnicMasked.isNotEmpty ? cnicMasked : cnicRaw);
            final appliedDate = _formatDateTime(c['createdAt']);

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WaterFixColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: WaterFixColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: WaterFixColors.primaryBlack,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Category: $category · Applied: $appliedDate',
                              style: const TextStyle(
                                fontSize: 12,
                                color: WaterFixColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Pending CNIC',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // CNIC Inspection Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          size: 18,
                          color: Color(0xFF0F4C81),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PAKISTANI CNIC',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                              Text(
                                displayCnic,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: WaterFixColors.primaryBlack,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: isRevealed ? 'Hide CNIC' : 'View full CNIC',
                          icon: Icon(
                            isRevealed
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: const Color(0xFF0F4C81),
                          ),
                          onPressed: () {
                            setState(() {
                              if (isRevealed) {
                                _revealedCnics.remove(id);
                              } else {
                                _revealedCnics.add(id);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Details wrap
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _buildApplicantChip(Icons.phone_outlined, phone),
                      _buildApplicantChip(Icons.email_outlined, email),
                      _buildApplicantChip(Icons.category_outlined, category),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            final ok = await controller.approveCustomer(id);
                            if (context.mounted && ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Customer "$name" has been approved.'),
                                  backgroundColor: const Color(0xFF16A34A),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: const Text(
                            'Approve Customer',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEE2E2),
                          foregroundColor: const Color(0xFFDC2626),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _showRejectApplicantDialog(
                          context: context,
                          controller: controller,
                          targetType: 'customer',
                          targetId: id,
                          targetName: name,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text(
                          'Reject',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildApplicantChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: WaterFixColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: WaterFixColors.primaryBlack,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentsTab(
    BuildContext context,
    WaterFixController controller,
  ) {
    final items = controller.adminPayments;
    final currentFilter = controller.adminPaymentFilter;

    const filters = [
      {'key': 'all', 'label': 'All payments'},
      {'key': 'pending', 'label': 'Pending verification'},
      {'key': 'paid', 'label': 'Successful payments'},
      {'key': 'failed', 'label': 'Failed payments'},
      {'key': 'outstanding_commissions', 'label': 'Outstanding commissions'},
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        _buildSummarySection(controller),
        const SizedBox(height: 18),
        const Text(
          'Payments & commission cases',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: WaterFixColors.primaryBlack,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('admin_payment_search_field'),
          controller: _paymentSearchCtrl,
          onChanged: (v) => controller.fetchAdminPayments(search: v),
          decoration: InputDecoration(
            hintText: 'Search reference, tracker, supplier name...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _paymentSearchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _paymentSearchCtrl.clear();
                      controller.fetchAdminPayments(search: '');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((f) {
              final key = f['key']!;
              final label = f['label']!;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SelectablePillChip(
                  label: label,
                  isSelected: currentFilter == key,
                  onTap: () => controller.fetchAdminPayments(filter: key),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        if (controller.isLoadingAdminPayments && items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: WaterFixColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: WaterFixColors.cardBorder),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 36,
                  color: WaterFixColors.textSecondary,
                ),
                SizedBox(height: 8),
                Text(
                  'No payment or commission records found',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          )
        else
          ...items.map((item) {
            final recordType = (item['recordType'] ?? 'safepay_payment')
                .toString();
            final ref = (item['paymentReference'] ?? '').toString();
            final sName = (item['supplierName'] ?? 'Supplier').toString();
            final sId = (item['supplierId'] ?? '').toString();
            final amt = (item['amount'] as num?)?.toInt() ?? 0;
            final status = (item['status'] ?? 'Pending').toString();
            final prov = (item['provider'] ?? 'Safepay').toString();
            final created = _formatDateTime(item['createdAt']);
            final verified = _formatDateTime(item['verifiedAt']);
            final daysOverdue = (item['daysOverdue'] as num?)?.toInt() ?? 0;
            final dueDate = _formatShortDate(item['dueDate']);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _showPaymentDetailSheet(context, controller, item),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: WaterFixColors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: WaterFixColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              ref,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _buildPaymentStatusPill(status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Supplier: $sName (${_shortId(sId)})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _buildInfoPair('Amount', 'Rs $amt PKR'),
                          _buildInfoPair('Provider', prov),
                          _buildInfoPair('Created', created),
                          if (recordType == 'outstanding_commission')
                            _buildInfoPair('Due Date', dueDate)
                          else
                            _buildInfoPair('Verified', verified),
                        ],
                      ),
                      if (recordType == 'outstanding_commission') ...[
                        const SizedBox(height: 8),
                        _buildOverdueBadge(daysOverdue),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildInfoPair(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: WaterFixColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: WaterFixColors.primaryBlack,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(waterFixControllerProvider);

    // Client-side route guard in addition to server-side `authorizeRoles('admin')`
    if (!controller.isAdmin) {
      return Scaffold(
        backgroundColor: WaterFixColors.scaffoldBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.gpp_bad_outlined,
                  size: 56,
                  color: WaterFixColors.coralAlertText,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Admin Access Required',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your account does not have administrator privileges.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: WaterFixColors.textSecondary),
                ),
                const SizedBox(height: 16),
                PrimaryArrowButton(
                  label: 'Sign out',
                  onPressed: controller.logout,
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget activeBody;
    switch (_selectedTab) {
      case 0:
        activeBody = KeyedSubtree(
          key: const ValueKey('admin_tab_suppliers'),
          child: _buildSuppliersTab(context, controller),
        );
        break;
      case 1:
        activeBody = KeyedSubtree(
          key: const ValueKey('admin_tab_pending_suppliers'),
          child: _buildPendingSuppliersTab(context, controller),
        );
        break;
      case 2:
        activeBody = KeyedSubtree(
          key: const ValueKey('admin_tab_customers'),
          child: _buildCustomersTab(context, controller),
        );
        break;
      case 3:
        activeBody = KeyedSubtree(
          key: const ValueKey('admin_tab_pending_customers'),
          child: _buildPendingCustomersTab(context, controller),
        );
        break;
      case 4:
      default:
        activeBody = KeyedSubtree(
          key: const ValueKey('admin_tab_payments'),
          child: _buildPaymentsTab(context, controller),
        );
        break;
    }

    return Scaffold(
      backgroundColor: WaterFixColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Admin Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const WaterFixLogo(fontSize: 24),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: WaterFixColors.primaryBlack,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: WaterFixColors.skyBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Refresh Admin Dashboard',
                        onPressed: controller.refreshAllAdminData,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      TextButton.icon(
                        onPressed: controller.logout,
                        icon: const Icon(
                          Icons.logout_rounded,
                          size: 16,
                          color: WaterFixColors.coralAlertText,
                        ),
                        label: const Text(
                          'Sign out',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: WaterFixColors.coralAlertText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: activeBody,
              ),
            ),

            // Admin Bottom Navigation Bar (Suppliers, New suppliers, Customers, New customers, Payments)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: WaterFixColors.cardBg,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: WaterFixColors.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _AdminNavTab(
                    icon: Icons.local_shipping_outlined,
                    label: 'Suppliers',
                    isSelected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                  _AdminNavTab(
                    icon: Icons.person_add_alt_1_outlined,
                    label: 'New suppliers',
                    badgeCount: controller.adminPendingSuppliers.length,
                    isSelected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                  _AdminNavTab(
                    icon: Icons.people_outline_rounded,
                    label: 'Customers',
                    isSelected: _selectedTab == 2,
                    onTap: () => setState(() => _selectedTab = 2),
                  ),
                  _AdminNavTab(
                    icon: Icons.how_to_reg_outlined,
                    label: 'New customers',
                    badgeCount: controller.adminPendingCustomers.length,
                    isSelected: _selectedTab == 3,
                    onTap: () => setState(() => _selectedTab = 3),
                  ),
                  _AdminNavTab(
                    icon: Icons.payments_outlined,
                    label: 'Payments',
                    isSelected: _selectedTab == 4,
                    onTap: () => setState(() => _selectedTab = 4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color accentColor;

  const _AdminStatTile({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: WaterFixColors.darkMetricCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  const _AdminNavTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? WaterFixColors.skyBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 21, color: WaterFixColors.primaryBlack),
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
