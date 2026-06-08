import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/apartment_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/common_button.dart';

class CreateApartmentScreen extends StatefulWidget {
  const CreateApartmentScreen({super.key});

  @override
  State<CreateApartmentScreen> createState() => _CreateApartmentScreenState();
}

class _CreateApartmentScreenState extends State<CreateApartmentScreen> {
  final _formKey = GlobalKey<FormState>();

  // Apartment fields
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _flatsCtrl = TextEditingController();
  final _amenityCtrl = TextEditingController();
  final List<String> _amenities = [];

  // President (Admin) fields
  final _presidentNameCtrl = TextEditingController();
  final _presidentEmailCtrl = TextEditingController();
  final _presidentFlatCtrl = TextEditingController();

  bool _isSubmitting = false;

  static const List<String> _commonAmenities = [
    'Parking', 'Gym', 'Pool', 'Garden', 'Security',
    'Lift', 'Clubhouse', 'Tennis Court', 'Play Area',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _flatsCtrl.dispose();
    _amenityCtrl.dispose();
    _presidentNameCtrl.dispose();
    _presidentEmailCtrl.dispose();
    _presidentFlatCtrl.dispose();
    super.dispose();
  }

  void _toggleAmenity(String a) {
    setState(() {
      if (_amenities.contains(a)) {
        _amenities.remove(a);
      } else {
        _amenities.add(a);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final userProvider = context.read<UserProvider>();
      final aptProvider = context.read<ApartmentProvider>();

      final aptName = _nameCtrl.text.trim();

      // Pre-generate apartment ID so admin can reference it before the apt exists
      final aptId = 'apt_${DateTime.now().millisecondsSinceEpoch}';

      // 1. Create admin user (password auto-generated)
      final adminResult = userProvider.createAdmin(
        name: _presidentNameCtrl.text.trim(),
        email: _presidentEmailCtrl.text.trim(),
        aptName: aptName,
        aptId: aptId,
        unit: _presidentFlatCtrl.text.trim(),
      );

      // 2. Create apartment with presidentId already set
      await aptProvider.createApartment(
        id: aptId,
        name: aptName,
        address: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        totalFlats: int.parse(_flatsCtrl.text.trim()),
        amenities: List.from(_amenities),
        presidentId: adminResult.id,
      );

      if (!mounted) return;

      // 3. Show generated credentials to super admin
      await AppUtils.showGeneratedCredentials(
        context,
        name: _presidentNameCtrl.text.trim(),
        email: _presidentEmailCtrl.text.trim(),
        password: adminResult.password,
        role: 'Admin (President)',
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      AppUtils.showSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Create Apartment',
            style: AppTextStyles.heading3(color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.superAdminGradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.superAdminGradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.apartment_outlined,
                        color: Colors.white, size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('New Apartment',
                              style: AppTextStyles.subheading(
                                  color: Colors.white)),
                          Text(
                              'Fill in apartment details and assign an initial president',
                              style: AppTextStyles.caption(
                                  color: Colors.white.withOpacity(0.8))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Apartment Details ─────────────────────────────────────────
              _SectionHeader(
                icon: Icons.apartment_outlined,
                title: 'Apartment Details',
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Apartment Name',
                hint: 'e.g., Samhith Residency',
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                prefixIcon: const Icon(Icons.apartment_outlined, size: 20),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter apartment name' : null,
              ),

              const SizedBox(height: 16),
              AppTextField(
                label: 'Address',
                hint: 'e.g., 14, Jubilee Hills',
                controller: _addressCtrl,
                textCapitalization: TextCapitalization.sentences,
                prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter address' : null,
              ),

              const SizedBox(height: 16),
              AppTextField(
                label: 'City',
                hint: 'e.g., Hyderabad',
                controller: _cityCtrl,
                textCapitalization: TextCapitalization.words,
                prefixIcon: const Icon(Icons.location_city_outlined, size: 20),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter city' : null,
              ),

              const SizedBox(height: 16),
              AppTextField(
                label: 'Total Flats (Hard Limit)',
                hint: 'e.g., 10',
                controller: _flatsCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                prefixIcon: const Icon(Icons.door_front_door_outlined, size: 20),
                helperText: 'Maximum members allowed (cannot exceed this limit)',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter number of flats';
                  final n = int.tryParse(v);
                  if (n == null || n < 1) return 'Enter a valid number (≥ 1)';
                  return null;
                },
              ),

              const SizedBox(height: 20),
              Text('Amenities',
                  style: AppTextStyles.label(color: AppColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commonAmenities.map((a) {
                  final selected = _amenities.contains(a);
                  return GestureDetector(
                    onTap: () => _toggleAmenity(a),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.purple.withOpacity(0.12)
                            : AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.purple
                              : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        a,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected
                              ? AppColors.purple
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              if (_amenities.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Selected: ${_amenities.join(', ')}',
                  style: AppTextStyles.caption(color: AppColors.purple),
                ),
              ],

              const SizedBox(height: 32),

              // ── Initial President (Admin) ─────────────────────────────────
              _SectionHeader(
                icon: Icons.manage_accounts_outlined,
                title: 'Initial President (Admin)',
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.blue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.blue.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: AppColors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This person will be created as the apartment president and can log in immediately.',
                        style: AppTextStyles.caption(color: AppColors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'President Name',
                hint: 'e.g., G. Srikanth',
                controller: _presidentNameCtrl,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter president name' : null,
              ),

              const SizedBox(height: 16),
              AppTextField(
                label: 'President Flat Number',
                hint: 'e.g., 402',
                controller: _presidentFlatCtrl,
                textCapitalization: TextCapitalization.characters,
                prefixIcon: const Icon(Icons.door_front_door_outlined, size: 20),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter flat number' : null,
              ),

              const SizedBox(height: 16),
              AppTextField(
                label: 'Login Email',
                hint: 'e.g., president@apartment.com',
                controller: _presidentEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter email';
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),

              Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.paid.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.paid.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 16, color: AppColors.paid),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Login password will be auto-generated and shown after creation.',
                        style: AppTextStyles.caption(color: AppColors.paid),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              CommonButton(
                text: 'Create Apartment',
                gradient: AppColors.superAdminGradient,
                icon: Icons.add_home_outlined,
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.superAdminGradient.first.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              size: 18, color: AppColors.superAdminGradient.last),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: AppTextStyles.subheading(color: AppColors.textPrimary)),
      ],
    );
  }
}

