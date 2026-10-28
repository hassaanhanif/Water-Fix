import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/location/islamabad_localities.dart';
import '../../../core/state/waterfix_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/waterfix_animations.dart';
import '../../../shared/widgets/waterfix_buttons.dart';
import '../../../shared/widgets/waterfix_logo.dart';
import 'verify_email_otp_screen.dart';
import 'pending_approval_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final bool initialIsSignUp;

  const AuthScreen({super.key, this.initialIsSignUp = false});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  late bool _isSignUp;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Sign in single identifier (email or phone)
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  // Sign up fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cnicController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = 'customer'; // 'customer' | 'supplier' | 'admin'

  // Supplier onboarding fields
  final _businessNameController = TextEditingController();
  final _serviceAreaController = TextEditingController(
    text: 'Hostel City, Park Road (Near COMSATS)',
  );
  final _serviceRadiusController = TextEditingController(text: '15');
  final _tankersOwnedController = TextEditingController(text: '2');
  final _availableWaterController = TextEditingController(text: '10000');
  final _pricePer1000Controller = TextEditingController(text: '1800');
  double _supplierLat = 33.6515;
  double _supplierLng = 73.1566;
  final _initialPrice2000Controller = TextEditingController(text: '1550');
  final bool _publishInitial2000L = false;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cnicController.dispose();
    _confirmPasswordController.dispose();
    _businessNameController.dispose();
    _serviceAreaController.dispose();
    _serviceRadiusController.dispose();
    _tankersOwnedController.dispose();
    _availableWaterController.dispose();
    _pricePer1000Controller.dispose();
    _initialPrice2000Controller.dispose();
    super.dispose();
  }

  void _pickIslamabadLocality() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: WaterFixColors.scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = kIslamabadLocalities.where((loc) {
              if (filter.isEmpty) return true;
              return loc.name.toLowerCase().contains(filter.toLowerCase()) ||
                  loc.sector.toLowerCase().contains(filter.toLowerCase());
            }).toList();

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SizedBox(
                height: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Islamabad Locality',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: WaterFixColors.primaryBlack,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (val) => setModalState(() => filter = val),
                      decoration: const InputDecoration(
                        hintText:
                            'Search sector or area (e.g. Hostel City, F-10, G-11)...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final loc = filtered[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.location_on_outlined,
                              color: WaterFixColors.primaryBlack,
                            ),
                            title: Text(
                              loc.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'Sector: ${loc.sector} · Lat: ${loc.lat}, Lng: ${loc.lng}',
                            ),
                            onTap: () {
                              setState(() {
                                _serviceAreaController.text = loc.name;
                                _supplierLat = loc.lat;
                                _supplierLng = loc.lng;
                              });
                              Navigator.of(ctx).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(waterFixControllerProvider);
    bool success = false;

    if (!_isSignUp) {
      success = await controller.login(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
      );
    } else {
      List<Map<String, dynamic>>? initialListings;
      if (_selectedRole == 'supplier' && _publishInitial2000L) {
        final wPrice =
            int.tryParse(_initialPrice2000Controller.text.trim()) ?? 1550;
        initialListings = [
          {
            'capacityLiters': 2000,
            'label': 'Most homes',
            'waterPrice': wPrice,
            'deliveryFee': 250,
            'estimatedArrivalMinutesMin': 35,
            'estimatedArrivalMinutesMax': 45,
          },
        ];
      }

      success = await controller.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        cnic: _cnicController.text.trim(),
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
        role: _selectedRole == 'admin' ? 'customer' : _selectedRole,
        businessName: _selectedRole == 'supplier'
            ? _businessNameController.text.trim()
            : null,
        serviceAreaText: _selectedRole == 'supplier'
            ? _serviceAreaController.text.trim()
            : null,
        serviceRadiusKm: _selectedRole == 'supplier'
            ? (int.tryParse(_serviceRadiusController.text.trim()) ?? 15)
            : null,
        tankersOwned: _selectedRole == 'supplier'
            ? (int.tryParse(_tankersOwnedController.text.trim()) ?? 1)
            : null,
        availableWaterLiters: _selectedRole == 'supplier'
            ? (int.tryParse(_availableWaterController.text.trim()) ?? 10000)
            : null,
        pricePer1000Liters: _selectedRole == 'supplier'
            ? (int.tryParse(_pricePer1000Controller.text.trim()) ?? 1800)
            : null,
        lat: _selectedRole == 'supplier' ? _supplierLat : null,
        lng: _selectedRole == 'supplier' ? _supplierLng : null,
        initialListings: initialListings,
      );
    }

    if (!mounted) return;
    if (success) {
      if (_isSignUp) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerifyEmailOtpScreen(
              email: _emailController.text.trim(),
            ),
          ),
        );
      } else if (controller.currentUser?.emailVerified == false) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerifyEmailOtpScreen(
              email: controller.currentUser!.email,
            ),
          ),
        );
      } else if (controller.currentUser?.isPendingApproval == true ||
          controller.currentUser?.isRejected == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PendingApprovalScreen(
              email: controller.currentUser!.email,
            ),
          ),
        );
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else if (controller.lastAuthErrorCode == 'EMAIL_NOT_VERIFIED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your email address before signing in.'),
          backgroundColor: WaterFixColors.coralAlertText,
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerifyEmailOtpScreen(
            email: _emailController.text.trim(),
          ),
        ),
      );
    } else if (controller.authError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.authError!),
          backgroundColor: WaterFixColors.coralAlertText,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(waterFixControllerProvider);

    return Scaffold(
      backgroundColor: WaterFixColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Form(
            key: _formKey,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (Navigator.of(context).canPop())
                    SquareIconButton(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  const SizedBox(height: 20),
                  const AnimatedSectionEntrance(
                    delayMs: 40,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome to',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: WaterFixColors.primaryBlack,
                            height: 1.1,
                            letterSpacing: -0.8,
                          ),
                        ),
                        SizedBox(height: 4),
                        WaterFixLogo(fontSize: 32),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSectionEntrance(
                    delayMs: 90,
                    child: Text(
                      _isSignUp
                          ? 'Create your ${_selectedRole == "supplier" ? "water supplier" : "customer"} account using email & phone.'
                          : 'Sign in as ${_selectedRole == "admin" ? "an Admin" : _selectedRole == "supplier" ? "a Water Supplier" : "a Customer"} with your email or phone (+92).',
                      style: const TextStyle(
                        fontSize: 15,
                        color: WaterFixColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sign In / Create Account Mode Switcher
                  AnimatedSectionEntrance(
                    delayMs: 130,
                    child: Row(
                      children: [
                        SelectablePillChip(
                          label: 'Sign in',
                          isSelected: !_isSignUp,
                          onTap: () => setState(() => _isSignUp = false),
                        ),
                        const SizedBox(width: 10),
                        SelectablePillChip(
                          label: 'Create account',
                          isSelected: _isSignUp,
                          onTap: () => setState(() {
                            _isSignUp = true;
                            if (_selectedRole == 'admin') {
                              _selectedRole = 'customer';
                            }
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Account Type Selector on Sign In (Customer, Water Supplier, Admin) and Sign Up (Customer, Water Supplier)
                  AnimatedSectionEntrance(
                    delayMs: 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isSignUp ? 'ACCOUNT TYPE' : 'SIGNING IN AS',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: WaterFixColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SelectablePillChip(
                              label: 'Customer',
                              isSelected: _selectedRole == 'customer',
                              onTap: () =>
                                  setState(() => _selectedRole = 'customer'),
                            ),
                            SelectablePillChip(
                              label: 'Water Supplier',
                              isSelected: _selectedRole == 'supplier',
                              onTap: () =>
                                  setState(() => _selectedRole = 'supplier'),
                            ),
                            if (!_isSignUp)
                              SelectablePillChip(
                                label: 'Admin',
                                isSelected: _selectedRole == 'admin',
                                onTap: () =>
                                    setState(() => _selectedRole = 'admin'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (!_isSignUp && _selectedRole == 'supplier') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: WaterFixColors.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: WaterFixColors.cardBorder),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            size: 20,
                            color: WaterFixColors.primaryBlack,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Supplier Portal: Manage tanker capacities, incoming delivery requests, and your commission wallet.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: WaterFixColors.primaryBlack,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else if (!_isSignUp && _selectedRole == 'admin') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: WaterFixColors.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: WaterFixColors.cardBorder),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 20,
                            color: WaterFixColors.primaryBlack,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Admin Portal:Authorized platform administrators only. Manage suppliers, customers, overdue commissions, and payments.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: WaterFixColors.primaryBlack,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (!_isSignUp) ...[
                    const Text(
                      'EMAIL OR PHONE NUMBER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: WaterFixColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('login_identifier_field'),
                      controller: _identifierController,
                      validator: AppValidators.validateIdentifier,
                      decoration: const InputDecoration(
                        hintText: '+92 300 0000000 or name@email.com',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const Text(
                      'FULL NAME',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: WaterFixColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('signup_name_field'),
                      controller: _nameController,
                      validator: (val) => (val == null || val.trim().length < 2)
                          ? 'Please enter your full name'
                          : null,
                      decoration: const InputDecoration(
                        hintText: 'Ayesha Khan',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'EMAIL ADDRESS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: WaterFixColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('signup_email_field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: AppValidators.validateEmailField,
                      decoration: const InputDecoration(
                        hintText: 'ayesha@example.com',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'PHONE NUMBER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: WaterFixColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('signup_phone_field'),
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      validator: AppValidators.validatePhoneField,
                      decoration: const InputDecoration(
                        hintText: '+92 300 0000000',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'CNIC NUMBER (13 DIGITS)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: WaterFixColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('signup_cnic_field'),
                      controller: _cnicController,
                      keyboardType: TextInputType.number,
                      validator: AppValidators.validateCnic,
                      decoration: const InputDecoration(
                        hintText: '35201-1234567-1',
                        prefixIcon: Icon(Icons.badge_outlined),
                        helperText: 'Required for official WaterFix identity review',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_isSignUp && _selectedRole == 'supplier') ...[
                    const Text(
                      'COMPANY / BUSINESS NAME',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: WaterFixColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _businessNameController,
                      validator: (val) => (val == null || val.trim().length < 2)
                          ? 'Company name is required for suppliers'
                          : null,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Ashhad Water Tanker Company',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'HOW MANY TANKERS DOES YOUR COMPANY OWN?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: WaterFixColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('tankers_owned_field'),
                      controller: _tankersOwnedController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        final n = int.tryParse(val?.trim() ?? '');
                        if (n == null || n < 1) {
                          return 'Please enter a positive whole number (at least 1)';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        hintText: 'e.g. 4',
                        prefixIcon: Icon(Icons.local_shipping_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'COMPANY LOCATION (ISLAMABAD SECTOR)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: WaterFixColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickIslamabadLocality,
                      borderRadius: BorderRadius.circular(16),
                      child: IgnorePointer(
                        child: TextFormField(
                          controller: _serviceAreaController,
                          decoration: const InputDecoration(
                            hintText: 'Select Islamabad sector or area...',
                            prefixIcon: Icon(Icons.location_on_outlined),
                            suffixIcon: Icon(Icons.arrow_drop_down_rounded),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DELIVERY RADIUS (MAX 20 KM)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                key: const Key('delivery_radius_field'),
                                controller: _serviceRadiusController,
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  final r = int.tryParse(val?.trim() ?? '');
                                  if (r == null || r < 1 || r > 20) {
                                    return 'Must be 1 to 20 km';
                                  }
                                  return null;
                                },
                                decoration: const InputDecoration(
                                  hintText: '15',
                                  suffixText: 'km',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PRICE PER 1,000 L',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: WaterFixColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _pricePer1000Controller,
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  final p = int.tryParse(val?.trim() ?? '');
                                  if (p == null || p < 100) {
                                    return 'Min PKR 100';
                                  }
                                  return null;
                                },
                                decoration: const InputDecoration(
                                  hintText: '1800',
                                  prefixText: 'PKR ',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Text(
                    'PASSWORD',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: WaterFixColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('password_field'),
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    validator: AppValidators.validatePassword,
                    decoration: InputDecoration(
                      hintText: 'Minimum 8 characters (letters & numbers)',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ),

                  if (_isSignUp) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'CONFIRM PASSWORD',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: WaterFixColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('confirm_password_field'),
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      validator: (val) => AppValidators.validateConfirmPassword(
                        val,
                        _passwordController.text,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Re-enter your password',
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  PrimaryArrowButton(
                    label: _isSignUp
                        ? 'Create ${_selectedRole == "supplier" ? "supplier" : "customer"} account'
                        : 'Sign in as ${_selectedRole == "admin" ? "Admin" : _selectedRole == "supplier" ? "Supplier" : "Customer"}',
                    isLoading: controller.isAuthLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'By continuing you agree to the Terms of Service and Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: WaterFixColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
