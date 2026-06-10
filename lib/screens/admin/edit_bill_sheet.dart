import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bill_model.dart';
import '../../models/user_model.dart';
import '../../providers/bill_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/common_button.dart';

/// Opens the edit bill bottom sheet.
Future<void> showEditBillSheet(
  BuildContext context, {
  required BillModel bill,
  required List<UserModel> residents,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => _EditBillContent(
        bill: bill,
        residents: residents,
        scrollController: scrollCtrl,
      ),
    ),
  );
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
  final ScrollController scrollController;

  const _EditBillContent({
    required this.bill,
    required this.residents,
    required this.scrollController,
  });

  @override
  State<_EditBillContent> createState() => _EditBillContentState();
}

class _EditBillContentState extends State<_EditBillContent> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _dueDate;
  late List<_EditLineItem> _lineItems;
  late Set<String> _excludedUserIds;

  static const _primaryColor = AppColors.blue;
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme:
              const ColorScheme.light(primary: _primaryColor),
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
    final s = _summary;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: CustomScrollView(
          controller: widget.scrollController,
          slivers: [
            // ── Sticky header ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),

            // ── Bill items ────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionRow(
                      'Bill Items',
                      trailing: TextButton.icon(
                        onPressed: () => setState(() =>
                            _lineItems.add(_EditLineItem(
                              title: '',
                              amount: 0,
                              category: 'Maintenance',
                              type: 'common',
                            ))),
                        icon: const Icon(Icons.add_rounded,
                            size: 16, color: _primaryColor),
                        label: Text('Add Item',
                            style: AppTextStyles.label(
                                color: _primaryColor)),
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._lineItems.asMap().entries.map(
                          (e) => _buildItemCard(e.key, e.value),
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
                  child: _buildExcludedSection(),
                ),
              ),

            // ── Live summary ──────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _buildSummaryCard(s),
              ),
            ),

            // ── Due date ──────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(child: _buildDueDateRow()),
            ),

            // ── Save button ───────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              sliver: SliverToBoxAdapter(
                child: Consumer<BillProvider>(
                  builder: (_, bp, __) => CommonButton(
                    text: 'Save Changes',
                    gradient: const [_primaryColor, Color(0xFF0EA5E9)],
                    icon: Icons.check_circle_outline,
                    isLoading: bp.isLoading,
                    onPressed: _submit,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: AppColors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: _primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Bill',
                        style: AppTextStyles.heading3()),
                    Text(
                      widget.bill.month,
                      style: AppTextStyles.caption(
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Section header row ──────────────────────────────────────────────────

  Widget _sectionRow(String title, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTextStyles.subheading(),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // ── Bill item card ──────────────────────────────────────────────────────

  Widget _buildItemCard(int idx, _EditLineItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Item ${idx + 1}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
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
          _fieldLabel('Category'),
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
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
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => item.category = v!),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Type toggle ───────────────────────────────────────────────
          _fieldLabel('Split Type'),
          const SizedBox(height: 6),
          Row(
            children: [
              _typeToggle(
                label: 'Common',
                icon: Icons.group_outlined,
                sublabel: 'Split equally',
                isActive: item.type == 'common',
                onTap: () => setState(() => item.type = 'common'),
              ),
              const SizedBox(width: 8),
              _typeToggle(
                label: 'Hybrid',
                icon: Icons.tune_outlined,
                sublabel: 'Default + overrides',
                isActive: item.type == 'hybrid',
                onTap: () => setState(() => item.type = 'hybrid'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Description ───────────────────────────────────────────────
          _fieldLabel('Description'),
          const SizedBox(height: 6),
          TextFormField(
            controller: item.titleCtrl,
            style: AppTextStyles.bodyLarge(),
            decoration: _inputDecor(
              hint: 'e.g. Water Charges, Lift Maintenance',
              icon: Icons.receipt_long_outlined,
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter description' : null,
          ),
          const SizedBox(height: 12),

          // ── Amount ────────────────────────────────────────────────────
          _fieldLabel(item.type == 'common'
              ? 'Total Amount (₹)'
              : 'Default Per Flat (₹)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: item.amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: AppTextStyles.bodyLarge(),
            onChanged: (_) => setState(() {}),
            decoration: _inputDecor(
              hint: item.type == 'common'
                  ? 'Total for all flats'
                  : 'Amount per flat (default)',
              icon: Icons.currency_rupee_outlined,
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
            _buildHybridSection(item),
          ],
        ],
      ),
    );
  }

  // ── Hybrid override section ─────────────────────────────────────────────

  Widget _buildHybridSection(_EditLineItem item) {
    final defaultAmt = double.tryParse(item.amountCtrl.text) ?? 0;
    final eligible = widget.residents
        .where((r) => !_excludedUserIds.contains(r.id))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightGray,
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
                  const Icon(Icons.tune_outlined,
                      size: 16, color: _primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Custom Amounts',
                            style: AppTextStyles.label(
                                    color: AppColors.textPrimary)
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text(
                          'Default: ${AppUtils.formatCurrency(defaultAmt)} · Tap to override per resident',
                          style: AppTextStyles.caption(),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    item.showOverrides
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: _primaryColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (item.showOverrides) ...[
            const Divider(height: 1, indent: 12, endIndent: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  // Column headers
                  Row(
                    children: [
                      const Expanded(
                          child: Text('Resident',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ))),
                      const SizedBox(
                          width: 90,
                          child: Text('Amount (₹)',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                color: AppColors.textSecondary,
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
                              color: _primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Center(
                              child: Text(
                                r.avatarInitials,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryColor,
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
                              style: AppTextStyles.bodyMedium(
                                      color: AppColors.textPrimary)
                                  .copyWith(fontWeight: FontWeight.w600),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: defaultAmt == 0
                                    ? '₹0'
                                    : defaultAmt.toStringAsFixed(0),
                                hintStyle: AppTextStyles.bodyMedium(
                                    color: AppColors.textSecondary),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                isDense: true,
                                filled: true,
                                fillColor: AppColors.white,
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                      color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: _primaryColor),
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

  Widget _buildExcludedSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              const Icon(Icons.person_remove_outlined,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text('Exclude Residents', style: AppTextStyles.subheading()),
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
              style: AppTextStyles.caption()),
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
                        : AppColors.lightGray,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isExcluded
                          ? AppColors.overdue.withOpacity(0.3)
                          : Colors.grey.shade200,
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
                              : AppColors.textPrimary,
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
                              : AppColors.textSecondary,
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
      ({double total, double perFlat, int eligible, int excluded}) s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryColor.withOpacity(0.85),
            const Color(0xFF0EA5E9).withOpacity(0.85),
          ],
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

  Widget _buildDueDateRow() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_today_outlined,
                  size: 18, color: _primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Due Date', style: AppTextStyles.label()),
                  Text(AppUtils.formatDate(_dueDate),
                      style: AppTextStyles.bodyLarge()),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      );

  InputDecoration _inputDecor({required String hint, required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium(),
        prefixIcon: Icon(icon, size: 18),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: AppColors.lightGray,
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
          borderSide: const BorderSide(color: _primaryColor, width: 1.5),
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
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color:
                isActive ? _primaryColor : AppColors.lightGray,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.25),
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
                      isActive ? Colors.white : AppColors.textSecondary),
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
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      color: isActive
                          ? Colors.white.withOpacity(0.8)
                          : AppColors.textSecondary,
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
