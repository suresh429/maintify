import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/apartment_model.dart';
import '../../models/user_model.dart';
import '../../widgets/common_button.dart';

class CreateBillScreen extends StatefulWidget {
  const CreateBillScreen({super.key});

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _selectedCategory = 'Maintenance';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 10));

  final List<String> _categories = [
    'Maintenance',
    'Utilities',
    'Security',
    'Parking',
    'Amenities',
    'Other',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  double get _perFlatShare {
    final auth = context.read<AuthProvider>();
    final aptId = auth.currentUser?.apartmentId ?? 'apt1';
    final apt = MockApartments.findById(aptId);
    final totalFlats = apt?.totalFlats ?? 1;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    return amount > 0 ? amount / totalFlats : 0;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.blue),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final aptId = auth.currentUser?.apartmentId ?? 'apt1';
    final apt = MockApartments.findById(aptId);
    if (apt == null) {
      AppUtils.showSnackBar(context, 'Apartment not found', isError: true);
      return;
    }

    final residents = MockUsers.residentsForApartment(aptId);
    if (residents.isEmpty) {
      AppUtils.showSnackBar(context, 'No residents found in this apartment',
          isError: true);
      return;
    }

    final billProvider = context.read<BillProvider>();
    await billProvider.createBill(
      apartmentId: aptId,
      adminId: auth.currentUser?.id ?? 'u2',
      title: _titleCtrl.text.trim(),
      totalAmount: double.parse(_amountCtrl.text.trim()),
      totalFlats: apt.totalFlats,
      category: _selectedCategory,
      month: AppUtils.formatMonthYear(DateTime.now()),
      dueDate: _dueDate,
      residents: residents,
    );

    if (!mounted) return;
    AppUtils.showSnackBar(
      context,
      'Bill created for ${residents.length} residents! (${AppUtils.formatCurrency(_perFlatShare)}/flat)',
      color: AppColors.green,
    );
    _formKey.currentState!.reset();
    setState(() {
      _titleCtrl.clear();
      _amountCtrl.clear();
      _selectedCategory = 'Maintenance';
      _dueDate = DateTime.now().add(const Duration(days: 10));
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final aptId = auth.currentUser?.apartmentId ?? 'apt1';
    final apt = MockApartments.findById(aptId);
    final residents = MockUsers.residentsForApartment(aptId);
    final theme = RoleTheme.of(UserRole.admin);
    final totalFlats = apt?.totalFlats ?? residents.length;

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Create Bill',
            style: AppTextStyles.heading3(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: theme.gradient,
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
                gradient: LinearGradient(
                  colors: theme.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline,
                      color: Colors.white, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New Apartment Bill',
                            style:
                                AppTextStyles.subheading(color: Colors.white)),
                        Text(
                          'Amount split equally across $totalFlats flats',
                          style: AppTextStyles.caption(
                              color: Colors.white.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _Label('Bill Title'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleCtrl,
              style: AppTextStyles.bodyLarge(),
              decoration: InputDecoration(
                hintText: 'e.g., Monthly Maintenance',
                hintStyle: AppTextStyles.bodyMedium(),
                prefixIcon:
                    const Icon(Icons.receipt_outlined, size: 20),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Enter bill title' : null,
            ),

            const SizedBox(height: 16),
            _Label('Total Amount (₹)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: AppTextStyles.bodyLarge(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'e.g., 2000',
                hintStyle: AppTextStyles.bodyMedium(),
                prefixIcon: const Icon(Icons.currency_rupee_outlined, size: 20),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter amount';
                final amount = double.tryParse(v);
                if (amount == null || amount <= 0) {
                  return 'Enter valid amount';
                }
                return null;
              },
            ),

            // Split preview
            if (_amountCtrl.text.isNotEmpty &&
                double.tryParse(_amountCtrl.text) != null &&
                double.parse(_amountCtrl.text) > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: theme.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calculate_outlined,
                        color: theme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  '${AppUtils.formatCurrency(double.parse(_amountCtrl.text))} ÷ $totalFlats flats = ',
                            ),
                            TextSpan(
                              text: AppUtils.formatCurrency(_perFlatShare),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.primary,
                                fontSize: 15,
                              ),
                            ),
                            const TextSpan(text: ' per flat'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            _Label('Category'),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  style: AppTextStyles.bodyLarge(),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedCategory = v!),
                ),
              ),
            ),

            const SizedBox(height: 16),
            _Label('Due Date'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Text(
                      AppUtils.formatDate(_dueDate),
                      style: AppTextStyles.bodyLarge(),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Residents summary card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(Icons.group_outlined, color: theme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bill will be created for all residents',
                            style: AppTextStyles.label()),
                        Text(
                          '${residents.length} residents · ${apt?.name ?? 'Apartment'}',
                          style: AppTextStyles.caption(),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${residents.length}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.primary,
                        )),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Consumer<BillProvider>(
              builder: (_, bp, __) => CommonButton(
                text: 'Create Bill for All Residents',
                gradient: theme.gradient,
                icon: Icons.add_circle_outline,
                isLoading: bp.isLoading,
                onPressed: _submit,
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    ), // end body SingleChildScrollView
    ); // end Scaffold
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
