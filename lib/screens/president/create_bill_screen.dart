import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bill_model.dart';
import '../../models/flat_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../providers/apartment_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/user_provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';

class CreateBillScreen extends StatefulWidget {
  const CreateBillScreen({super.key});

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

/// One billing line-item. type='common' splits total equally; type='hybrid'
/// charges defaultAmount to applicable flats only (₹0 for non-applicable).
class _LineItem {
  /// Key attached to the card widget — used for Scrollable.ensureVisible().
  final GlobalKey cardKey = GlobalKey();

  // common → total amount; hybrid → default per-applicable-flat amount
  final TextEditingController amountCtrl;
  String category;
  String type; // 'common' | 'hybrid'
  // For hybrid: which resident/flat IDs are applicable (pay defaultAmount).
  // Others pay ₹0. Empty set = none selected yet.
  Set<String> applicableResidentIds;

  _LineItem({String? category, String? type})
      : amountCtrl = TextEditingController(),
        category = category ?? 'Maintenance',
        type = type ?? 'common',
        applicableResidentIds = {};

  void dispose() {
    amountCtrl.dispose();
  }
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<_LineItem> _lineItems = [];
  final ScrollController _scrollCtrl = ScrollController();
  String _selectedMonth = '';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 10));

  /// All flats for this apartment — loaded once after mount.
  /// Includes unregistered flats (residentId == null) so they are billed too.
  List<FlatModel> _allFlats = [];

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
    _selectedMonth = AppUtils.formatMonthYear(DateTime.now());
    _lineItems.add(_LineItem()); // initial item — no scroll needed
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFlats());
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    for (final item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFlats() async {
    final aptId = context.read<AuthProvider>().currentUser?.apartmentId ?? '';
    if (aptId.isEmpty) return;
    final flats = await FirestoreService().getFlatsForApartment(aptId);
    if (mounted) setState(() => _allFlats = flats);
  }

  /// Adds a new bill item and smoothly scrolls to it.
  void _addLineItem() {
    setState(() => _lineItems.add(_LineItem()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _lineItems.last.cardKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  /// Computed total for the summary banner.
  double _computedTotal(List<UserModel> residents) {
    double total = 0;
    for (final item in _lineItems) {
      final amount = double.tryParse(item.amountCtrl.text) ?? 0;
      if (item.type == 'common') {
        total += amount;
      } else {
        // Hybrid: only applicable residents/flats contribute
        total += item.applicableResidentIds.length * amount;
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
      builder: (ctx, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(primary: Color(0xFF60A5FA))
                : const ColorScheme.light(primary: AppColors.blue),
          ),
          child: child!,
        );
      },
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
        final sheetCs = Theme.of(ctx).colorScheme;
        final sheetAccent = RoleTheme.of(UserRole.president).effectivePrimary(ctx);
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollCtrl) => Container(
            decoration: BoxDecoration(
              color: sheetCs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                          color: sheetCs.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Select Billing Month',
                          style: AppTextStyles.heading3(color: sheetCs.onSurface)),
                      const SizedBox(height: 4),
                      Text('Current month and past months only',
                          style: AppTextStyles.caption(color: sheetCs.onSurfaceVariant)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    padding: EdgeInsets.only(
                        bottom: 24 + MediaQuery.of(ctx).viewPadding.bottom),
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
                                ? sheetAccent.withValues(alpha: 0.1)
                                : sheetCs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.calendar_month_outlined,
                            size: 18,
                            color: isSelected ? sheetAccent : sheetCs.onSurfaceVariant,
                          ),
                        ),
                        title: Text(
                          label,
                          style: AppTextStyles.bodyLarge().copyWith(
                            color: isFuture ? sheetCs.onSurfaceVariant : sheetCs.onSurface,
                          ),
                        ),
                        subtitle: i == 0
                            ? Text('Current month',
                                style: AppTextStyles.caption(color: sheetAccent))
                            : null,
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: sheetAccent)
                            : null,
                        enabled: !isFuture,
                        onTap: () {
                          if (isFuture) {
                            AppUtils.showSnackBar(ctx, 'Future billing not allowed',
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
    final notificationProvider = context.read<NotificationProvider>();

    if (residents.isEmpty) {
      AppUtils.showSnackBar(context, 'No residents found in this apartment',
          isError: true);
      return;
    }

    // Validate hybrid categories have at least one applicable flat
    for (final item in _lineItems) {
      if (item.type == 'hybrid' && item.applicableResidentIds.isEmpty) {
        AppUtils.showSnackBar(
          context,
          'Select at least one applicable flat for "${item.category}"',
          isError: true,
        );
        return;
      }
    }

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

    // Build BillCategory list from line items.
    // The category dropdown value IS the bill name — no separate description needed.
    final categories = <BillCategory>[];
    for (final item in _lineItems) {
      final name = item.category; // dropdown is the single source of truth
      final amount = double.parse(item.amountCtrl.text.trim());

      if (item.type == 'common') {
        categories.add(BillCategory(
          name: name,
          type: 'common',
          totalAmount: amount,
        ));
        debugPrint('[FLOW] Category: $name, type=common, total=₹${amount.toStringAsFixed(0)}, '
            'per-flat=₹${(amount / totalFlats).toStringAsFixed(0)}');
      } else {
        // Hybrid: total = applicableCount × defaultAmount
        final applicableIds = item.applicableResidentIds.toList();
        final hybridTotal = applicableIds.length * amount;
        categories.add(BillCategory(
          name: name,
          type: 'hybrid',
          totalAmount: hybridTotal,
          defaultAmount: amount,
          applicableResidentIds: applicableIds,
        ));
        debugPrint('[FLOW] Category: $name, type=hybrid, default=₹${amount.toStringAsFixed(0)}, '
            'applicable=${applicableIds.length}, total=₹${hybridTotal.toStringAsFixed(0)}');
      }
    }

    // Fetch fresh flat list at submit time (in case _allFlats hasn't loaded yet).
    final flats = _allFlats.isNotEmpty
        ? _allFlats
        : await FirestoreService().getFlatsForApartment(aptId);

    await billProvider.createBillForMonth(
      apartmentId: aptId,
      adminId: auth.currentUser?.id ?? '',
      month: _selectedMonth,
      dueDate: _dueDate,
      categories: categories,
      totalFlats: totalFlats,
      residents: residents,
      allFlats: flats,
      notificationProvider: notificationProvider,
    );

    if (!mounted) return;
    final totalAmount = _computedTotal(residents);
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
    final theme = RoleTheme.of(UserRole.president);
    final accent = theme.effectivePrimary(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalFlats = apt?.totalFlats ?? residents.length;
    final totalAmount = _computedTotal(residents);
    final perFlatAvg = totalFlats > 0 ? totalAmount / totalFlats : 0.0;

    return Scaffold(
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

      // ── Sticky bottom action bar ─────────────────────────────────────────────
      // Placed in bottomNavigationBar so it stays above the keyboard and
      // system navigation bar while the bill list scrolls independently.
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
              // ── + Add Bill Item ──────────────────────────────────────────────
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addLineItem,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Bill Item',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
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
              // ── Create Bill ──────────────────────────────────────────────────
              Expanded(
                child: Consumer<BillProvider>(
                  builder: (_, bp, __) => FilledButton(
                    onPressed: bp.isLoading
                        ? null
                        : () => _submit(residents, totalFlats, aptId),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      disabledBackgroundColor: accent.withValues(alpha: 0.4),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: bp.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Create Bill',
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

      // ── Scrollable body ──────────────────────────────────────────────────────
      body: SingleChildScrollView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header banner ────────────────────────────────────────────────
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
                                color: Colors.white.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Month selector ───────────────────────────────────────────────
              _SectionLabel('Billing Month'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickMonth,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border.all(color: cs.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 20, color: cs.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Text(_selectedMonth,
                          style: AppTextStyles.bodyLarge(color: cs.onSurface)),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Bill categories header (no + button — it's in the sticky bar) ─
              Row(
                children: [
                  Text(
                    'Bill Categories',
                    style: AppTextStyles.label(color: cs.onSurface)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              const SizedBox(height: 8),

              // ── Bill item cards ──────────────────────────────────────────────
              ..._lineItems.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return _buildLineItemCard(
                    idx, item, residents, totalFlats, accent, cs, isDark);
              }),

              // ── Total summary banner ─────────────────────────────────────────
              if (totalAmount > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calculate_outlined, color: accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: cs.onSurface,
                            ),
                            children: [
                              TextSpan(
                                  text:
                                      'Total ${AppUtils.formatCurrency(totalAmount)} · avg '),
                              TextSpan(
                                text: AppUtils.formatCurrency(perFlatAvg),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: accent,
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

              // ── Due date ─────────────────────────────────────────────────────
              _SectionLabel('Due Date'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border.all(color: cs.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 20, color: cs.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Text(AppUtils.formatDate(_dueDate),
                          style:
                              AppTextStyles.bodyLarge(color: cs.onSurface)),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Residents summary ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          Icon(Icons.group_outlined, color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Will be sent to all residents',
                              style: AppTextStyles.label(
                                  color: cs.onSurface)),
                          Text(
                            '${residents.length} residents · ${apt?.name ?? 'Apartment'}',
                            style: AppTextStyles.caption(
                                color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Extra bottom padding so the last card clears the sticky bar.
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineItemCard(int idx, _LineItem item, List<UserModel> residents,
      int totalFlats, Color primary, ColorScheme cs, bool isDark) {
    return Container(
      key: item.cardKey, // required for Scrollable.ensureVisible
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
              color: primary.withValues(alpha: 0.06),
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
                      accent: primary,
                      onSelected: (v) => setState(() => item.category = v),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_categoryIcon(item.category),
                                size: 16, color: primary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.category,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              size: 20, color: primary),
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

          // ── Card body ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Common / Hybrid type toggle ───────────────────────────────
                Row(
                  children: [
                    _typeToggle(
                      label: 'Common',
                      icon: Icons.group_outlined,
                      sublabel: 'Split equally',
                      isActive: item.type == 'common',
                      onTap: () => setState(() => item.type = 'common'),
                      cs: cs,
                      accent: primary,
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
                          item.applicableResidentIds = {
                            ...residents.map((r) => r.id),
                            ..._allFlats
                                .where((f) => f.residentId == null)
                                .map((f) => f.id),
                          };
                        }
                      }),
                      cs: cs,
                      accent: primary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Amount field ─────────────────────────────────────────────
                TextFormField(
                  controller: item.amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: AppTextStyles.bodyLarge(color: cs.onSurface),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: item.type == 'common'
                        ? 'Total amount (₹)'
                        : 'Default per applicable flat (₹)',
                    hintStyle:
                        AppTextStyles.bodyMedium(color: cs.onSurfaceVariant),
                    prefixIcon: Icon(Icons.currency_rupee_outlined,
                        size: 18, color: cs.onSurfaceVariant),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
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
                      borderSide: BorderSide(color: primary, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.overdue),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.overdue),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter amount';
                    final a = double.tryParse(v);
                    if (a == null || a <= 0) return 'Enter valid amount';
                    return null;
                  },
                ),

                // ── Hybrid: applicable flats section ─────────────────────────
                if (item.type == 'hybrid') ...[
                  const SizedBox(height: 12),
                  _buildApplicableFlatsSection(
                      item, residents, _allFlats, primary, cs),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildApplicableFlatsSection(_LineItem item, List<UserModel> residents,
      List<FlatModel> allFlats, Color primary, ColorScheme cs) {
    final defaultAmt = double.tryParse(item.amountCtrl.text) ?? 0;

    // Unregistered flats = flats with no residentId that aren't already
    // covered by a registered resident in this apartment.
    final registeredIds = residents.map((r) => r.id).toSet();
    final unregisteredFlats = allFlats
        .where((f) =>
            f.residentId == null || !registeredIds.contains(f.residentId))
        .toList();

    final totalFlatCount = residents.length + unregisteredFlats.length;
    final applicableCount = item.applicableResidentIds.length;
    final hybridTotal = applicableCount * defaultAmt;

    return Container(
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Icon(Icons.tune_outlined, size: 16, color: primary),
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
                        style:
                            AppTextStyles.caption(color: cs.onSurfaceVariant),
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
                _quickSelectBtn(
                  label: 'Select All',
                  onTap: () => setState(() =>
                      item.applicableResidentIds = {
                        ...residents.map((r) => r.id),
                        ...unregisteredFlats.map((f) => f.id),
                      }),
                  primary: primary,
                  cs: cs,
                ),
                const SizedBox(width: 8),
                _quickSelectBtn(
                  label: 'Clear',
                  onTap: () =>
                      setState(() => item.applicableResidentIds = {}),
                  primary: primary,
                  cs: cs,
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$applicableCount of $totalFlatCount',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Registered residents
          ...residents.map((r) => _buildFlatCheckRow(
                id: r.id,
                name: r.name,
                unit: r.unit,
                isApplicable: item.applicableResidentIds.contains(r.id),
                isUnregistered: false,
                defaultAmt: defaultAmt,
                item: item,
                primary: primary,
                cs: cs,
              )),

          // Unregistered flats (resident hasn't signed up)
          ...unregisteredFlats.map((flat) => _buildFlatCheckRow(
                id: flat.id,
                name: 'Unregistered',
                unit: flat.flatNumber,
                isApplicable: item.applicableResidentIds.contains(flat.id),
                isUnregistered: true,
                defaultAmt: defaultAmt,
                item: item,
                primary: primary,
                cs: cs,
              )),

          // Total allocation footer
          if (defaultAmt > 0) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$applicableCount × ${AppUtils.formatCurrency(defaultAmt)}',
                    style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    AppUtils.formatCurrency(hybridTotal),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: primary,
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

  Widget _buildFlatCheckRow({
    required String id,
    required String name,
    required String unit,
    required bool isApplicable,
    required bool isUnregistered,
    required double defaultAmt,
    required _LineItem item,
    required Color primary,
    required ColorScheme cs,
  }) {
    return InkWell(
      onTap: () => setState(() {
        if (isApplicable) {
          item.applicableResidentIds.remove(id);
        } else {
          item.applicableResidentIds.add(id);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              isApplicable
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 20,
              color: isApplicable ? primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: AppTextStyles.bodySmall(color: cs.onSurface)
                              .copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnregistered) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Not signed up',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 9,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text('Unit $unit',
                      style:
                          AppTextStyles.caption(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Text(
              isApplicable ? AppUtils.formatCurrency(defaultAmt) : '₹0',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isApplicable ? primary : cs.onSurfaceVariant,
              ),
            ),
            if (!isApplicable) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.1),
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
  }

  Widget _quickSelectBtn({
    required String label,
    required VoidCallback onTap,
    required Color primary,
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
            color: primary,
          ),
        ),
      ),
    );
  }

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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style:
          AppTextStyles.label(color: Theme.of(context).colorScheme.onSurface)
              .copyWith(fontWeight: FontWeight.w600),
    );
  }
}

