import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bill_model.dart';
import '../../models/user_model.dart';
import '../../providers/bill_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/common_button.dart';

/// Opens the edit bill as a full-screen page.
void showEditBillSheet(
  BuildContext context, {
  required BillModel bill,
  required List<UserModel> residents,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _EditBillPage(bill: bill, residents: residents),
    ),
  );
}

class _EditBillPage extends StatelessWidget {
  final BillModel bill;
  final List<UserModel> residents;
  const _EditBillPage({required this.bill, required this.residents});

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.admin);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Bill',
                style: AppTextStyles.heading3(color: Colors.white)),
            Text(
              bill.month,
              style: AppTextStyles.caption(
                  color: Colors.white.withOpacity(0.8)),
            ),
          ],
        ),
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
      body: SafeArea(child: _EditBillContent(bill: bill, residents: residents)),
    );
  }
}

// ── Editable line item ──────────────────────────────────────────────────────

class _EditLineItem {
  final TextEditingController titleCtrl;
  final TextEditingController amountCtrl;
  String category;
  String type; // 'common' | 'hybrid'
  bool showOverrides;
  final Map<String, TextEditingController> overrideCtrls;

  _EditLineItem({
    required String title,
    required double amount,
    required this.category,
    required this.type,
    Map<String, double> prefilledOverrides = const {},
  })  : titleCtrl = TextEditingController(text: title),
        amountCtrl = TextEditingController(
            text: amount == 0 ? '' : amount.toStringAsFixed(0)),
        showOverrides = prefilledOverrides.isNotEmpty,
        overrideCtrls = {} {
    for (final entry in prefilledOverrides.entries) {
      overrideCtrls[entry.key] =
          TextEditingController(text: entry.value.toStringAsFixed(0));
    }
  }

  void dispose() {
    titleCtrl.dispose();
    amountCtrl.dispose();
    for (final c in overrideCtrls.values) { c.dispose(); }
  }
}

// ── Sheet content ───────────────────────────────────────────────────────────

class _EditBillContent extends StatefulWidget {
  final BillModel bill;
  final List<UserModel> residents;

  const _EditBillContent({
    required this.bill,
    required this.residents,
  });

  @override
  State<_EditBillContent> createState() => _EditBillContentState();
}

