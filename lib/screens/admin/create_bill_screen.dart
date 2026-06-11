import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bill_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../providers/apartment_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/user_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/common_button.dart';

class CreateBillScreen extends StatefulWidget {
  const CreateBillScreen({super.key});

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

/// One billing line-item. type='common' splits total equally; type='hybrid'
/// uses a per-flat default with optional per-user overrides.
class _LineItem {
  final TextEditingController titleCtrl;
  // common → total amount; hybrid → default per-flat amount
  final TextEditingController amountCtrl;
  String category;
  String type; // 'common' | 'hybrid'
  bool showOverrides;
  // userId → override amount (hybrid only; empty = use default)
  final Map<String, TextEditingController> overrideCtrls;

  _LineItem({String? category, String? type})
      : titleCtrl = TextEditingController(),
        amountCtrl = TextEditingController(),
        category = category ?? 'Maintenance',
        type = type ?? 'common',
        showOverrides = false,
        overrideCtrls = {};

  void dispose() {
    titleCtrl.dispose();
    amountCtrl.dispose();
    for (final c in overrideCtrls.values) {
      c.dispose();
    }
  }
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<_LineItem> _lineItems = [];
  String _selectedMonth = '';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 10));

  static const _categories = [
    'Maintenance', 'Water', 'Lift', 'Security', 'Parking', 'Amenities', 'Garbage', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMonth = AppUtils.formatMonthYear(DateTime.now());
    _lineItems.add(_LineItem());
  }

  @override
  void dispose() {
    for (final item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  /// Computed total to display in the summary banner.
  double _computedTotal(List<UserModel> residents, int totalFlats) {
    double total = 0;
    for (final item in _lineItems) {
      final amount = double.tryParse(item.amountCtrl.text) ?? 0;
      if (item.type == 'common') {
        total += amount;
      } else {
        // Hybrid: sum override-or-default for each resident
        for (final r in residents) {
          final overrideText = item.overrideCtrls[r.id]?.text.trim() ?? '';
          final override = double.tryParse(overrideText);
          total += override ?? amount;
        }
      }
    }
    return total;
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

  Future<void> _submit(
      List<UserModel> residents, int totalFlats, String aptId) async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    if (aptId.isEmpty) {
      AppUtils.showSnackBar(context, 'Apartment not found', isError: true);
      return;
    }

    final billProvider = context.read<BillProvider>();
    if (residents.isEmpty) {
      AppUtils.showSnackBar(context, 'No residents found in this apartment',
          isError: true);
      return;
    }

    // Always check the server directly — the local stream cache can be stale
    // after a console deletion or across re-logins (Firestore offline cache).
    final alreadyExists =
        await billProvider.checkMonthlyBillFresh(aptId, _selectedMonth);
    if (!mounted) return;
    if (alreadyExists) {
      AppUtils.showSnackBar(
          context,
          'A bill for $_selectedMonth already exists. Edit or delete it from the dashboard.',
          isError: true);
      return;
    }

    // Build BillCategory list from line items
    final categories = <BillCategory>[];
    for (final item in _lineItems) {
      final title = item.titleCtrl.text.trim();
      final amount = double.parse(item.amountCtrl.text.trim());

      if (item.type == 'common') {
        categories.add(BillCategory(
          name: title,
          type: 'common',
          totalAmount: amount,
        ));
        debugPrint('[FLOW] Category: $title, type=common, total=₹${amount.toStringAsFixed(0)}, per-flat=₹${(amount / totalFlats).toStringAsFixed(0)}');
      } else {
        // Hybrid: compute total from override-or-default for each resident
        final userOverrides = <String, double>{};
        double hybridTotal = 0;
        for (final r in residents) {
          final overrideText = item.overrideCtrls[r.id]?.text.trim() ?? '';
          final overrideAmount = double.tryParse(overrideText);
          if (overrideAmount != null && overrideAmount != amount) {
            userOverrides[r.id] = overrideAmount;
            hybridTotal += overrideAmount;
          } else {
            hybridTotal += amount;
          }
        }
        categories.add(BillCategory(
          name: title,
          type: 'hybrid',
          totalAmount: hybridTotal,
          defaultAmount: amount,
          userOverrides: userOverrides,
        ));
        debugPrint('[FLOW] Category: $title, type=hybrid, default=₹${amount.toStringAsFixed(0)}, overrides=${userOverrides.length}, total=₹${hybridTotal.toStringAsFixed(0)}');
      }
    }

    await billProvider.createBillForMonth(
      apartmentId: aptId,
      adminId: auth.currentUser?.id ?? '',
      month: _selectedMonth,
      dueDate: _dueDate,
      categories: categories,
      totalFlats: totalFlats,
      residents: residents,
      notificationProvider: context.read<NotificationProvider>(),
    );

    if (!mounted) return;
    final totalAmount = _computedTotal(residents, totalFlats);
    AppUtils.showSnackBar(
      context,
      '$_selectedMonth bill created for ${residents.length} residents! '
      '(${AppUtils.formatCurrency(totalAmount / totalFlats)}/flat avg)',
      color: AppColors.green,
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final aptId = auth.currentUser?.apartmentId ?? '';
    final apt = context.read<ApartmentProvider>().findById(aptId);
    final residents = context.read<UserProvider>().membersForApartment(aptId);
    final theme = RoleTheme.of(UserRole.admin);
    final totalFlats = apt?.totalFlats ?? residents.length;
    final totalAmount = _computedTotal(residents, totalFlats);
    final perFlatAvg = totalFlats > 0 ? totalAmount / totalFlats : 0.0;

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

              const SizedBox(height: 20),

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

              // Bill categories
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SectionLabel('Bill Categories'),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _lineItems.add(_LineItem()));
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
                return _buildLineItemCard(
                    idx, item, residents, totalFlats, theme.primary);
              }),

              // Total summary
              if (totalAmount > 0) ...[
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
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    'Total ${AppUtils.formatCurrency(totalAmount)} · avg ',
                              ),
                              TextSpan(
                                text: AppUtils.formatCurrency(perFlatAvg),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.primary,
                                  fontSize: 15,
                                ),
                              ),
                              const TextSpan(text: '/flat'),
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
                  onPressed: () => _submit(residents, totalFlats, aptId),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineItemCard(
      int idx, _LineItem item, List<UserModel> residents, int totalFlats, Color primary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Text('Item ${idx + 1}',
                    style: AppTextStyles.label(color: primary)
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
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category dropdown
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
                          Icons.keyboard_arrow_down_rounded, size: 20),
                      items: _categories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => item.category = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Type toggle: Common / Hybrid
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      _TypeChip(
                        label: 'Common',
                        sublabel: 'Split equally',
                        isActive: item.type == 'common',
                        color: primary,
                        onTap: () => setState(() => item.type = 'common'),
                      ),
                      _TypeChip(
                        label: 'Hybrid',
                        sublabel: 'Default + overrides',
                        isActive: item.type == 'hybrid',
                        color: primary,
                        onTap: () => setState(() => item.type = 'hybrid'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Description
                TextFormField(
                  controller: item.titleCtrl,
                  style: AppTextStyles.bodyLarge(),
                  decoration: InputDecoration(
                    hintText: 'Description (e.g., Water Charges)',
                    hintStyle: AppTextStyles.bodyMedium(),
                    prefixIcon:
                        const Icon(Icons.receipt_outlined, size: 18),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter description' : null,
                ),
                const SizedBox(height: 8),

                // Amount field
                TextFormField(
                  controller: item.amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  style: AppTextStyles.bodyLarge(),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: item.type == 'common'
                        ? 'Total amount (₹)'
                        : 'Default per flat (₹)',
                    hintStyle: AppTextStyles.bodyMedium(),
                    prefixIcon: const Icon(
                        Icons.currency_rupee_outlined, size: 18),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter amount';
                    final a = double.tryParse(v);
                    if (a == null || a < 0) return 'Enter valid amount';
                    return null;
                  },
                ),

                // Hybrid: override section toggle + per-resident inputs
                if (item.type == 'hybrid') ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setState(
                        () => item.showOverrides = !item.showOverrides),
                    child: Row(
                      children: [
                        Icon(
                          item.showOverrides
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                          color: primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.showOverrides
                              ? 'Hide custom amounts'
                              : 'Set custom amounts (optional)',
                          style: AppTextStyles.label(color: primary),
                        ),
                      ],
                    ),
                  ),
                  if (item.showOverrides) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Leave blank to use the default amount above',
                      style: AppTextStyles.caption(
                          color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    ...residents.map((r) {
                      item.overrideCtrls.putIfAbsent(
                          r.id, () => TextEditingController());
                      final ctrl = item.overrideCtrls[r.id]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  r.avatarInitials,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(r.name,
                                      style: AppTextStyles.bodyMedium(
                                              color: AppColors.textPrimary)
                                          .copyWith(
                                              fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text('Unit ${r.unit}',
                                      style: AppTextStyles.caption()),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: TextFormField(
                                controller: ctrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                textAlign: TextAlign.right,
                                style: AppTextStyles.bodyLarge().copyWith(
                                    fontWeight: FontWeight.w600),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: item.amountCtrl.text.isEmpty
                                      ? '₹0'
                                      : '₹${item.amountCtrl.text}',
                                  hintStyle: AppTextStyles.bodyMedium(
                                      color: AppColors.textSecondary),
                                  prefixText: ctrl.text.isEmpty ? '' : '₹',
                                  prefixStyle: AppTextStyles.bodyMedium(
                                      color: AppColors.textSecondary),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 8),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: Colors.grey.shade300),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return null;
                                  final a = double.tryParse(v);
                                  if (a == null || a < 0) return 'Invalid';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ],
            ),
          ),
        ],
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

class _TypeChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.sublabel,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? color : AppColors.textSecondary,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 9,
                  color: isActive
                      ? color.withOpacity(0.7)
                      : AppColors.textSecondary.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
