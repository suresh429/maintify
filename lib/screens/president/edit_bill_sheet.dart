import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bill_model.dart';
import '../../models/user_model.dart';
import '../../providers/bill_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';

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

// ── Editable line item ──────────────────────────────────────────────────────

class _EditLineItem {
  final TextEditingController amountCtrl;
  String category;
  String type; // 'common' | 'hybrid'
  Set<String> applicableResidentIds;

  _EditLineItem({
    required double amount,
    required this.category,
    required this.type,
    Set<String>? applicableResidentIds,
  })  : amountCtrl = TextEditingController(
            text: amount == 0 ? '' : amount.toStringAsFixed(0)),
        applicableResidentIds = applicableResidentIds ?? {};

  void dispose() {
    amountCtrl.dispose();
  }
}

// ── Edit Bill Page ──────────────────────────────────────────────────────────

class _EditBillPage extends StatefulWidget {
  final BillModel bill;
  final List<UserModel> residents;
  const _EditBillPage({required this.bill, required this.residents});

  @override
  State<_EditBillPage> createState() => _EditBillPageState();
}

class _EditBillPageState extends State<_EditBillPage> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _dueDate;
  late List<_EditLineItem> _lineItems;
  late Set<String> _excludedUserIds;

  static const _categories = [
    'Maintenance',
    'Electricity Bill',
    'Water Bill',
    'GHMC Garbage',
    'Watchman Salary',
    'Lift Maintenance',
    'CCTV Bill',
    'Security',
    'Parking',
    'Amenities',
    'Internet',
    'Garbage',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _dueDate = widget.bill.dueDate;
    _excludedUserIds = Set.from(widget.bill.excludedUserIds);

    if (widget.bill.categories.isNotEmpty) {
      _lineItems = widget.bill.categories.map((cat) {
        final catName = _categories.contains(cat.name) ? cat.name : 'Other';
        Set<String>? applicable;
        if (cat.type == 'hybrid') {
          applicable = cat.applicableResidentIds.isNotEmpty
              ? cat.applicableResidentIds.toSet()
              : widget.residents.map((r) => r.id).toSet();
        }
        return _EditLineItem(
          amount: cat.type == 'common' ? cat.totalAmount : cat.defaultAmount,
          category: catName,
          type: cat.type == 'hybrid' ? 'hybrid' : 'common',
          applicableResidentIds: applicable,
        );
      }).toList();
    } else {
      _lineItems = [
        _EditLineItem(
          amount: widget.bill.totalAmount,
          category: 'Maintenance',
          type: 'common',
        )
      ];
    }
  }

  @override
  void dispose() {
    for (final item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  // ── Live summary ────────────────────────────────────────────────────────

  ({double total, double perFlat, int eligible, int excluded}) get _summary {
    final excluded = _excludedUserIds;
    final eligible =
        widget.residents.where((r) => !excluded.contains(r.id)).toList();
    final eligibleCount =
        eligible.isEmpty ? widget.bill.totalFlats : eligible.length;

    double total = 0;
    for (final item in _lineItems) {
      final amount = double.tryParse(item.amountCtrl.text) ?? 0;
      if (item.type == 'common') {
        total += amount;
      } else {
        final applicableCount = item.applicableResidentIds
            .where((id) => !excluded.contains(id))
            .length;
        total += applicableCount * amount;
      }
    }
    final perFlat = eligibleCount > 0 ? total / eligibleCount : 0.0;
    return (
      total: total,
      perFlat: perFlat,
      eligible: eligible.isEmpty ? widget.bill.totalFlats : eligible.length,
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

    final categories = <BillCategory>[];
    for (final item in _lineItems) {
      final amount = double.parse(item.amountCtrl.text.trim());

      if (item.type == 'common') {
        categories.add(BillCategory(
          name: item.category,
          type: 'common',
          totalAmount: amount,
        ));
      } else {
        final applicableNonExcluded = item.applicableResidentIds
            .where((id) => !_excludedUserIds.contains(id))
            .toList();
        final hybridTotal = applicableNonExcluded.length * amount;
        categories.add(BillCategory(
          name: item.category,
          type: 'hybrid',
          totalAmount: hybridTotal,
          defaultAmount: amount,
          applicableResidentIds: applicableNonExcluded,
        ));
      }
    }

    await context.read<BillProvider>().adminEditBill(
          billId: widget.bill.id,
          categories: categories,
          dueDate: _dueDate,
          residents: widget.residents,
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
    final theme = RoleTheme.of(UserRole.president);
    final accent = theme.effectivePrimary(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = _summary;

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
              widget.bill.month,
              style: AppTextStyles.caption(
                  color: Colors.white.withValues(alpha: 0.8)),
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

      // ── Sticky bottom action bar ─────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              top: BorderSide(color: cs.outlineVariant, width: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── + Add Bill Item ────────────────────────────────────────────
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _lineItems.add(_EditLineItem(
                        amount: 0,
                        category: 'Maintenance',
                        type: 'common',
                      ))),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Bill Item',
                      style:
                          TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // ── Save Changes ───────────────────────────────────────────────
              Expanded(
                child: Consumer<BillProvider>(
                  builder: (_, bp, __) => FilledButton(
                    onPressed: bp.isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      disabledBackgroundColor:
                          accent.withValues(alpha: 0.4),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: bp.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Changes',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            )),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      body: SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              // ── Bill items ──────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Bill Items',
                            style:
                                AppTextStyles.label(color: cs.onSurface)
                                    .copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_lineItems.length} ${_lineItems.length == 1 ? 'Item' : 'Items'}',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._lineItems.asMap().entries.map(
                            (e) => _buildItemCard(
                                e.key, e.value, cs, isDark, accent),
                          ),
                    ],
                  ),
                ),
              ),

              // ── Excluded users ──────────────────────────────────────────────
              if (widget.residents.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _buildExcludedSection(cs, isDark, accent),
                  ),
                ),

              // ── Live summary ────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildSummaryCard(s, accent),
                ),
              ),

              // ── Due date ────────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverToBoxAdapter(
                    child: _buildDueDateRow(cs, isDark, accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bill item card ──────────────────────────────────────────────────────────

  Widget _buildItemCard(int idx, _EditLineItem item, ColorScheme cs,
      bool isDark, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header: tap to open category picker bottom sheet ───────────
          Container(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showCategoryPicker(
                      context: context,
                      current: item.category,
                      accent: accent,
                      onSelected: (v) => setState(() => item.category = v),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_categoryIcon(item.category),
                                size: 16, color: accent),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.category,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              size: 20, color: accent),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_lineItems.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _lineItems[idx].dispose();
                        _lineItems.removeAt(idx);
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.overdue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.overdue, size: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Card body ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Type toggle ──────────────────────────────────────────────
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
                      sublabel: 'Select applicable flats',
                      isActive: item.type == 'hybrid',
                      onTap: () => setState(() {
                        item.type = 'hybrid';
                        if (item.applicableResidentIds.isEmpty) {
                          item.applicableResidentIds = widget.residents
                              .where((r) => !_excludedUserIds.contains(r.id))
                              .map((r) => r.id)
                              .toSet();
                        }
                      }),
                      cs: cs,
                      accent: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Amount ───────────────────────────────────────────────────
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

                // ── Hybrid overrides ─────────────────────────────────────────
                if (item.type == 'hybrid') ...[
                  const SizedBox(height: 12),
                  _buildHybridSection(item, cs, accent),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Type toggle widget ──────────────────────────────────────────────────────

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
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isActive ? accent : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.25),
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
                  color: isActive ? Colors.white : cs.onSurfaceVariant),
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
                      color: isActive ? Colors.white : cs.onSurface,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.8)
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

  // ── Hybrid applicable flats section ────────────────────────────────────────

  Widget _buildHybridSection(
      _EditLineItem item, ColorScheme cs, Color accent) {
    final defaultAmt = double.tryParse(item.amountCtrl.text) ?? 0;
    final eligible = widget.residents
        .where((r) => !_excludedUserIds.contains(r.id))
        .toList();
    final applicableCount = item.applicableResidentIds
        .where((id) => !_excludedUserIds.contains(id))
        .length;
    final hybridTotal = applicableCount * defaultAmt;

    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Icon(Icons.tune_outlined, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Applicable Flats',
                          style: AppTextStyles.label(color: cs.onSurface)
                              .copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        'Only selected flats are charged. Others pay ₹0.',
                        style: AppTextStyles.caption(
                            color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Select All / Clear
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                _quickBtn(
                  label: 'Select All',
                  onTap: () => setState(() =>
                      item.applicableResidentIds =
                          widget.residents.map((r) => r.id).toSet()),
                  accent: accent,
                  cs: cs,
                ),
                const SizedBox(width: 8),
                _quickBtn(
                  label: 'Clear',
                  onTap: () =>
                      setState(() => item.applicableResidentIds = {}),
                  accent: accent,
                  cs: cs,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$applicableCount of ${eligible.length}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Per-resident rows
          ...eligible.map((r) {
            final isApplicable = item.applicableResidentIds.contains(r.id);
            return InkWell(
              onTap: () => setState(() {
                if (isApplicable) {
                  item.applicableResidentIds.remove(r.id);
                } else {
                  item.applicableResidentIds.add(r.id);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      isApplicable
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 20,
                      color: isApplicable ? accent : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name,
                              style: AppTextStyles.bodySmall(
                                      color: cs.onSurface)
                                  .copyWith(fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text('Unit ${r.unit}',
                              style: AppTextStyles.caption(
                                  color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Text(
                      isApplicable
                          ? AppUtils.formatCurrency(defaultAmt)
                          : '₹0',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isApplicable ? accent : cs.onSurfaceVariant,
                      ),
                    ),
                    if (!isApplicable) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              cs.onSurfaceVariant.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'N/A',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),

          // Total allocation
          if (defaultAmt > 0) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$applicableCount × ${AppUtils.formatCurrency(defaultAmt)}',
                    style:
                        AppTextStyles.caption(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    AppUtils.formatCurrency(hybridTotal),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickBtn({
    required String label,
    required VoidCallback onTap,
    required Color accent,
    required ColorScheme cs,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: accent,
          ),
        ),
      ),
    );
  }

  // ── Excluded users section ──────────────────────────────────────────────────

  Widget _buildExcludedSection(
      ColorScheme cs, bool isDark, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
              Text('Exclude Residents',
                  style: AppTextStyles.subheading(color: cs.onSurface)),
              const Spacer(),
              if (_excludedUserIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.overdue.withValues(alpha: 0.1),
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
          Text(
              'Excluded residents pay ₹0 and are not counted in the split.',
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
                        ? AppColors.overdue.withValues(alpha: 0.08)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isExcluded
                          ? AppColors.overdue.withValues(alpha: 0.3)
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
                              ? AppColors.overdue.withValues(alpha: 0.6)
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

  // ── Live summary card ───────────────────────────────────────────────────────

  Widget _buildSummaryCard(
      ({double total, double perFlat, int eligible, int excluded}) s,
      Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: RoleTheme.of(UserRole.president).gradient,
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
                color: Colors.white.withValues(alpha: 0.75),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _summaryDivider() => Container(
        width: 1,
        height: 28,
        color: Colors.white.withValues(alpha: 0.25),
      );

  // ── Due date row ────────────────────────────────────────────────────────────

  Widget _buildDueDateRow(
      ColorScheme cs, bool isDark, Color accent) {
    return GestureDetector(
      onTap: () => _pickDate(accent),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
                color: accent.withValues(alpha: 0.1),
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
                  Text('Due Date',
                      style: AppTextStyles.label(
                          color: cs.onSurfaceVariant)),
                  Text(AppUtils.formatDate(_dueDate),
                      style: AppTextStyles.bodyLarge(color: cs.onSurface)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // ── Input decoration helper ─────────────────────────────────────────────────

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

  // ── Category icon mapper ────────────────────────────────────────────────────

  static IconData _categoryIcon(String category) {
    switch (category) {
      case 'Maintenance':      return Icons.build_outlined;
      case 'Electricity Bill': return Icons.bolt_outlined;
      case 'Water Bill':       return Icons.water_drop_outlined;
      case 'GHMC Garbage':     return Icons.delete_outline_rounded;
      case 'Watchman Salary':  return Icons.security_outlined;
      case 'Lift Maintenance': return Icons.elevator_outlined;
      case 'CCTV Bill':        return Icons.videocam_outlined;
      case 'Security':         return Icons.shield_outlined;
      case 'Parking':          return Icons.local_parking_outlined;
      case 'Amenities':        return Icons.pool_outlined;
      case 'Internet':         return Icons.wifi_outlined;
      case 'Garbage':          return Icons.recycling_outlined;
      default:                 return Icons.category_outlined;
    }
  }

  // ── Category picker bottom sheet ────────────────────────────────────────────

  Future<void> _showCategoryPicker({
    required BuildContext context,
    required String current,
    required Color accent,
    required void Function(String) onSelected,
  }) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sheetCs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final maxHeight = MediaQuery.of(ctx).size.height * 0.55;
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Container(
              decoration: BoxDecoration(
                color: sheetCs.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetCs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title row
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Row(
                    children: [
                      Text('Select Category',
                          style: AppTextStyles.heading3(
                              color: sheetCs.onSurface)),
                      const Spacer(),
                      Text('${_categories.length} options',
                          style: AppTextStyles.caption(
                              color: sheetCs.onSurfaceVariant)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Category list — Flexible caps height at available space
                // and lets the list scroll internally when needed.
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: sheetCs.outlineVariant.withValues(alpha: 0.5)),
                    itemBuilder: (_, i) {
                      final cat = _categories[i];
                      final isSelected = cat == current;
                      return InkWell(
                        onTap: () => Navigator.pop(ctx, cat),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 13),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? accent.withValues(alpha: 0.12)
                                      : sheetCs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _categoryIcon(cat),
                                  size: 18,
                                  color: isSelected
                                      ? accent
                                      : sheetCs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? accent
                                        : sheetCs.onSurface,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle_rounded,
                                    color: accent, size: 22),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
    if (picked != null) onSelected(picked);
  }
}