class _EditBillContentState extends State<_EditBillContent> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _dueDate;
  late List<_EditLineItem> _lineItems;
  late Set<String> _excludedUserIds;

  static const _categories = [
    'Maintenance', 'Water', 'Lift', 'Security',
    'Parking', 'Amenities', 'Garbage', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _dueDate = widget.bill.dueDate;
    _excludedUserIds = Set.from(widget.bill.excludedUserIds);

    if (widget.bill.categories.isNotEmpty) {
      _lineItems = widget.bill.categories.map((cat) {
        final catName =
            _categories.contains(cat.name) ? cat.name : 'Other';
        return _EditLineItem(
          title: cat.name,
          amount:
              cat.type == 'common' ? cat.totalAmount : cat.defaultAmount,
          category: catName,
          type: cat.type == 'hybrid' ? 'hybrid' : 'common',
          prefilledOverrides: cat.userOverrides,
        );
      }).toList();
    } else {
      _lineItems = [
        _EditLineItem(
          title: widget.bill.title,
          amount: widget.bill.totalAmount,
          category: 'Maintenance',
          type: 'common',
        )
      ];
    }
  }

  @override
  void dispose() {
    for (final item in _lineItems) { item.dispose(); }
    super.dispose();
  }

  // ── Live summary ────────────────────────────────────────────────────────

  ({double total, double perFlat, int eligible, int excluded}) get _summary {
    final excluded = _excludedUserIds;
    final eligible = widget.residents
        .where((r) => !excluded.contains(r.id))
        .toList();
    final eligibleCount =
        eligible.isEmpty ? widget.bill.totalFlats : eligible.length;

    double total = 0;
    for (final item in _lineItems) {
      final amount = double.tryParse(item.amountCtrl.text) ?? 0;
      if (item.type == 'common') {
        total += amount;
      } else {
        for (final r in eligible) {
          final overrideText =
              item.overrideCtrls[r.id]?.text.trim() ?? '';
          final override = double.tryParse(overrideText);
          total += override ?? amount;
        }
      }
    }
    final perFlat = eligibleCount > 0 ? total / eligibleCount : 0.0;
    return (
      total: total,
      perFlat: perFlat,
      eligible: eligible.isEmpty
          ? widget.bill.totalFlats
          : eligible.length,
      excluded: excluded.length,
    );
  }

  // ── Date picker ─────────────────────────────────────────────────────────

  Future<void> _pickDate(Color accent) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  // ── Submit ──────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final residents = widget.residents;
    final eligible = residents
        .where((r) => !_excludedUserIds.contains(r.id))
        .toList();

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
      } else {
        final userOverrides = <String, double>{};
        double hybridTotal = 0;
        for (final r in eligible) {
          final overrideText =
              item.overrideCtrls[r.id]?.text.trim() ?? '';
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
      }
    }

    await context.read<BillProvider>().adminEditBill(
          billId: widget.bill.id,
          categories: categories,
          dueDate: _dueDate,
          residents: residents,
          excludedUserIds: _excludedUserIds.toList(),
        );

    if (!mounted) return;
    AppUtils.showSnackBar(context, '${widget.bill.month} bill updated',
        color: AppColors.paid);
    Navigator.pop(context);
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = RoleTheme.of(UserRole.admin).effectivePrimary(context);
    final s = _summary;

    return Form(
      key: _formKey,
      child: CustomScrollView(
        slivers: [
          // ── Bill items ────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionRow(
                    'Bill Items',
                    cs,
                    trailing: TextButton.icon(
                      onPressed: () => setState(() =>
                          _lineItems.add(_EditLineItem(
                            title: '',
                            amount: 0,
                            category: 'Maintenance',
                            type: 'common',
                          ))),
                      icon: Icon(Icons.add_rounded,
                          size: 16, color: accent),
                      label: Text('Add Item',
                          style: AppTextStyles.label(color: accent)),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._lineItems.asMap().entries.map(
                        (e) => _buildItemCard(e.key, e.value, cs, isDark, accent),
                      ),
                ],
              ),
            ),
          ),

          // ── Excluded users ────────────────────────────────────────────
          if (widget.residents.isNotEmpty)
            SliverPadding(
              padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _buildExcludedSection(cs, isDark, accent),
              ),
            ),

          // ── Live summary ──────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _buildSummaryCard(s, accent),
            ),
          ),

          // ── Due date ──────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(child: _buildDueDateRow(cs, isDark, accent)),
          ),

          // ── Save button ───────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            sliver: SliverToBoxAdapter(
              child: Consumer<BillProvider>(
                builder: (_, bp, __) => CommonButton(
                  text: 'Save Changes',
                  gradient: RoleTheme.of(UserRole.admin).gradient,
                  icon: Icons.check_circle_outline,
                  isLoading: bp.isLoading,
                  onPressed: _submit,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header row ──────────────────────────────────────────────────

  Widget _sectionRow(String title, ColorScheme cs, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTextStyles.subheading(color: cs.onSurface),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // ── Bill item card ──────────────────────────────────────────────────────

  Widget _buildItemCard(int idx, _EditLineItem item, ColorScheme cs, bool isDark, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row: "Item N" + delete ────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Item ${idx + 1}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
              const Spacer(),
              if (_lineItems.length > 1)
                GestureDetector(
                  onTap: () => setState(() {
                    _lineItems[idx].dispose();
                    _lineItems.removeAt(idx);
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.overdue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.overdue,
                        size: 16),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Category dropdown ─────────────────────────────────────────
          _fieldLabel('Category', cs),
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: item.category,
                isExpanded: true,
                isDense: true,
                dropdownColor: cs.surface,
                style: AppTextStyles.bodyMedium(color: cs.onSurface),
                icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: cs.onSurfaceVariant),
                items: _categories
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => item.category = v!),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Type toggle ───────────────────────────────────────────────
          _fieldLabel('Split Type', cs),
          const SizedBox(height: 6),
          Row(
            children: [
              _typeToggle(
                label: 'Common',
                icon: Icons.group_outlined,
                sublabel: 'Split equally',
                isActive: item.type == 'common',
                onTap: () => setState(() => item.type = 'common'),
                cs: cs,
                accent: accent,
              ),
              const SizedBox(width: 8),
              _typeToggle(
                label: 'Hybrid',
                icon: Icons.tune_outlined,
                sublabel: 'Default + overrides',
                isActive: item.type == 'hybrid',
                onTap: () => setState(() => item.type = 'hybrid'),
                cs: cs,
                accent: accent,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Description ───────────────────────────────────────────────
          _fieldLabel('Description', cs),
          const SizedBox(height: 6),
          TextFormField(
            controller: item.titleCtrl,
            style: AppTextStyles.bodyLarge(color: cs.onSurface),
            decoration: _inputDecor(
              hint: 'e.g. Water Charges, Lift Maintenance',
              icon: Icons.receipt_long_outlined,
              cs: cs,
              accent: accent,
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter description' : null,
          ),
          const SizedBox(height: 12),

          // ── Amount ────────────────────────────────────────────────────
          _fieldLabel(item.type == 'common'
              ? 'Total Amount (₹)'
              : 'Default Per Flat (₹)', cs),
          const SizedBox(height: 6),
          TextFormField(
            controller: item.amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.bodyLarge(color: cs.onSurface),
            onChanged: (_) => setState(() {}),
            decoration: _inputDecor(
              hint: item.type == 'common'
                  ? 'Total for all flats'
                  : 'Amount per flat (default)',
              icon: Icons.currency_rupee_outlined,
              cs: cs,
              accent: accent,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter amount';
              final a = double.tryParse(v);
              if (a == null || a < 0) return 'Enter valid amount';
              return null;
            },
          ),

          // ── Hybrid overrides ──────────────────────────────────────────
          if (item.type == 'hybrid') ...[
            const SizedBox(height: 12),
            _buildHybridSection(item, cs, accent),
          ],
        ],
      ),
    );
  }

  // ── Hybrid override section ─────────────────────────────────────────────

  Widget _buildHybridSection(_EditLineItem item, ColorScheme cs, Color accent) {
    final defaultAmt = double.tryParse(item.amountCtrl.text) ?? 0;
    final eligible = widget.residents
        .where((r) => !_excludedUserIds.contains(r.id))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: "Custom Amounts" + toggle
          InkWell(
            onTap: () =>
                setState(() => item.showOverrides = !item.showOverrides),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.tune_outlined,
                      size: 16, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Custom Amounts',
                            style: AppTextStyles.label(color: cs.onSurface)
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text(
                          'Default: ${AppUtils.formatCurrency(defaultAmt)} · Tap to override per resident',
                          style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    item.showOverrides
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: accent,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (item.showOverrides) ...[
            Divider(height: 1, indent: 12, endIndent: 12, color: cs.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  // Column headers
                  Row(
                    children: [
                      Expanded(
                          child: Text('Resident',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ))),
                      SizedBox(
                          width: 90,
                          child: Text('Amount (₹)',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...eligible.map((r) {
                    item.overrideCtrls.putIfAbsent(
                        r.id, () => TextEditingController());
                    final ctrl = item.overrideCtrls[r.id]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Center(
                              child: Text(
                                r.avatarInitials,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: accent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(r.name,
                                    style: AppTextStyles.bodySmall(
                                            color: cs.onSurface)
                                        .copyWith(
                                            fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                Text('Unit ${r.unit}',
                                    style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
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
                              style: AppTextStyles.bodyMedium(
                                      color: cs.onSurface)
                                  .copyWith(fontWeight: FontWeight.w600),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: defaultAmt == 0
                                    ? '₹0'
                                    : defaultAmt.toStringAsFixed(0),
                                hintStyle: AppTextStyles.bodyMedium(
                                    color: cs.onSurfaceVariant),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                isDense: true,
                                filled: true,
                                fillColor: cs.surface,
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: cs.outlineVariant),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: cs.outlineVariant),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: accent),
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
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Excluded users section ──────────────────────────────────────────────

  Widget _buildExcludedSection(ColorScheme cs, bool isDark, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_remove_outlined,
                  size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('Exclude Residents', style: AppTextStyles.subheading(color: cs.onSurface)),
              const Spacer(),
              if (_excludedUserIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.overdue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_excludedUserIds.length} excluded',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.overdue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Excluded residents pay ₹0 and are not counted in the split.',
              style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.residents.map((r) {
              final isExcluded = _excludedUserIds.contains(r.id);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isExcluded) {
                    _excludedUserIds.remove(r.id);
                  } else {
                    _excludedUserIds.add(r.id);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isExcluded
                        ? AppColors.overdue.withOpacity(0.08)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isExcluded
                          ? AppColors.overdue.withOpacity(0.3)
                          : cs.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isExcluded) ...[
                        const Icon(Icons.close_rounded,
                            size: 13, color: AppColors.overdue),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        r.name.split(' ').first,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isExcluded
                              ? AppColors.overdue
                              : cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        r.unit,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          color: isExcluded
                              ? AppColors.overdue.withOpacity(0.6)
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Live summary card ───────────────────────────────────────────────────

  Widget _buildSummaryCard(
      ({double total, double perFlat, int eligible, int excluded}) s, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: RoleTheme.of(UserRole.admin).gradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Live Summary',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryItem('Total', AppUtils.formatCurrency(s.total)),
              _summaryDivider(),
              _summaryItem('Per Flat', AppUtils.formatCurrency(s.perFlat)),
              _summaryDivider(),
              _summaryItem('Eligible', '${s.eligible} flats'),
              if (s.excluded > 0) ...[
                _summaryDivider(),
                _summaryItem('Excluded', '${s.excluded}',
                    color: Colors.orange.shade300),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, {Color? color}) =>
      Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color ?? Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9,
                color: Colors.white.withOpacity(0.75),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _summaryDivider() => Container(
        width: 1,
        height: 28,
        color: Colors.white.withOpacity(0.25),
      );

  // ── Due date row ────────────────────────────────────────────────────────

  Widget _buildDueDateRow(ColorScheme cs, bool isDark, Color accent) {
    return GestureDetector(
      onTap: () => _pickDate(accent),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.calendar_today_outlined,
                  size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Due Date', style: AppTextStyles.label(color: cs.onSurfaceVariant)),
                  Text(AppUtils.formatDate(_dueDate),
                      style: AppTextStyles.bodyLarge(color: cs.onSurface)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Widget _fieldLabel(String text, ColorScheme cs) => Text(
        text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant,
        ),
      );

  InputDecoration _inputDecor({
    required String hint,
    required IconData icon,
    required ColorScheme cs,
    required Color accent,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium(color: cs.onSurfaceVariant),
        prefixIcon: Icon(icon, size: 18, color: cs.onSurfaceVariant),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.overdue),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.overdue),
        ),
      );

  Widget _typeToggle({
    required String label,
    required IconData icon,
    required String sublabel,
    required bool isActive,
    required VoidCallback onTap,
    required ColorScheme cs,
    required Color accent,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color:
                isActive ? accent : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color:
                      isActive ? Colors.white : cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? Colors.white
                          : cs.onSurface,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      color: isActive
                          ? Colors.white.withOpacity(0.8)
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
