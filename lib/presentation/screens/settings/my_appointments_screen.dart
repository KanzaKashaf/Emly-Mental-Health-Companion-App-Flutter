import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';
import '../../../../core/data/repositories/appointment_repository.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  int _selectedTab = 0;

  bool _loading = true;
  bool _error = false;
  String? _cancellingAppointmentId;

  List<AppointmentModel> _appointments = [];

  final List<String> _tabs = const [
    'Upcoming',
    'Past',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final data = await AppServices.appointmentRepository.getAppointments();

      if (!mounted) return;

      data.sort((a, b) {
        final ad = a.preferredDate ?? a.createdAt;
        final bd = b.preferredDate ?? b.createdAt;

        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;

        return ad.compareTo(bd);
      });

      setState(() {
        _appointments = data;
        _loading = false;
        _error = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = true;
      });

      _showError(
        e.message.isNotEmpty ? e.message : 'Failed to load appointments.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = true;
      });

      _showError('Failed to load appointments.');
    }
  }

  List<AppointmentModel> get _filteredAppointments {
    if (_selectedTab == 0) {
      return _appointments.where((a) => a.isUpcoming).toList();
    }

    if (_selectedTab == 1) {
      return _appointments.where((a) => a.isPast).toList();
    }

    return _appointments.where((a) => a.isCancelled).toList();
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _cancelAppointmentRequest(AppointmentModel appointment) async {
    if (_cancellingAppointmentId != null) return;

    final confirmed = await _showCancelAppointmentConfirmation(
      context,
      doctorName: appointment.doctorName,
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _cancellingAppointmentId = appointment.id);

    try {
      await AppServices.appointmentRepository.cancelAppointment(appointment.id);

      final updatedAppointments =
          await AppServices.appointmentRepository.getAppointments();

      if (!mounted) return;

      setState(() {
        _appointments = updatedAppointments;
        _selectedTab = 2;
        _cancellingAppointmentId = null;
      });

      _showSuccess('Appointment request cancelled successfully.');
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() => _cancellingAppointmentId = null);

      _showError(
        e.message.isNotEmpty
            ? e.message
            : 'Failed to cancel appointment request.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _cancellingAppointmentId = null);
      _showError('Failed to cancel appointment request. Please try again.');
    }
  }

  Future<bool?> _showCancelAppointmentConfirmation(
    BuildContext context, {
    required String doctorName,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cancel Request?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.15),
                ),
              ),

              Text(
                'Are you sure you want to cancel your appointment request with $doctorName?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2B2B2B)
                              : const Color(0xFFF4F7FD),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          'No',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.white
                                : AppColors.primaryLight,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, true),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF63A3A),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'Yes, Cancel',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _goToFindDoctor() {
    Navigator.pushNamed(context, AppRoutes.findDoctor).then((_) {
      if (mounted) {
        _loadAppointments();
      }
    });
  }

  _AppointmentEmptyStateData _emptyStateDataForCurrentTab() {
    if (_selectedTab == 0) {
      return _AppointmentEmptyStateData(
        icon: Icons.calendar_month_rounded,
        title: 'No appointments booked',
        subtitle:
            'Find a mental health professional and send an appointment request. Your upcoming sessions will appear here.',
        buttonText: 'Find Doctor',
        onTap: _goToFindDoctor,
      );
    }

    if (_selectedTab == 1) {
      return _AppointmentEmptyStateData(
        icon: Icons.history_rounded,
        title: 'No past appointments',
        subtitle:
            'After your sessions are completed, your appointment history will be saved here for quick reference.',
        buttonText: 'Book Appointment',
        onTap: _goToFindDoctor,
      );
    }

    return _AppointmentEmptyStateData(
      icon: Icons.event_busy_rounded,
      title: 'No cancelled requests',
      subtitle:
          'Cancelled appointment requests will appear here. For now, everything looks clean and organized.',
      buttonText: 'Find Doctor',
      onTap: _goToFindDoctor,
    );
  }

  Widget _buildBody(bool isDark) {
    final filteredAppointments = _filteredAppointments;

    if (_loading) {
      return _AppointmentsSkeleton(
        isDark: isDark,
        appointmentCount: filteredAppointments.isNotEmpty
            ? filteredAppointments.length
            : 3,
        showCancelButton: _selectedTab == 0,
      );
    }

    if (_error && _appointments.isEmpty) {
      return _AppointmentsEmptyState(
        isDark: isDark,
        icon: Icons.wifi_off_rounded,
        title: 'Appointments did not load',
        subtitle: 'Please check your connection and try again.',
        buttonText: 'Retry',
        onTap: _loadAppointments,
      );
    }

    if (filteredAppointments.isEmpty) {
      final data = _emptyStateDataForCurrentTab();

      return RefreshIndicator(
        onRefresh: _loadAppointments,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.58,
              child: _AppointmentsEmptyState(
                isDark: isDark,
                icon: data.icon,
                title: data.title,
                subtitle: data.subtitle,
                buttonText: data.buttonText,
                onTap: data.onTap,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filteredAppointments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final appointment = filteredAppointments[index];

          final isCancellingThisCard =
              _cancellingAppointmentId == appointment.id;

          return _AppointmentCard(
            isDark: isDark,
            appointment: appointment,
            buttonText: isCancellingThisCard
                ? 'Cancelling...'
                : 'Cancel Request',
            showCancelButton: _selectedTab == 0 && !appointment.isCancelled,
            onButtonTap: isCancellingThisCard
                ? () {}
                : () => _cancelAppointmentRequest(appointment),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back,
                      size: 26,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'My Appointments',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    _tabs.length,
                    (index) => _AppointmentTab(
                      title: _tabs[index],
                      selected: _selectedTab == index,
                      isDark: isDark,
                      onTap: () {
                        setState(() => _selectedTab = index);
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Expanded(child: _buildBody(isDark)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentEmptyStateData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onTap;

  const _AppointmentEmptyStateData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onTap,
  });
}

class _AppointmentsEmptyState extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onTap;

  const _AppointmentsEmptyState({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final cardColor = isDark
        ? const Color(0xFF2B2B2B)
        : const Color(0xFFF4F7FD);

    final chipColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.92);

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.20)
                  : Colors.black.withOpacity(0.06),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary.withOpacity(isDark ? 0.18 : 0.10),
                  ),
                ),
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary,
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.34),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                Positioned(
                  right: 2,
                  top: 12,
                  child: _MiniBadge(
                    isDark: isDark,
                    icon: Icons.add_rounded,
                  ),
                ),
                Positioned(
                  left: 4,
                  bottom: 14,
                  child: _MiniBadge(
                    isDark: isDark,
                    icon: Icons.favorite_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.15,
                color: onSurface,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: onSurface.withOpacity(0.62),
              ),
            ),

            const SizedBox(height: 18),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _EmptyStateChip(
                  label: 'Verified doctors',
                  icon: Icons.verified_rounded,
                  color: primary,
                  backgroundColor: chipColor,
                ),
                _EmptyStateChip(
                  label: 'Easy booking',
                  icon: Icons.schedule_rounded,
                  color: primary,
                  backgroundColor: chipColor,
                ),
              ],
            ),

            const SizedBox(height: 24),

            GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary,
                      primary.withOpacity(0.82),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      buttonText,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: Colors.white,
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

