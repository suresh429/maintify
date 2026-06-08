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

class _LineItem {
  final TextEditingController titleCtrl;
  final TextEditingController amountCtrl;
  String category;

  _LineItem({required this.titleCtrl, required this.amountCtrl, String? category})
      : category = category ?? 'Maintenance';

  void dispose() {
    titleCtrl.dispose();
    amountCtrl.dispose();
  }
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<_LineItem> _lineItems = [];
  String _selectedMonth = '';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 10));

  static const _categories = [
    'Maintenance', 'Water', 'Lift', 'Security', 'Parking', 'Amenities', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMonth = AppUtils.formatMonthYear(DateTime.now());
    _lineItems.add(_LineItem(
      titleCtrl: TextEditingController(),
      amountCtrl: TextEditingController(),
    ));
  }

  @override
  void dispose() {
    for (final item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  double get _totalAmount {
    return _lineItems.fold(0.0, (s, item) {
      return s + (double.tryParse(item.amountCtrl.text) ?? 0);
    });
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

  /// Returns DateTime objects for the last 12 months (current month first).
  List<DateTime> _generateMonths() {
    final now = DateTime.now();
    return List.generate(12, (i) => DateTime(now.year, now.month - i));
  }

  Future<void> _pickMonth() async {
    final months = _generateMonths();
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month);

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle + title (fixed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Select Billing Month',
                          style: AppTextStyles.heading3()),
                      const SizedBox(height: 4),
                      Text('Current month and past months only',
                          style: AppTextStyles.caption()),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Scrollable month list
                Flexible(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: months.length,
                    itemBuilder: (_, i) {
                      final month = months[i];
                      final label = AppUtils.formatMonthYear(month);
                      final isSelected = label == _selectedMonth;
                      final isFuture = month.isAfter(currentMonthStart);

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.blue.withOpacity(0.1)
                                : AppColors.lightGray,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.calendar_month_outlined,
                            size: 18,
                            color: isSelected
                                ? AppColors.blue
                                : AppColors.textSecondary,
                          ),
                        ),
                        title: Text(
                          label,
                          style: AppTextStyles.bodyLarge().copyWith(
                            color: isFuture
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: i == 0
                            ? Text('Current month',
                                style: AppTextStyles.caption(
                                    color: AppColors.blue))
                            : null,
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppColors.blue)
                            : null,
                        enabled: !isFuture,
                        onTap: () {
                          if (isFuture) {
                            AppUtils.showSnackBar(ctx,
                                'Future billing not allowed',
                                isError: true);
                            return;
                          }
                          Navigator.pop(ctx, label);
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

    if (picked != null) setState(() => _selectedMonth = picked);
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

    final billProvider = context.read<BillProvider>();

    if (billProvider.hasMonthlyBill(aptId, _selectedMonth)) {
      AppUtils.showSnackBar(
          context,
          'A bill for $_selectedMonth already exists. Delete or update it instead.',
          isError: true);
      return;
    }

    final residents = MockUsers.residentsForApartment(aptId);
    if (residents.isEmpty) {
      AppUtils.showSnackBar(context, 'No residents found in this apartment',
          isError: true);
      return;
    }

    final lineItems = _lineItems.map((item) => (
          title: item.titleCtrl.text.trim(),
          category: item.category,
          amount: double.parse(item.amountCtrl.text.trim()),
        )).toList();

    await billProvider.createMonthlyBill(
      apartmentId: aptId,
      adminId: auth.currentUser?.id ?? 'u2',
      month: _selectedMonth,
      dueDate: _dueDate,
      lineItems: lineItems,
      totalFlats: apt.totalFlats,
      residents: residents,
    );

    if (!mounted) return;
    AppUtils.showSnackBar(
      context,
      '$_selectedMonth bill created for ${residents.length} residents! '
      '(${AppUtils.formatCurrency(_totalAmount / apt.totalFlats)}/flat)',
      color: AppColors.green,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final aptId = auth.currentUser?.apartmentId ?? 'apt1';
    final apt = MockApartments.findById(aptId);
    final residents = MockUsers.residentsForApartment(aptId);
    final theme = RoleTheme.of(UserRole.admin);
    final totalFlats = apt?.totalFlats ?? residents.length;
    final perFlatShare = totalFlats > 0 ? _totalAmount / totalFlats : 0.0;

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Create Monthly Bill',
            style: AppTextStyles.heading3(color: Colors.white)),
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
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined,
                        color: Colors.white, size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Monthly Bill',
                              style: AppTextStyles.subheading(
                                  color: Colors.white)),
                          Text(
                            'One bill per month · split across $totalFlats flats',
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

              // Month selector
              _SectionLabel('Billing Month'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickMonth,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined,
                          size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Text(_selectedMonth, style: AppTextStyles.bodyLarge()),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Line items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SectionLabel('Bill Categories'),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _lineItems.add(_LineItem(
                          titleCtrl: TextEditingController(),
                          amountCtrl: TextEditingController(),
                        ));
                      });
                    },
                    icon: const Icon(Icons.add_rounded,
                        size: 18, color: AppColors.blue),
                    label: Text('Add',
                        style: AppTextStyles.label(color: AppColors.blue)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ..._lineItems.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Item ${idx + 1}',
                              style: AppTextStyles.label(
                                  color: theme.primary)
                                  .copyWith(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (_lineItems.length > 1)
                            GestureDetector(
                              onTap: () => setState(() {
                                _lineItems[idx].dispose();
                                _lineItems.removeAt(idx);
                              }),
                              child: const Icon(Icons.remove_circle_outline,
                                  color: AppColors.overdue, size: 20),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Category
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.lightGray,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: item.category,
                            isExpanded: true,
                            isDense: true,
                            style: AppTextStyles.bodyMedium(
                                color: AppColors.textPrimary),
                            icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 20),
                            items: _categories
                                .map((c) => DropdownMenuItem(
                                    value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => item.category = v!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Title
                      TextFormField(
                        controller: item.titleCtrl,
                        style: AppTextStyles.bodyLarge(),
                        decoration: InputDecoration(
                          hintText: 'Description (e.g., Water Charges)',
                          hintStyle: AppTextStyles.bodyMedium(),
                          prefixIcon: const Icon(Icons.receipt_outlined,
                              size: 18),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Enter description' : null,
                      ),
                      const SizedBox(height: 8),

                      // Amount
                      TextFormField(
                        controller: item.amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: AppTextStyles.bodyLarge(),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Total amount (₹)',
                          hintStyle: AppTextStyles.bodyMedium(),
                          prefixIcon: const Icon(
                              Icons.currency_rupee_outlined,
                              size: 18),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter amount';
                          final a = double.tryParse(v);
                          if (a == null || a <= 0) return 'Enter valid amount';
                          return null;
                        },
                      ),
                    ],
                  ),
                );
              }),

              // Total summary
              if (_totalAmount > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.primary.withOpacity(0.2)),
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
                                    'Total ${AppUtils.formatCurrency(_totalAmount)} ÷ $totalFlats flats = ',
                              ),
                              TextSpan(
                                text: AppUtils.formatCurrency(perFlatShare),
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

              const SizedBox(height: 20),

              // Due date
              _SectionLabel('Due Date'),
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
                      Text(AppUtils.formatDate(_dueDate),
                          style: AppTextStyles.bodyLarge()),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Residents summary
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
                      child: Icon(Icons.group_outlined,
                          color: theme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Will be sent to all residents',
                              style: AppTextStyles.label()),
                          Text(
                            '${residents.length} residents · ${apt?.name ?? 'Apartment'}',
                            style: AppTextStyles.caption(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Consumer<BillProvider>(
                builder: (_, bp, __) => CommonButton(
                  text: 'Create $_selectedMonth Bill',
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
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.label(color: AppColors.textPrimary)
          .copyWith(fontWeight: FontWeight.w600),
    );
  }
}
