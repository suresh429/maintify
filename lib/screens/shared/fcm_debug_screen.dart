import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/fcm_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Shows the device FCM token (full, selectable, copyable) and a guide for
/// testing all 9 Cloud Function push notification triggers.
class FcmDebugScreen extends StatefulWidget {
  const FcmDebugScreen({super.key});

  @override
  State<FcmDebugScreen> createState() => _FcmDebugScreenState();
}

class _FcmDebugScreenState extends State<FcmDebugScreen> {
  String? _token;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    setState(() => _loading = true);
    final token = await FcmService().getToken();
    if (mounted) setState(() { _token = token; _loading = false; });
  }

  void _copyToken() {
    if (_token == null) return;
    Clipboard.setData(ClipboardData(text: _token!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('FCM token copied to clipboard!',
            style: TextStyle(fontFamily: 'Poppins')),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'FCM Debug',
          style: TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadToken,
            tooltip: 'Refresh token',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // ── Token card ────────────────────────────────────────────────────
          _Card(
            title: 'Your Device FCM Token',
            icon: Icons.key_rounded,
            iconColor: AppColors.blue,
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _token == null
                    ? _InfoBanner(
                        color: AppColors.overdue,
                        icon: Icons.warning_amber_rounded,
                        message:
                            'No token available. Check that notification permissions are granted.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Copy this token to test from Firebase Console → Messaging → Send test message.',
                            style: AppTextStyles.caption(
                                color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.lightGray,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.blue.withOpacity(0.25)),
                            ),
                            child: SelectableText(
                              _token!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: AppColors.textPrimary,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _copyToken,
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('Copy Full Token',
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.blue,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),

          const SizedBox(height: 16),

          // ── Firebase Console instructions ─────────────────────────────────
          _Card(
            title: 'Test via Firebase Console',
            icon: Icons.send_rounded,
            iconColor: AppColors.purple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Step(n: '1', text: 'Open Firebase Console → your project → Messaging'),
                _Step(n: '2', text: 'Click "Create your first campaign" → Firebase Notification messages'),
                _Step(n: '3', text: 'Enter a notification title and body'),
                _Step(n: '4', text: 'Click "Send test message"'),
                _Step(n: '5', text: 'Paste the FCM token above and click the + icon, then "Test"'),
                SizedBox(height: 10),
                _InfoBanner(
                  color: AppColors.blue,
                  icon: Icons.info_outline_rounded,
                  message:
                      'To test Cloud Function triggers, create or update the relevant documents directly in Firebase Console → Firestore.',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Test cases ────────────────────────────────────────────────────
          _Card(
            title: 'All Push Notification Triggers',
            icon: Icons.notifications_active_outlined,
            iconColor: AppColors.pending,
            child: Column(
              children: _kTestCases
                  .map((tc) => _TestCaseTile(tc: tc))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data ──────────────────────────────────────────────────────────────────────

class _TestCase {
  final String trigger;
  final String dataType;
  final String receiver;
  final String howToTest;
  const _TestCase({
    required this.trigger,
    required this.dataType,
    required this.receiver,
    required this.howToTest,
  });
}

const List<_TestCase> _kTestCases = [
  _TestCase(
    trigger: '1. New Bill Created',
    dataType: 'type: "bill"',
    receiver: 'All Residents (role: user)',
    howToTest:
        'Admin creates a bill from the Billing screen. Cloud Function fires on bills/{id} onCreate.',
  ),
  _TestCase(
    trigger: '2. Meeting Scheduled',
    dataType: 'type: "meeting"',
    receiver: 'All Residents (role: user)',
    howToTest:
        'Admin taps Schedule Meeting. Function fires on meetings/{id} onCreate.',
  ),
  _TestCase(
    trigger: '3. New Complaint Filed',
    dataType: 'type: "complaint"',
    receiver: 'Apartment Admin (president)',
    howToTest:
        'Resident raises a complaint. Function fires on complaints/{id} onCreate.',
  ),
  _TestCase(
    trigger: '4. Complaint Reply',
    dataType: 'type: "complaint"',
    receiver: 'The other party (admin ↔ user)',
    howToTest:
        'Either party sends a message in a complaint chat. Function fires on complaints/{id}/messages/{id} onCreate.',
  ),
  _TestCase(
    trigger: '5. Payment Reported',
    dataType: 'type: "payment"',
    receiver: 'Apartment Admin',
    howToTest:
        'Resident taps "I Paid" and submits a transaction ID. Function fires on payments/{id} onUpdate.',
  ),
  _TestCase(
    trigger: '6. Payment Verified',
    dataType: 'type: "payment"',
    receiver: 'Resident who paid',
    howToTest:
        'Admin marks a payment as verified in Mark Paid screen. Function fires on payments/{id} onUpdate.',
  ),
  _TestCase(
    trigger: '7. New Resident Request',
    dataType: 'type: "resident_request"',
    receiver: 'Apartment Admin',
    howToTest:
        'New resident signs up via "Join Apartment" flow. Function fires on resident_requests/{id} onCreate.',
  ),
  _TestCase(
    trigger: '8. President Registered',
    dataType: 'type: "president_registered"',
    receiver: 'All Super Admins',
    howToTest:
        'New president completes sign-up via President Sign Up screen. Function fires on apartments/{id} onUpdate when status → "active".',
  ),
  _TestCase(
    trigger: '9. President Transferred',
    dataType: 'type: "president_transfer"',
    receiver: 'Old & New President',
    howToTest:
        'Admin transfers presidency in Profile → Transfer Presidency. Function fires on apartments/{id} onUpdate when presidentId changes.',
  ),
];

// ── Widgets ───────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  const _Card({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: AppTextStyles.subheading()),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TestCaseTile extends StatelessWidget {
  final _TestCase tc;
  const _TestCaseTile({required this.tc});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tc.trigger,
                  style: AppTextStyles.bodySmall()
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _LabelRow(label: 'Data type', value: tc.dataType),
              _LabelRow(label: 'Receiver', value: tc.receiver),
              _LabelRow(label: 'How to trigger', value: tc.howToTest),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
      ],
    );
  }
}

class _LabelRow extends StatelessWidget {
  final String label;
  final String value;
  const _LabelRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
                color: AppColors.purple, shape: BoxShape.circle),
            child: Center(
              child: Text(
                n,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall())),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String message;
  const _InfoBanner({
    required this.color,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTextStyles.caption(color: color)
                    .copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
