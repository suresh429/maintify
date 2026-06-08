import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/role_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/meeting_provider.dart';
import '../providers/notification_provider.dart';
import 'app_text_field.dart';

Future<bool> showScheduleMeetingSheet(BuildContext context) async {
  HapticFeedback.mediumImpact();
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useRootNavigator: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: const _ScheduleMeetingSheet(),
    ),
  );
  return result ?? false;
}

class _ScheduleMeetingSheet extends StatefulWidget {
  const _ScheduleMeetingSheet();

  @override
  State<_ScheduleMeetingSheet> createState() => _ScheduleMeetingSheetState();
}

class _ScheduleMeetingSheetState extends State<_ScheduleMeetingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);

  bool _isLoading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String get _formattedDate {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${_selectedDate.day} ${months[_selectedDate.month]} ${_selectedDate.year}';
  }

  String get _formattedTime {
    final hour =
        _selectedTime.hour % 12 == 0 ? 12 : _selectedTime.hour % 12;
    final min = _selectedTime.minute.toString().padLeft(2, '0');
    final period = _selectedTime.hour < 12 ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: RoleTheme.of(UserRole.admin).primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: RoleTheme.of(UserRole.admin).primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final meetingProvider = context.read<MeetingProvider>();
    final notificationProvider = context.read<NotificationProvider>();

    final scheduledAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    await meetingProvider.createMeeting(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      scheduledAt: scheduledAt,
      adminId: auth.currentUser?.id ?? 'u2',
      aptId: auth.currentUser?.apartmentId ?? 'apt1',
      notificationProvider: notificationProvider,
    );

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.admin);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 14, 24, 24 + bottomPad),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: theme.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.event_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Schedule Meeting',
                          style: AppTextStyles.heading3()),
                      Text('Notify all flat members',
                          style: AppTextStyles.caption()),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Title field
              AppTextField(
                label: 'Meeting Title',
                hint: 'e.g. Monthly Maintenance Review',
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                focusColor: theme.primary,
                prefixIcon: const Icon(Icons.title_rounded),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Description field
              AppTextField(
                label: 'Description',
                hint: 'What will be discussed?',
                controller: _descCtrl,
                textCapitalization: TextCapitalization.sentences,
                focusColor: theme.primary,
                maxLines: 3,
                prefixIcon: const Icon(Icons.notes_rounded),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Date & Time row
              Row(
                children: [
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: _formattedDate,
                      color: theme.primary,
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value: _formattedTime,
                      color: theme.primary,
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Info note
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: theme.primary.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_outlined,
                        color: theme.primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All flat members will receive a notification.',
                        style: AppTextStyles.caption(color: theme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Schedule button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: theme.gradient,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primary.withOpacity(0.32),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _isLoading ? null : _submit,
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.send_rounded,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Schedule & Notify',
                                    style: AppTextStyles.buttonText(
                                        color: Colors.white),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Cancel
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.buttonText(
                        color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.caption(
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: AppTextStyles.bodySmall(
                              color: AppColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, color: color, size: 14),
          ],
        ),
      ),
    );
  }
}