class _MiniBadge extends StatelessWidget {
  final bool isDark;
  final IconData icon;

  const _MiniBadge({
    required this.isDark,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A3A3A) : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.22 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 17,
        color: primary,
      ),
    );
  }
}

class _EmptyStateChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _EmptyStateChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.0,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentsSkeleton extends StatelessWidget {
  final bool isDark;
  final int appointmentCount;
  final bool showCancelButton;

  const _AppointmentsSkeleton({
    required this.isDark,
    required this.appointmentCount,
    required this.showCancelButton,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
      highlightColor:
          isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF6F8FC),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: appointmentCount,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) {
          return _AppointmentCardSkeleton(
            showCancelButton: showCancelButton,
          );
        },
      ),
    );
  }
}

class _AppointmentCardSkeleton extends StatelessWidget {
  final bool showCancelButton;

  const _AppointmentCardSkeleton({
    required this.showCancelButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: showCancelButton ? 162 : 116,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          const SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonCircle(size: 40),

                SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(width: 140, height: 16, radius: 6),
                      SizedBox(height: 5),
                      _SkeletonBox(width: 105, height: 16, radius: 6),
                    ],
                  ),
                ),

                SizedBox(width: 10),

                Padding(
                  padding: EdgeInsets.only(top: 6, right: 4),
                  child: _SkeletonBox(width: 70, height: 14, radius: 6),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          const SizedBox(
            height: 13,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 96, height: 13, radius: 6),
                SizedBox(width: 4),
                Expanded(
                  child: _SkeletonBox(height: 13, radius: 6),
                ),
              ],
            ),
          ),

          const SizedBox(height: 7),

          const SizedBox(
            height: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 42, height: 13, radius: 6),
                SizedBox(width: 4),
                Expanded(
                  child: _SkeletonBox(height: 13, radius: 6),
                ),
              ],
            ),
          ),

          if (showCancelButton) ...[
            const SizedBox(height: 15),
            const _SkeletonBox(width: 191, height: 31, radius: 16),
          ],
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.height,
    this.width = double.infinity,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  final double size;

  const _SkeletonCircle({
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _AppointmentTab extends StatelessWidget {
  final String title;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _AppointmentTab({
    required this.title,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final bgColor = selected
        ? primary
        : isDark
            ? const Color(0xFF4A4A4A)
            : const Color(0xFFE3E7F0);

    final textColor = selected
        ? Colors.white
        : isDark
            ? Colors.white.withOpacity(0.84)
            : const Color(0xFF252525);

    final double width;
    if (title == 'Upcoming') {
      width = 111;
    } else if (title == 'Past') {
      width = 76;
    } else {
      width = 112;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.0,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final bool isDark;
  final AppointmentModel appointment;
  final String buttonText;
  final bool showCancelButton;
  final VoidCallback onButtonTap;

  const _AppointmentCard({
    required this.isDark,
    required this.appointment,
    required this.buttonText,
    required this.showCancelButton,
    required this.onButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final cardColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    final subTextColor = isDark
        ? Colors.white.withOpacity(0.70)
        : Colors.black.withOpacity(0.58);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFD9D9D9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  size: 31,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.doctorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      appointment.doctorType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(top: 6, right: 4),
                child: Text(
                  _formatStatus(appointment.status),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    color: _statusColor(appointment.status),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preferred date:',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  color: primary,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _formatDate(appointment.preferredDate),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.0,
                    color: subTextColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notes:',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  color: primary,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  appointment.notes.trim().isEmpty
                      ? 'No notes added'
                      : appointment.notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.25,
                    color: subTextColor,
                  ),
                ),
              ),
            ],
          ),

          if (showCancelButton) ...[
            const SizedBox(height: 15),
            GestureDetector(
              onTap: onButtonTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 191,
                height: 31,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    height: 1.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not selected';

    final local = date.toLocal();

    const months = [
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
      'Dec',
    ];

    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  String _formatStatus(String status) {
    final cleaned = status.replaceAll('_', ' ').replaceAll('-', ' ').trim();

    if (cleaned.isEmpty) return 'Pending';

    return cleaned
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();

    if (s.contains('cancel')) return const Color(0xFFF63A3A);
    if (s.contains('confirm') || s.contains('accept')) {
      return const Color(0xFF18B663);
    }
    if (s.contains('complete') || s.contains('done')) {
      return const Color(0xFF18B663);
    }

    return const Color(0xFFFFD400);
  }
}