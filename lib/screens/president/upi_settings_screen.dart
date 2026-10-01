import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/upi_validator.dart';
import '../../providers/apartment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_text_field.dart';

class UpiSettingsScreen extends StatefulWidget {
  const UpiSettingsScreen({super.key});

  @override
  State<UpiSettingsScreen> createState() => _UpiSettingsScreenState();
}

class _UpiSettingsScreenState extends State<UpiSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _upiController = TextEditingController();
  bool _saving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final auth = context.read<AuthProvider>();
      final apt = context.read<ApartmentProvider>().findById(auth.currentUser?.apartmentId ?? '');
      if (apt != null) {
        _upiController.text = apt.upiId ?? '';
      }
    }
  }

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final normalized = UpiValidator.normalize(_upiController.text);
    final auth = context.read<AuthProvider>();
    final aptId = auth.currentUser?.apartmentId ?? '';
    final uid = auth.currentUser?.id ?? '';
    if (aptId.isEmpty) return;

    setState(() => _saving = true);
    try {
      await context.read<ApartmentProvider>().updateUpiSettings(
        aptId: aptId,
        upiId: normalized,
        upiPaymentsEnabled: normalized.isNotEmpty,
        updatedBy: uid,
      );
      if (!mounted) return;
      AppUtils.showSnackBar(context, 'UPI settings saved.', color: AppColors.paid);
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnackBar(context, 'Failed to save. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final apt = context.watch<ApartmentProvider>().findById(
          context.read<AuthProvider>().currentUser?.apartmentId ?? '');
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'UPI Payment Settings',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Residents can use this UPI ID to pay their apartment bills. Payments are verified by you before being marked as paid.',
                        style: AppTextStyles.caption(color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // UPI ID field
              Text('UPI ID', style: AppTextStyles.label(color: cs.onSurface).copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              AppTextField(
                controller: _upiController,
                label: 'UPI ID',
                hint: 'e.g., name@upi, 9876543210@ybl',
                keyboardType: TextInputType.emailAddress,
                focusColor: const Color(0xFF2563EB),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // empty = remove UPI
                  return UpiValidator.validate(v);
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Text(
                'Format: name@upi, name@oksbi, 9876543210@ybl',
                style: AppTextStyles.caption(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Save UPI Settings', style: AppTextStyles.buttonText()),
                ),
              ),

              // Current status
              if (apt != null && (apt.upiId ?? '').isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.paid.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.paid, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'UPI payments are active. Residents can pay using ${apt.upiId}.',
                          style: AppTextStyles.caption(color: AppColors.paid),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
