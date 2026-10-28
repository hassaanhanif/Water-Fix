import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/state/waterfix_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/waterfix_animations.dart';
import '../../../shared/widgets/waterfix_buttons.dart';
import '../../notifications/screens/notifications_screen.dart';

class CustomerAccountView extends ConsumerWidget {
  const CustomerAccountView({super.key});

  void _showEditProfileDialog(
    BuildContext context,
    WaterFixController controller,
  ) {
    final user = controller.currentUser;
    if (user == null) return;
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone (+92)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await controller.updateCustomerProfile(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSavedAddressesSheet(
    BuildContext context,
    WaterFixController controller,
  ) {
    final addressCtrl = TextEditingController();
    final labelCtrl = TextEditingController(text: 'Home');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: WaterFixColors.scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saved addresses',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (controller.savedAddresses.isEmpty)
              const Text('No saved addresses yet.')
            else
              ...controller.savedAddresses.map(
                (a) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(a.addressLine),
                  subtitle: Text('${a.label} · ${a.city}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      await controller.deleteAddress(a.id);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
                ),
              ),
            const Divider(),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Label (Home / Site)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(
                labelText: 'New address (e.g. Street 7, F-10/3, Islamabad)',
              ),
            ),
            const SizedBox(height: 14),
            SkyBlueButton(
              label: 'Add address',
              onPressed: () async {
                if (addressCtrl.text.trim().isEmpty) return;
                await controller.setManualLocation(
                  addressLine: addressCtrl.text.trim(),
                  saveToAccount: true,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpAndSupportDialog(
    BuildContext context,
    WaterFixController controller,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.headset_mic_outlined, color: WaterFixColors.primaryBlack),
            SizedBox(width: 10),
            Text(
              'Help & Support',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact the WaterFix assistance team for instant support regarding your orders or questions:',
              style: TextStyle(fontSize: 13.5, color: WaterFixColors.textSecondary),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final uri = Uri.parse('mailto:realhassaanhanif@gmail.com');
                try {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    await Clipboard.setData(
                      const ClipboardData(text: 'realhassaanhanif@gmail.com'),
                    );
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Email copied to clipboard: realhassaanhanif@gmail.com',
                          ),
                        ),
                      );
                    }
                  }
                } catch (_) {
                  await Clipboard.setData(
                    const ClipboardData(text: 'realhassaanhanif@gmail.com'),
                  );
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Email copied to clipboard: realhassaanhanif@gmail.com',
                        ),
                      ),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WaterFixColors.pastelBlueCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      color: WaterFixColors.primaryBlack,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EMAIL SUPPORT',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: WaterFixColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'realhassaanhanif@gmail.com',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: WaterFixColors.primaryBlack,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: WaterFixColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final uri = Uri.parse('tel:03026008411');
                try {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    await Clipboard.setData(
                      const ClipboardData(text: '03026008411'),
                    );
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Phone number copied to clipboard: 03026008411',
                          ),
                        ),
                      );
                    }
                  }
                } catch (_) {
                  await Clipboard.setData(
                    const ClipboardData(text: '03026008411'),
                  );
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Phone number copied to clipboard: 03026008411',
                        ),
                      ),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WaterFixColors.pastelSageCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      color: WaterFixColors.primaryBlack,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PHONE / CALL',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: WaterFixColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '03026008411',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: WaterFixColors.primaryBlack,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.call_made_rounded,
                      size: 18,
                      color: WaterFixColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showBackendConfigDialog(context, controller);
                },
                child: const Text(
                  'Configure Backend Server URL',
                  style: TextStyle(
                    fontSize: 12,
                    color: WaterFixColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBackendConfigDialog(
    BuildContext context,
    WaterFixController controller,
  ) {
    final urlCtrl = TextEditingController(text: AppConfig.apiBaseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend Server URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emulator default: http://10.0.2.2:5000/api\nFor a physical phone on Wi-Fi, enter your laptop LAN IP (e.g. http://192.168.18.131:5000/api):',
              style: TextStyle(
                fontSize: 12.5,
                color: WaterFixColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                hintText: 'http://192.168.18.131:5000/api',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await AppConfig.setCustomBaseUrl(null);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Reset default'),
          ),
          ElevatedButton(
            onPressed: () async {
              await AppConfig.setCustomBaseUrl(urlCtrl.text.trim());
              if (ctx.mounted) Navigator.of(ctx).pop();
              controller.discoverSuppliers();
            },
            child: const Text('Save URL'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(waterFixControllerProvider);
    final user = controller.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: WaterFixColors.primaryBlack,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 18),

          // Profile Card matching Screen 13 · Account
          AnimatedSectionEntrance(
            delay: const Duration(milliseconds: 40),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: WaterFixColors.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: WaterFixColors.cardBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: WaterFixColors.skyBlue,
                    child: Text(
                      user?.initials ?? 'AK',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: WaterFixColors.primaryBlack,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Ayesha Khan',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: WaterFixColors.primaryBlack,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.phone ?? '+92 300 0000000',
                          style: const TextStyle(
                            fontSize: 14,
                            color: WaterFixColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SquareIconButton(
                    icon: Icons.edit_outlined,
                    onTap: () => _showEditProfileDialog(context, controller),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Dark Site/Business Promo Card matching Screen 13 · Account
          AnimatedSectionEntrance(
            delay: const Duration(milliseconds: 80),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: WaterFixColors.primaryBlack,
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 125,
                      height: 125,
                      decoration: BoxDecoration(
                        color: WaterFixColors.skyBlue,
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Booking for a site or\nbusiness?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Get bulk and recurring water supply.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SkyBlueButton(
                          label: 'Explore tankers',
                          fullWidth: false,
                          height: 42,
                          onPressed: () {
                            controller.discoverSuppliers();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Browsing verified bulk and commercial suppliers in Islamabad.',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Menu List Card matching Screen 13 · Account
          AnimatedSectionEntrance(
            delay: const Duration(milliseconds: 120),
            child: Container(
              decoration: BoxDecoration(
                color: WaterFixColors.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: WaterFixColors.cardBorder),
              ),
              child: Column(
                children: [
                  _AccountMenuRow(
                    label: 'Saved addresses',
                    onTap: () => _showSavedAddressesSheet(context, controller),
                  ),
                  const Divider(height: 1, color: WaterFixColors.cardBorder),
                  _AccountMenuRow(
                    label: 'Payment methods',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Active payment method: Cash on Delivery (direct payment to supplier).',
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: WaterFixColors.cardBorder),
                  _AccountMenuRow(
                    label: 'Notifications',
                    onTap: () {
                      Navigator.of(context).push(
                        WaterFixPageRoute(page: const NotificationsScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1, color: WaterFixColors.cardBorder),
                  _AccountMenuRow(
                    label: 'Help and support',
                    onTap: () => _showHelpAndSupportDialog(context, controller),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          Center(
            child: TextButton(
              onPressed: () => controller.logout(),
              child: const Text(
                'Log out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: WaterFixColors.coralAlertText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountMenuRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AccountMenuRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: WaterFixColors.primaryBlack,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: WaterFixColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
