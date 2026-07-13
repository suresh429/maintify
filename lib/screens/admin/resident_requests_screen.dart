import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_utils.dart';
import '../../models/resident_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/registration_provider.dart';
import '../../providers/notification_provider.dart';

class ResidentRequestsScreen extends StatefulWidget {
  const ResidentRequestsScreen({super.key});

  @override
  State<ResidentRequestsScreen> createState() =>
      _ResidentRequestsScreenState();
}

class _ResidentRequestsScreenState extends State<ResidentRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final aptId = auth.currentUser?.apartmentId;
      if (aptId != null) {
        context.read<RegistrationProvider>().startListeningRequests(aptId);
      }
    });
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  String _avatarInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _approve(ResidentRequestModel req) async {
    final confirmed = await AppUtils.showConfirmDialog(
      context,
      title: 'Approve Request',
      message:
          'Approve ${req.name} for Flat ${req.unit}? They will be able to log in immediately.',
      confirmText: 'Approve',
      confirmColor: AppColors.paid,
    );
    if (confirmed != true || !mounted) return;

    final reg = context.read<RegistrationProvider>();
    final notif = context.read<NotificationProvider>();
    final success = await reg.approveRequest(req, notif);
    if (!mounted) return;

    if (success) {
      AppUtils.showSnackBar(
          context, '${req.name} approved successfully!');
    } else {
      AppUtils.showSnackBar(
          context, reg.error ?? 'Approval failed.', isError: true);
    }
  }

  Future<void> _reject(ResidentRequestModel req) async {
    final confirmed = await AppUtils.showConfirmDialog(
      context,
      title: 'Reject Request',
      message:
          'Reject registration request from ${req.name} (Flat ${req.unit})?',
      confirmText: 'Reject',
      confirmColor: AppColors.overdue,
    );
    if (confirmed != true || !mounted) return;

    final reg = context.read<RegistrationProvider>();
    final notif = context.read<NotificationProvider>();
    final success = await reg.rejectRequest(req, notif);
    if (!mounted) return;

    if (success) {
      AppUtils.showSnackBar(
          context, 'Request from ${req.name} has been rejected.');
    } else {
      AppUtils.showSnackBar(
          context, reg.error ?? 'Rejection failed.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Resident Requests',
            style: AppTextStyles.heading3(color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.adminGradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: Consumer<RegistrationProvider>(
        builder: (_, reg, __) {
          if (reg.isLoading && reg.pendingRequests.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = reg.pendingRequests;

          if (requests.isEmpty) {
            return _EmptyState();
          }

          return RefreshIndicator(
            color: AppColors.blue,
            onRefresh: () async {
              final auth = context.read<AuthProvider>();
              final aptId = auth.currentUser?.apartmentId;
              if (aptId != null) {
                reg.startListeningRequests(aptId);
              }
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary banner
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.adminGradient,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pending_actions_outlined,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        '${requests.length} pending request${requests.length == 1 ? '' : 's'} awaiting review',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ...requests.map((req) => _RequestCard(
                      request: req,
                      timeAgo: _timeAgo(req.requestedAt),
                      initials: _avatarInitials(req.name),
                      onApprove: () => _approve(req),
                      onReject: () => _reject(req),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final ResidentRequestModel request;
  final String timeAgo;
  final String initials;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({
    required this.request,
    required this.timeAgo,
    required this.initials,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.adminGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              request.name,
                              style: AppTextStyles.subheading(
                                      color: AppColors.textPrimary)
                                  .copyWith(fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(timeAgo, style: AppTextStyles.caption()),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _InfoRow(
                          icon: Icons.email_outlined, label: request.email),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoRow(
                                icon: Icons.phone_outlined,
                                label: request.phone),
                          ),
                          _FlatBadge(unit: request.unit),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, color: Colors.grey.shade100),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Reject button
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.overdue,
                      side: BorderSide(
                          color: AppColors.overdue.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: onReject,
                  ),
                ),
                const SizedBox(width: 10),

                // Approve button
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.paid,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: onApprove,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.caption(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _FlatBadge extends StatelessWidget {
  final String unit;

  const _FlatBadge({required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Flat $unit',
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.blue,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.blue.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox_outlined,
                size: 52,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: 20),
            Text('No Pending Requests',
                style: AppTextStyles.heading3(
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'All resident registration requests have been reviewed. New requests will appear here.',
              style: AppTextStyles.bodyMedium(),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
