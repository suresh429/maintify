import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/apartment_provider.dart';
import '../../widgets/common_button.dart';

class CreateApartmentScreen extends StatefulWidget {
  const CreateApartmentScreen({super.key});

  @override
  State<CreateApartmentScreen> createState() => _CreateApartmentScreenState();
}

class _CreateApartmentScreenState extends State<CreateApartmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _flatsCtrl = TextEditingController();
  final _amenityCtrl = TextEditingController();
  final List<String> _amenities = [];

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

    await context.read<ApartmentProvider>().createApartment(
          name: _nameCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          totalFlats: int.parse(_flatsCtrl.text.trim()),
          amenities: List.from(_amenities),
        );

    if (!mounted) return;
    AppUtils.showSnackBar(context, 'Apartment created successfully!',
        color: AppColors.green);
    Navigator.pop(context);
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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
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
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
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
                          Text('Fill in the details to add a new property',
                              style: AppTextStyles.caption(
                                  color: Colors.white.withOpacity(0.8))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _Label('Apartment Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                style: AppTextStyles.bodyLarge(),
                decoration: InputDecoration(
                  hintText: 'e.g., Sai Residency',
                  hintStyle: AppTextStyles.bodyMedium(),
                  prefixIcon: const Icon(Icons.apartment_outlined, size: 20),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter apartment name' : null,
              ),

              const SizedBox(height: 16),
              _Label('Address'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressCtrl,
                style: AppTextStyles.bodyLarge(),
                decoration: InputDecoration(
                  hintText: 'e.g., 12, MG Road',
                  hintStyle: AppTextStyles.bodyMedium(),
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter address' : null,
              ),

              const SizedBox(height: 16),
              _Label('City'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cityCtrl,
                style: AppTextStyles.bodyLarge(),
                decoration: InputDecoration(
                  hintText: 'e.g., Bengaluru',
                  hintStyle: AppTextStyles.bodyMedium(),
                  prefixIcon: const Icon(Icons.location_city_outlined, size: 20),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter city' : null,
              ),

              const SizedBox(height: 16),
              _Label('Total Flats'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _flatsCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTextStyles.bodyLarge(),
                decoration: InputDecoration(
                  hintText: 'e.g., 10',
                  hintStyle: AppTextStyles.bodyMedium(),
                  prefixIcon:
                      const Icon(Icons.door_front_door_outlined, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter number of flats';
                  final n = int.tryParse(v);
                  if (n == null || n < 1) return 'Enter a valid number (≥ 1)';
                  return null;
                },
              ),

              const SizedBox(height: 20),
              _Label('Amenities'),
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

              Consumer<ApartmentProvider>(
                builder: (_, aptProv, __) => CommonButton(
                  text: 'Create Apartment',
                  gradient: AppColors.superAdminGradient,
                  icon: Icons.add_home_outlined,
                  isLoading: aptProv.isLoading,
                  onPressed: _submit,
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: AppTextStyles.label(color: AppColors.textPrimary)
            .copyWith(fontWeight: FontWeight.w600));
  }
}
