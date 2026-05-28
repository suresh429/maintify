import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/bill_model.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/status_chip.dart';

class MarkPaidScreen extends StatefulWidget {
  const MarkPaidScreen({super.key});

  @override
  State<MarkPaidScreen> createState() => _MarkPaidScreenState();
}

class _MarkPaidScreenState extends State<MarkPaidScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final aptId = auth.currentUser?.apartmentId ?? 'apt1';
    final theme = RoleTheme.of(UserRole.admin);
    final billProvider = context.watch<BillProvider>();

    final allBills = billProvider.billsForApartment(aptId);
    final pendingBills = allBills
        .where((b) => billProvider.paymentsForBill(b.id).any((p) => !p.isPaid))
        .where((b) =>
            _search.isEmpty ||
            b.title.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    final fullyPaidBills = allBills
        .where((b) {
          final payments = billProvider.paymentsForBill(b.id);
          return payments.isNotEmpty && payments.every((p) => p.isPaid);
        })
        .where((b) =>
            _search.isEmpty ||
            b.title.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search bills...',
              hintStyle: AppTextStyles.bodyMedium(),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textSecondary),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                ),
              ],
            ),
            child: TabBar(
              controller: _tabCtrl,
              labelStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              indicator: BoxDecoration(
                gradient: LinearGradient(colors: theme.gradient),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                Tab(text: 'Pending (${pendingBills.length})'),
                Tab(text: 'Paid (${fullyPaidBills.length})'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _BillPaymentList(
                bills: pendingBills,
                billProvider: billProvider,
                showMarkPaid: true,
                isLoading: billProvider.isLoading,
                emptyTitle: 'All Collected!',
                emptySubtitle: 'No pending payments',
                emptyIcon: Icons.check_circle_outline,
              ),
              _BillPaymentList(
                bills: fullyPaidBills,
                billProvider: billProvider,
                showMarkPaid: false,
                isLoading: billProvider.isLoading,
                emptyTitle: 'No Fully Paid Bills',
                emptySubtitle: 'Bills will appear here when all flats pay',
                emptyIcon: Icons.receipt_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BillPaymentList extends StatelessWidget {
  final List<BillModel> bills;
  final BillProvider billProvider;
  final bool showMarkPaid;
  final bool isLoading;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;

  const _BillPaymentList({
    required this.bills,
    required this.billProvider,
    required this.showMarkPaid,
    required this.isLoading,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty) {
      return EmptyState(
          title: emptyTitle, subtitle: emptySubtitle, icon: emptyIcon);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: bills.length,
      itemBuilder: (_, i) => _BillPaymentCard(
        bill: bills[i],
        billProvider: billProvider,
        showMarkPaid: showMarkPaid,
        isLoading: isLoading,
      ),
    );
  }
}

class _BillPaymentCard extends StatelessWidget {
  final BillModel bill;
  final BillProvider billProvider;
  final bool showMarkPaid;
  final bool isLoading;

  const _BillPaymentCard({
    required this.bill,
    required this.billProvider,
    required this.showMarkPaid,
    required this.isLoading,
  });

  Future<void> _markPaid(BuildContext context, BillPayment payment) async {
    final confirm = await AppUtils.showConfirmDialog(
      context,
      title: 'Mark as Paid',
      message:
          'Mark "${bill.title}" for ${payment.unitNumber} as paid?\n\nAmount: ${AppUtils.formatCurrency(bill.perFlatShare)}',
      confirmText: 'Mark Paid',
      confirmColor: AppColors.green,
    );
    if (confirm != true) return;

    final bp = context.read<BillProvider>();
    await bp.adminMarkPaid(bill.id, payment.userId);
    if (!context.mounted) return;
    AppUtils.showSnackBar(context, 'Payment marked as paid!',
        color: AppColors.green);
  }

  @override
  Widget build(BuildContext context) {
    final payments = billProvider.paymentsForBill(bill.id);
    final paidCount = bill.paidFlats(payments);
    final theme = RoleTheme.of(UserRole.admin);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bill header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primary.withOpacity(0.08),
                  theme.primary.withOpacity(0.02),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bill.title,
                          style: AppTextStyles.subheading(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(
                        '${AppUtils.formatCurrency(bill.totalAmount)} total · ${AppUtils.formatCurrency(bill.perFlatShare)}/flat · Due ${AppUtils.formatDate(bill.dueDate)}',
                        style: AppTextStyles.caption(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$paidCount/${bill.totalFlats}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        color: paidCount == bill.totalFlats
                            ? AppColors.green
                            : theme.primary,
                        fontSize: 16,
                      ),
                    ),
                    Text('flats paid', style: AppTextStyles.caption()),
                  ],
                ),
              ],
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: bill.totalFlats == 0
                    ? 0
                    : paidCount / bill.totalFlats,
                backgroundColor: AppColors.lightGray,
                valueColor: AlwaysStoppedAnimation<Color>(
                    paidCount == bill.totalFlats
                        ? AppColors.green
                        : theme.primary),
                minHeight: 6,
              ),
            ),
          ),

          // Per-flat payment rows
          ...payments.map((payment) {
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: AppColors.lightGray, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(payment.unitNumber,
                        style: AppTextStyles.caption(color: AppColors.blue)
                            .copyWith(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (payment.paidDate != null)
                          Text(
                            'Paid on ${AppUtils.formatDate(payment.paidDate!)}',
                            style: AppTextStyles.caption(
                                color: AppColors.green),
                          ),
                        if (payment.transactionId != null)
                          Text(
                            payment.transactionId!,
                            style: AppTextStyles.caption(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!payment.isPaid && showMarkPaid)
                    GestureDetector(
                      onTap: isLoading ? null : () => _markPaid(context, payment),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.green, AppColors.teal],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Mark Paid',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else
                    StatusChip(status: payment.status),
                ],
              ),
            );
          }),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
