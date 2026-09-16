import 'package:flutter/material.dart';

import '../../../../core/services/cbt_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';

class CbtNotificationSettingsScreen extends StatefulWidget {
  const CbtNotificationSettingsScreen({super.key});

  @override
  State<CbtNotificationSettingsScreen> createState() =>
      _CbtNotificationSettingsScreenState();
}

class _CbtNotificationSettingsScreenState
    extends State<CbtNotificationSettingsScreen> {
  bool _loading = true;
  bool _enabled = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final enabled = await CbtNotificationService.instance.isEnabled();

    if (!mounted) return;

    setState(() {
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    if (value) {
      await CbtNotificationService.instance.enableDefaultCbtReminders();
    } else {
      await CbtNotificationService.instance.disableCbtReminders();
    }

    final enabled = await CbtNotificationService.instance.isEnabled();

    if (!mounted) return;

    setState(() {
      _enabled = enabled;
      _saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'CBT reminders enabled.'
              : 'CBT reminders disabled.',
        ),
      ),
    );
  }

  Future<void> _sendTest() async {
    await CbtNotificationService.instance.showTestNotification();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test notification sent.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;

    final cardColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    final textColor = isDark ? Colors.white : const Color(0xFF2F2F2F);

    final subTextColor =
        isDark ? Colors.white.withOpacity(0.62) : Colors.black.withOpacity(0.55);

    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      IconButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back,
                          size: 26,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'CBT Notifications',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: primary.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.notifications_active_outlined,
                                    color: primary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Daily CBT Reminders',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        'Mood check-ins, CBT activities, and weekly reflection reminders.',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          height: 1.35,
                                          color: subTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _enabled,
                                  activeColor: primary,
                                  onChanged: _saving ? null : _toggle,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          Text(
                            'Default Reminder Schedule',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),

                          const SizedBox(height: 12),

                          _ReminderRow(
                            isDark: isDark,
                            title: 'CBT Activity',
                            time: 'Daily · 7:00 PM',
                          ),
                          _ReminderRow(
                            isDark: isDark,
                            title: 'Mood Check-in',
                            time: 'Daily · 9:00 PM',
                          ),
                          _ReminderRow(
                            isDark: isDark,
                            title: 'Weekly Review',
                            time: 'Sunday · 8:00 PM',
                          ),

                          const SizedBox(height: 28),

                          PrimaryButton(
                            text: 'Send Test Notification',
                            onTap: _sendTest,
                          ),

                          const SizedBox(height: 14),

                          Text(
                            'Notification text is kept private and neutral. EMLY will not mention diagnosis or sensitive screening results in reminders.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              height: 1.45,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final bool isDark;
  final String title;
  final String time;

  const _ReminderRow({
    required this.isDark,
    required this.title,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF2F2F2F);
    final subTextColor =
        isDark ? Colors.white.withOpacity(0.62) : Colors.black.withOpacity(0.55);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 20,
            color: subTextColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: textColor,
              ),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: subTextColor,
            ),
          ),
        ],
      ),
    );
  }
}