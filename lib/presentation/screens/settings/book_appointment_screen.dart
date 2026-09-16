import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';
import '../../widgets/primary_button.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  int _selectedTimeIndex = 1;

  bool _argsRead = false;
  bool _isBooked = false;
  bool _isSubmitting = false;

  DateTime? _selectedDate;
  DateTime? _bookedDateTime;

  String? _doctorId;
  String _doctorName = 'Doctor';
  String _doctorType = 'Mental Health Professional';
  String _doctorPhone = '';
  String _doctorAvailability = 'Availability not specified';
  String _doctorImageUrl = '';

  final List<String> _times = const [
    '09:00',
    '12:00',
    '14:00',
    '17:00',
    '23:00',
    '23:30',
  ];

  @override
  void initState() {
    super.initState();

    final initialDate = DateTime.now().add(const Duration(days: 1));
    _setSelectedDate(initialDate);

    // Empty by default. Hint text still shows the sample.
    _notesController.text = '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_argsRead) return;
    _argsRead = true;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map) {
      final doctor = args['doctor'];

      if (doctor is Map) {
        final map = Map<String, dynamic>.from(doctor);

        _doctorId = (map['id'] ?? args['doctorId'] ?? '').toString();
        _doctorName = (map['name'] ?? args['doctorName'] ?? 'Doctor').toString();
        _doctorType = (map['specialty'] ??
                args['doctorType'] ??
                'Mental Health Professional')
            .toString();
        _doctorPhone = (map['phone'] ?? args['doctorPhone'] ?? '').toString();
        _doctorAvailability = (map['availability'] ??
                args['doctorAvailability'] ??
                'Availability not specified')
            .toString();
        _doctorImageUrl = (map['imageUrl'] ?? '').toString();
      } else {
        _doctorId = args['doctorId']?.toString();
        _doctorName = (args['doctorName'] ?? 'Doctor').toString();
        _doctorType =
            (args['doctorType'] ?? 'Mental Health Professional').toString();
        _doctorPhone = (args['doctorPhone'] ?? '').toString();
        _doctorAvailability =
            (args['doctorAvailability'] ?? 'Availability not specified')
                .toString();
        _doctorImageUrl = (args['doctorImageUrl'] ?? '').toString();
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _dateController.dispose();
    _dayController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today.add(const Duration(days: 1)),
      firstDate: today,
      lastDate: DateTime(now.year + 5),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );

    if (date != null) {
      setState(() {
        _setSelectedDate(date);
      });
    }
  }

  void _setSelectedDate(DateTime date) {
    _selectedDate = date;
    _dayController.text = _weekdayShort(date.weekday);
    _dateController.text =
        '${_monthName(date.month)} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }

  DateTime _selectedDateTime() {
    final date = _selectedDate ?? DateTime.now().add(const Duration(days: 1));
    final time = _times[_selectedTimeIndex];

    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 12;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String _weekdayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }

  String _shortMonthName(int month) {
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

    return months[month - 1];
  }

  String _confirmedDateText() {
    final dt = _bookedDateTime ?? _selectedDateTime();

    return '$_doctorName will see you on ${_weekdayShort(dt.weekday)}, '
        '${_shortMonthName(dt.month)} ${dt.day} · '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmBooking() async {
    if (_isSubmitting) return;

    final doctorId = _doctorId;

    if (doctorId == null || doctorId.trim().isEmpty) {
      _showError('Doctor information is missing. Please select a doctor again.');
      return;
    }

    final preferredDate = _selectedDateTime();

    setState(() => _isSubmitting = true);

    try {
      await AppServices.appointmentRepository.createAppointment(
        doctorId: doctorId,
        preferredDate: preferredDate,
        notes: [
          'Preferred time: ${_times[_selectedTimeIndex]}',
          if (_notesController.text.trim().isNotEmpty)
            _notesController.text.trim(),
        ].join('\n'),
      );

      if (!mounted) return;

      setState(() {
        _bookedDateTime = preferredDate;
        _isBooked = true;
        _isSubmitting = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      _showError(
        e.message.isNotEmpty
            ? e.message
            : 'Failed to book appointment. Please try again.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);
      _showError('Failed to book appointment. Please try again.');
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    final subTextColor = isDark
        ? Colors.white.withOpacity(0.66)
        : Colors.black.withOpacity(0.56);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        if (_isBooked) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (route) => false,
          );
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              Row(
                children: [
                  IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            if (_isBooked) {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                AppRoutes.home,
                                (route) => false,
                              );
                            } else {
                              Navigator.pop(context);
                            }
                          },
                    icon: Icon(Icons.arrow_back, size: 26, color: textColor),
                  ),
                  Text(
                    'Book Appointment',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),

              Expanded(
                child: _isBooked
                    ? _BookingConfirmedContent(
                        isDark: isDark,
                        confirmationText: _confirmedDateText(),
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DoctorSummaryCard(
                              isDark: isDark,
                              doctorName: _doctorName,
                              doctorType: _doctorType,
                              availability: _doctorAvailability,
                              imageUrl: _doctorImageUrl,
                            ),

                            const SizedBox(height: 8),

                            _Label(text: 'Select date', color: textColor),

                            const SizedBox(height: 7),

                            _DateField(
                              isDark: isDark,
                              day: _dayController.text,
                              date: _dateController.text,
                              onTap: _isSubmitting ? () {} : _pickDate,
                            ),

                            const SizedBox(height: 8),

                            _Label(text: 'Select time', color: textColor),

                            const SizedBox(height: 15),

                            Opacity(
                              opacity: _isSubmitting ? 0.6 : 1,
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _times.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 34,
                                  mainAxisSpacing: 11,
                                  childAspectRatio: 1.95,
                                ),
                                itemBuilder: (context, index) {
                                  return _TimeSlot(
                                    text: _times[index],
                                    selected: _selectedTimeIndex == index,
                                    isDark: isDark,
                                    onTap: _isSubmitting
                                        ? () {}
                                        : () {
                                            setState(() {
                                              _selectedTimeIndex = index;
                                            });
                                          },
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 13),

                            _Label(text: 'Notes (Optional)', color: textColor),

                            const SizedBox(height: 10),

                            _NotesField(
                              controller: _notesController,
                              isDark: isDark,
                              subTextColor: subTextColor,
                              enabled: !_isSubmitting,
                            ),

                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: PrimaryButton(
                    text: _isBooked
                        ? 'Back to Home'
                        : _isSubmitting
                            ? 'Booking...'
                            : 'Confirm Booking',
                    onTap: () {
                      if (_isBooked) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.home,
                          (route) => false,
                        );
                      } else {
                        _confirmBooking();
                      }
                    },
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

class _BookingConfirmedContent extends StatelessWidget {
  final bool isDark;
  final String confirmationText;

  const _BookingConfirmedContent({
    required this.isDark,
    required this.confirmationText,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final titleColor = isDark ? Colors.white : Colors.black;

    final subtitleColor = isDark
        ? Colors.white.withOpacity(0.74)
        : Colors.black.withOpacity(0.58);

    return Column(
      children: [
        const SizedBox(height: 97),

        Center(
          child: Image.asset(
            'assets/images/Booked.png',
            width: 148,
            height: 148,
            fit: BoxFit.contain,
            color: primary,
          ),
        ),

        const SizedBox(height: 22),

        Text(
          'You are Booked !',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.0,
            color: titleColor,
          ),
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            confirmationText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.35,
              color: subtitleColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _DoctorSummaryCard extends StatelessWidget {
  final bool isDark;
  final String doctorName;
  final String doctorType;
  final String availability;
  final String imageUrl;

  const _DoctorSummaryCard({
    required this.isDark,
    required this.doctorName,
    required this.doctorType,
    required this.availability,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    final subTextColor = isDark
        ? Colors.white.withOpacity(0.68)
        : Colors.black.withOpacity(0.58);

    final url = imageUrl.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 11, 14, 11),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 33,
            backgroundColor: const Color(0xFFD9D9D9),
            backgroundImage:
                url.isNotEmpty ? NetworkImage(url) : const AssetImage('assets/images/Person.png') as ImageProvider,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctorName,
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
                const SizedBox(height: 7),
                Text(
                  doctorType,
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
                const SizedBox(height: 7),
                Text(
                  availability,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.0,
                    color: subTextColor,
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

class _Label extends StatelessWidget {
  final String text;
  final Color color;

  const _Label({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.0,
          color: color,
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final bool isDark;
  final String day;
  final String date;
  final VoidCallback onTap;

  const _DateField({
    required this.isDark,
    required this.day,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.08);

    final dayColor = isDark
        ? Colors.white.withOpacity(0.82)
        : Colors.black.withOpacity(0.30);

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 56,
        padding: const EdgeInsets.fromLTRB(16, 7, 20, 7),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'Poppins', height: 1.0),
                  children: [
                    TextSpan(
                      text: '$day\n',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: dayColor,
                      ),
                    ),
                    TextSpan(
                      text: date,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Image.asset(
              'assets/images/Calender.png',
              width: 22,
              height: 22,
              color: isDark
                  ? Colors.white.withOpacity(0.68)
                  : Colors.black.withOpacity(0.32),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSlot extends StatelessWidget {
  final String text;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _TimeSlot({
    required this.text,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final borderColor = selected
        ? primary
        : isDark
            ? Colors.white.withOpacity(0.72)
            : Colors.black.withOpacity(0.50);

    final bgColor = selected
        ? (isDark ? const Color(0xFF252338) : primary.withOpacity(0.08))
        : Colors.transparent;

    final textColor = selected
        ? primary
        : isDark
            ? Colors.white
            : const Color(0xFF252525);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: selected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            height: 1.0,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _NotesField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final Color subTextColor;
  final bool enabled;

  const _NotesField({
    required this.controller,
    required this.isDark,
    required this.subTextColor,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final fieldColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    return Container(
      width: double.infinity,
      height: 102,
      padding: const EdgeInsets.fromLTRB(9, 2, 9, 8),
      decoration: BoxDecoration(
        color: fieldColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        minLines: 3,
        maxLines: 4,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.4,
          color: isDark
              ? Colors.white.withOpacity(0.74)
              : Colors.black.withOpacity(0.72),
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText:
              'First time consultation. I\'d like to discuss\nanxiety and sleep.',
          hintStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.4,
            color: subTextColor.withOpacity(0.72),
          ),
          isCollapsed: true,
          contentPadding: const EdgeInsets.only(top: 12),
        ),
      ),
    );
  }
}