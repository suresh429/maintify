import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/apartment_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/common_button.dart';

const List<String> _kApartmentTypes = [
  'Apartment',
  'Villa',
  'Gated Community',
];

class CreateApartmentScreen extends StatefulWidget {
  const CreateApartmentScreen({super.key});

  @override
  State<CreateApartmentScreen> createState() => _CreateApartmentScreenState();
}

class _CreateApartmentScreenState extends State<CreateApartmentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl           = TextEditingController();
  final _addressCtrl        = TextEditingController();
  final _flatsCtrl          = TextEditingController();
  final _towerCountCtrl     = TextEditingController(text: '1');
  final _towerNamesCtrl     = TextEditingController(text: 'A');
  final _presidentNameCtrl  = TextEditingController();
  final _presidentEmailCtrl = TextEditingController();
  final _presidentPhoneCtrl = TextEditingController();
  final _presidentFlatCtrl  = TextEditingController();

  String _aptType    = _kApartmentTypes.first;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _flatsCtrl.dispose();
    _towerCountCtrl.dispose();
    _towerNamesCtrl.dispose();
    _presidentNameCtrl.dispose();
    _presidentEmailCtrl.dispose();
    _presidentPhoneCtrl.dispose();
    _presidentFlatCtrl.dispose();
    super.dispose();
  }

  void _onTowerCountChanged(String value) {
    final n = int.tryParse(value.trim()) ?? 0;
    if (n < 1 || n > 26) return;
    _towerNamesCtrl.text =
        List.generate(n, (i) => String.fromCharCode(65 + i)).join(', ');
  }

  String _generateCode(String aptName) {
    final clean = aptName.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final letters =
        clean.length >= 4 ? clean.substring(0, 4) : clean.padRight(4, 'X');
    final digits = (1000 + Random().nextInt(9000)).toString();
    return '$letters$digits';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final aptProvider = context.read<ApartmentProvider>();
      final aptName     = _nameCtrl.text.trim();
      final aptId       = 'apt_${DateTime.now().millisecondsSinceEpoch}';
      final code        = _generateCode(aptName);
      final isGated     = _aptType == 'Gated Community';
      final towerCount  = isGated
          ? (int.tryParse(_towerCountCtrl.text.trim()) ?? 1)
          : 0;
      final towerNames  = isGated
          ? _towerNamesCtrl.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList()
          : <String>[];

      await aptProvider.createApartment(
        id: aptId,
        name: aptName,
        type: _aptType,
        address: _addressCtrl.text.trim(),
        totalFlats: int.parse(_flatsCtrl.text.trim()),
        towerCount: towerCount,
        towerNames: towerNames,
        presidentName: _presidentNameCtrl.text.trim(),
        presidentEmail: _presidentEmailCtrl.text.trim().toLowerCase(),
        presidentPhone: _presidentPhoneCtrl.text.trim(),
        presidentFlat: _presidentFlatCtrl.text.trim(),
        code: code,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await _showSuccessSheet(code, aptName);
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

  Future<void> _showSuccessSheet(String code, String aptName) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (ctx) {
        final sheetCs    = Theme.of(ctx).colorScheme;
        final accentColor =
            RoleTheme.of(UserRole.superAdmin).effectivePrimary(ctx);
        return Container(
          decoration: BoxDecoration(
            color: sheetCs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetCs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.superAdminGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.apartment_outlined,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),

              Text('Apartment Created!',
                  style: AppTextStyles.heading3(color: sheetCs.onSurface)),
              const SizedBox(height: 4),
              Text(aptName,
                  style: AppTextStyles.subheading(
                      color: sheetCs.onSurfaceVariant),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),

              Text('Apartment Code',
                  style: AppTextStyles.label(color: sheetCs.onSurfaceVariant)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 16),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: accentColor.withOpacity(0.35), width: 1.5),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy Code'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: BorderSide(color: accentColor.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  AppUtils.showSnackBar(ctx, 'Apartment code copied!');
                },
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.paid.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.paid.withOpacity(0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.mark_email_read_outlined,
                        size: 16, color: AppColors.paid),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'An invitation email with apartment details and this code has been sent to the president automatically.',
                        style: AppTextStyles.caption(color: AppColors.paid),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              CommonButton(
                text: 'Done',
                gradient: AppColors.superAdminGradient,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final theme = RoleTheme.of(UserRole.superAdmin);
    final accent = theme.effectivePrimary(context);

    return Scaffold(
      backgroundColor: cs.background,
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
                            'A unique code is generated and emailed to the president automatically.',
                            style: AppTextStyles.caption(
                                color: Colors.white.withOpacity(0.8)),
                          ),
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

              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: _aptType,
                decoration: InputDecoration(
                  labelText: 'Apartment Type',
                  prefixIcon: const Icon(Icons.category_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accent, width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  labelStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: cs.onSurfaceVariant),
                ),
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 14, color: cs.onSurface),
                items: _kApartmentTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _aptType = v!),
              ),

              const SizedBox(height: 14),

              AppTextField(
                label: 'Complete Address',
                hint: 'Street, City, State, PIN Code',
                controller: _addressCtrl,
                maxLines: 3,
                prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter address' : null,
              ),

              const SizedBox(height: 14),

              AppTextField(
                label: 'Total Flats',
                hint: 'e.g., 10',
                controller: _flatsCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                prefixIcon:
                    const Icon(Icons.door_front_door_outlined, size: 20),
                helperText: 'Hard limit — no more than this many residents',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter number of flats';
                  final n = int.tryParse(v);
                  if (n == null || n < 1) return 'Must be ≥ 1';
                  return null;
                },
              ),

              if (_aptType == 'Gated Community') ...[
                const SizedBox(height: 14),

                AppTextField(
                  label: 'Number of Towers / Blocks',
                  hint: 'e.g., 3',
                  controller: _towerCountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: const Icon(Icons.domain_outlined, size: 20),
                  onChanged: _onTowerCountChanged,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter number of towers';
                    }
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 1 || n > 26) {
                      return 'Must be between 1 and 26';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                AppTextField(
                  label: 'Tower / Block Names',
                  hint: 'e.g., A, B, C  or  North, South',
                  controller: _towerNamesCtrl,
                  prefixIcon:
                      const Icon(Icons.label_outline_rounded, size: 20),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter tower names'
                      : null,
                ),
              ],

              const SizedBox(height: 32),

              // ── President Info ────────────────────────────────────────────
              _SectionHeader(
                icon: Icons.manage_accounts_outlined,
                title: 'President Info',
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'An invitation email with the Apartment Code will be sent to the president as soon as the apartment is created.',
                        style: AppTextStyles.caption(color: accent),
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
                prefixIcon:
                    const Icon(Icons.person_outline_rounded, size: 20),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter president name'
                    : null,
              ),

              const SizedBox(height: 16),

              AppTextField(
                label: 'President Email',
                hint: 'e.g., president@example.com',
                controller: _presidentEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter email';
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              AppTextField(
                label: 'President Mobile',
                hint: 'e.g., +91 98765 43210',
                controller: _presidentPhoneCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter mobile number'
                    : null,
              ),

              const SizedBox(height: 16),

              AppTextField(
                label: 'President Flat Number',
                hint: 'e.g., A-101',
                controller: _presidentFlatCtrl,
                textCapitalization: TextCapitalization.characters,
                prefixIcon:
                    const Icon(Icons.meeting_room_outlined, size: 20),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter flat number'
                    : null,
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
    final cs     = Theme.of(context).colorScheme;
    final accent =
        RoleTheme.of(UserRole.superAdmin).effectivePrimary(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: AppTextStyles.subheading(color: cs.onSurface)),
      ],
    );
  }
}
