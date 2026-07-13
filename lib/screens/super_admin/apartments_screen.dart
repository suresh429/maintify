import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_utils.dart';
import '../../models/apartment_model.dart';
import '../../providers/apartment_provider.dart';
import '../../providers/bill_provider.dart';
import 'create_apartment_screen.dart';

class ApartmentsScreen extends StatefulWidget {
  const ApartmentsScreen({super.key});

  @override
  State<ApartmentsScreen> createState() => _ApartmentsScreenState();
}

class _ApartmentsScreenState extends State<ApartmentsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final aptProvider = context.watch<ApartmentProvider>();
    final filtered = aptProvider.apartments
        .where((a) =>
            a.name.toLowerCase().contains(_search.toLowerCase()) ||
            a.code.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search apartments...',
              hintStyle: AppTextStyles.bodyMedium(),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textSecondary),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _search = ''),
                    )
                  : null,
            ),
          ),
        ),
        // Summary strip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _SummaryChip(
                label: '${aptProvider.apartments.length} Properties',
                color: AppColors.purple,
                icon: Icons.apartment_outlined,
              ),
              const SizedBox(width: 10),
              _SummaryChip(
                label:
                    '${aptProvider.apartments.fold(0, (s, a) => s + a.totalFlats)} Total Flats',
                color: AppColors.blue,
                icon: Icons.door_front_door_outlined,
              ),
              const Spacer(),
              // Create apartment FAB
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CreateApartmentScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.superAdminGradient,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (_, i) => _ApartmentDetailCard(apt: filtered[i]),
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _SummaryChip(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              )),
        ],
      ),
    );
  }
}

class _ApartmentDetailCard extends StatelessWidget {
  final ApartmentModel apt;
  const _ApartmentDetailCard({required this.apt});

  @override
  Widget build(BuildContext context) {
    final billProvider = context.watch<BillProvider>();
    final presidentName = apt.presidentName ?? 'Unassigned';
    final collected = billProvider.collectedForApartment(apt.id);
    final pending = billProvider.pendingForApartment(apt.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.purple.withOpacity(0.08),
                  AppColors.blue.withOpacity(0.04),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.apartment_rounded,
                      color: AppColors.purple, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(apt.name, style: AppTextStyles.subheading()),
                      Text(apt.code,
                          style: AppTextStyles.caption(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: apt.hasPresident
                        ? AppColors.green.withOpacity(0.1)
                        : AppColors.overdue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    apt.hasPresident ? 'Active' : 'No President',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: apt.hasPresident
                          ? AppColors.green
                          : AppColors.overdue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Flats + President row
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.door_front_door_outlined,
                        label: 'Total Flats',
                        value: '${apt.totalFlats}',
                        color: AppColors.blue,
                      ),
                    ),
                    Container(
                        width: 1, height: 36, color: AppColors.lightGray),
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.person_outline,
                        label: 'President',
                        value: presidentName,
                        color: apt.hasPresident
                            ? AppColors.textPrimary
                            : AppColors.overdue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Finance row
                Row(
                  children: [
                    Expanded(
                      child: _FinanceTile(
                        label: 'Collected',
                        value: AppUtils.formatCurrency(collected),
                        color: AppColors.green,
                      ),
                    ),
                    Container(
                        width: 1, height: 36, color: AppColors.lightGray),
                    Expanded(
                      child: _FinanceTile(
                        label: 'Pending',
                        value: AppUtils.formatCurrency(pending),
                        color: AppColors.pending,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(label, style: AppTextStyles.caption()),
            ],
          ),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _FinanceTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _FinanceTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              )),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption()),
        ],
      ),
    );
  }
}
