import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/security_staff_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/security_staff_provider.dart';
import '../../widgets/app_text_field.dart';

class AddEditSecurityStaffScreen extends StatefulWidget {
  final SecurityStaffModel? existingStaff;

  const AddEditSecurityStaffScreen({super.key, this.existingStaff});

  @override
  State<AddEditSecurityStaffScreen> createState() =>
      _AddEditSecurityStaffScreenState();
}

class _AddEditSecurityStaffScreenState
    extends State<AddEditSecurityStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Controllers
  final _nameCtrl    = TextEditingController();
  final _mobileCtrl  = TextEditingController();
  final _salaryCtrl  = TextEditingController();
  final _addressCtrl = TextEditingController();

  // State
  String _designation = SecurityDesignation.watchman;
  String? _shift;
  DateTime _joiningDate = DateTime.now();
  bool _isActive = true;

  bool get _isEditing => widget.existingStaff != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existingStaff;
    if (s != null) {
      _nameCtrl.text   = s.name;
      // Strip the +91 prefix for display — only the 10-digit number in field
      _mobileCtrl.text = s.mobileNumber.startsWith('+91')
          ? s.mobileNumber.substring(3)
          : s.mobileNumber;
      _designation = s.designation;
      _shift       = s.shift;
      _joiningDate = s.joiningDate;
      _isActive    = s.isActive;
      if (s.address != null) _addressCtrl.text = s.address!;

      // Pre-fill salary from provider cache
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final salary = context
            .read<SecurityStaffProvider>()
            .salaries[s.id];
        if (salary != null && mounted) {
          _salaryCtrl.text =
              (salary.monthlySalaryPaise / 100).toStringAsFixed(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _salaryCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final auth        = context.read<AuthProvider>();
    final provider    = context.read<SecurityStaffProvider>();
    final presidentId = auth.currentUser?.id ?? '';
    final aptId       = auth.currentUser?.apartmentId ?? '';

    final mobile = '+91${_mobileCtrl.text.trim()}';

    final salaryRaw = double.tryParse(_salaryCtrl.text.trim()) ?? 0;
    final salaryPaise = (salaryRaw * 100).toInt();

    final now = DateTime.now();

    String? error;

    if (_isEditing) {
      final updated = widget.existingStaff!.copyWith(
        name:             _nameCtrl.text.trim(),
        mobileNumber:     mobile,
        designation:      _designation,
        joiningDate:      _joiningDate,
        shift:            _shift,
        address:          _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        employmentStatus: _isActive
            ? SecurityEmploymentStatus.active
            : SecurityEmploymentStatus.inactive,
        updatedAt: now,
        updatedBy: presidentId,
      );
      error = await provider.updateStaff(
        updated,
        monthlySalaryPaise: salaryPaise,
        presidentId: presidentId,
      );
    } else {
      final staffRef = DateTime.now().millisecondsSinceEpoch.toString();
      final newStaff = SecurityStaffModel(
        id:           staffRef,
        apartmentId:  aptId,
        name:         _nameCtrl.text.trim(),
        mobileNumber: mobile,
        designation:  _designation,
        joiningDate:  _joiningDate,
        shift:        _shift,
        address:      _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        employmentStatus: SecurityEmploymentStatus.active,
        createdAt:    now,
        updatedAt:    now,
        createdBy:    presidentId,
        updatedBy:    presidentId,
      );
      error = await provider.addStaff(newStaff, salaryPaise, presidentId);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      AppUtils.showSnackBar(context, 'Error: $error', isError: true);
    } else {
      AppUtils.showSnackBar(
          context,
          _isEditing
              ? '${_nameCtrl.text.trim()} updated'
              : '${_nameCtrl.text.trim()} added');
      Navigator.pop(context);
    }
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  Future<void> _pickJoiningDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _joiningDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.president);
    final cs    = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _isEditing ? 'Edit Staff' : 'Add Staff',
          style: AppTextStyles.heading3(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: theme.gradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Required fields ─────────────────────────────────────────────
              _SectionLabel(label: 'Required Information'),
              const SizedBox(height: 12),

              AppTextField(
                label: 'Full Name',
                controller: _nameCtrl,
                focusColor: theme.primary,
                prefixIcon: const Icon(Icons.person_outline_rounded),
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Mobile Number',
                controller: _mobileCtrl,
                focusColor: theme.primary,
                keyboardType: TextInputType.phone,
                prefixIcon: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 14),
                  child: Text('+91',
                      style: AppTextStyles.bodyMedium(
                          color: cs.onSurface)),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Mobile number is required';
                  }
                  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim())) {
                    return 'Enter a valid 10-digit Indian mobile number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Designation dropdown
              _DropdownField(
                label: 'Designation',
                value: _designation,
                items: SecurityDesignation.all,
                onChanged: (v) => setState(() => _designation = v!),
                icon: Icons.badge_outlined,
                focusColor: theme.primary,
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Monthly Salary (₹)',
                controller: _salaryCtrl,
                focusColor: theme.primary,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: const Icon(Icons.currency_rupee_rounded),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Salary is required';
                  }
                  final val = double.tryParse(v.trim());
                  if (val == null || val < 0) {
                    return 'Enter a valid salary amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Joining date picker
              GestureDetector(
                onTap: _pickJoiningDate,
                child: AbsorbPointer(
                  child: AppTextField(
                    label: 'Joining Date',
                    controller: TextEditingController(
                        text: AppUtils.formatDate(_joiningDate)),
                    focusColor: theme.primary,
                    readOnly: true,
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    validator: (_) => null,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Employment status toggle (shown only in edit mode)
              if (_isEditing) ...[
                _SectionLabel(label: 'Employment Status'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      _isActive ? 'Active' : 'Inactive',
                      style: AppTextStyles.bodyMedium(color: cs.onSurface),
                    ),
                    subtitle: Text(
                      _isActive
                          ? 'Staff is currently on duty'
                          : 'Staff is no longer active',
                      style:
                          AppTextStyles.caption(color: cs.onSurfaceVariant),
                    ),
                    value: _isActive,
                    activeThumbColor: AppColors.paid,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── Optional fields ────────────────────────────────────────────
              _SectionLabel(label: 'Optional Information'),
              const SizedBox(height: 12),

              // Shift dropdown
              _DropdownField(
                label: 'Shift',
                value: _shift,
                items: SecurityShift.all,
                nullable: true,
                onChanged: (v) => setState(() => _shift = v),
                icon: Icons.watch_later_outlined,
                focusColor: theme.primary,
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Address',
                controller: _addressCtrl,
                focusColor: theme.primary,
                prefixIcon: const Icon(Icons.location_on_outlined),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 28),

              // ── Save button ────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: theme.gradient,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _isSaving ? null : _save,
                      child: Center(
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5),
                              )
                            : Text(
                                'Save Staff',
                                style: AppTextStyles.buttonText(
                                    color: Colors.white),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(label,
        style: AppTextStyles.subheading(color: cs.onSurface)
            .copyWith(fontWeight: FontWeight.w700));
  }
}

// ── Dropdown field ────────────────────────────────────────────────────────────

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final bool nullable;
  final void Function(String?) onChanged;
  final IconData icon;
  final Color? focusColor;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
    this.nullable = false,
    this.focusColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            fontFamily: 'Poppins', color: cs.onSurfaceVariant),
        prefixIcon: Icon(icon, color: cs.onSurfaceVariant),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: focusColor ?? cs.primary, width: 2),
        ),
        filled: true,
        fillColor: cs.surface,
      ),
      items: [
        if (nullable)
          const DropdownMenuItem<String>(
              value: null, child: Text('Not set', style: TextStyle(fontFamily: 'Poppins'))),
        ...items.map((s) => DropdownMenuItem<String>(
              value: s,
              child: Text(s, style: const TextStyle(fontFamily: 'Poppins')),
            )),
      ],
      onChanged: onChanged,
      style: TextStyle(
          fontFamily: 'Poppins', fontSize: 14, color: cs.onSurface),
      validator: (v) {
        if (!nullable && (v == null || v.isEmpty)) return 'Please select a $label';
        return null;
      },
    );
  }
}
