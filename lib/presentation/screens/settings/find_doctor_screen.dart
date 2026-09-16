import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';
import '../../../../core/data/repositories/doctor_repository.dart';

class FindDoctorScreen extends StatefulWidget {
  const FindDoctorScreen({super.key});

  @override
  State<FindDoctorScreen> createState() => _FindDoctorScreenState();
}

class _FindDoctorScreenState extends State<FindDoctorScreen> {
  int _selectedFilter = 0;

  bool _loading = true;
  bool _hasLoadedDoctorsOnce = false;

  final List<String> _filters = const [
    'All',
    'Psychiatrist',
    'Therapist',
    'CBT',
  ];

  List<DoctorModel> _doctors = [];

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() => _loading = true);

    try {
      final doctors = await AppServices.doctorRepository.getDoctors();

      if (!mounted) return;

      setState(() {
        _doctors = doctors;
        _loading = false;
        _hasLoadedDoctorsOnce = true;
      });
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _hasLoadedDoctorsOnce = true;
      });

      _showError(
        e.message.isNotEmpty ? e.message : 'Failed to load doctors.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _hasLoadedDoctorsOnce = true;
      });
      _showError('Failed to load doctors.');
    }
  }

  List<DoctorModel> get _filteredDoctors {
    final filter = _filters[_selectedFilter].toLowerCase();

    if (filter == 'all') return _doctors;

    return _doctors.where((doctor) {
      final specialty = doctor.specialty.toLowerCase();
      final name = doctor.name.toLowerCase();

      if (filter == 'cbt') {
        return specialty.contains('cbt') ||
            specialty.contains('therap') ||
            name.contains('cbt');
      }

      return specialty.contains(filter);
    }).toList();
  }

  Future<void> _callDoctor(DoctorModel doctor) async {
    final phone = doctor.phone.trim();

    if (phone.isEmpty) {
      _showError('Phone number is not available for this doctor.');
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);

    try {
      final launched = await launchUrl(uri);

      if (!launched) {
        _showError('Could not open phone dialer.');
      }
    } catch (_) {
      _showError('Could not open phone dialer.');
    }
  }

  void _bookDoctor(DoctorModel doctor) {
    Navigator.pushNamed(
      context,
      AppRoutes.bookAppointment,
      arguments: {
        'doctor': doctor.toJson(),
        'doctorId': doctor.id,
        'doctorName': doctor.name,
        'doctorType': doctor.specialty,
        'doctorPhone': doctor.phone,
      },
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

              /// APP BAR
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
                    'Find a Doctor',
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
                child: _loading
                    ? _FindDoctorSkeleton(
                        isDark: isDark,
                        doctorCount: _filteredDoctors.isNotEmpty
                            ? _filteredDoctors.length
                            : 3,
                        showEmptyState:
                            _hasLoadedDoctorsOnce && _filteredDoctors.isEmpty,
                        filters: _filters,
                        selectedFilter: _selectedFilter,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadDoctors,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Connect with available mental\nhealth professionals.',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                  height: 1.28,
                                  color: textColor,
                                ),
                              ),

                              const SizedBox(height: 12),

                              SizedBox(
                                height: 27,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.only(left: 3),
                                  itemCount: _filters.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    return _DoctorFilterChip(
                                      title: _filters[index],
                                      selected: _selectedFilter == index,
                                      isDark: isDark,
                                      onTap: () {
                                        setState(() => _selectedFilter = index);
                                      },
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 15),

                              if (_filteredDoctors.isEmpty)
                                _EmptyDoctorsCard(isDark: isDark)
                              else
                                ...List.generate(
                                  _filteredDoctors.length,
                                  (index) => Padding(
                                    padding: EdgeInsets.only(
                                      bottom: index ==
                                              _filteredDoctors.length - 1
                                          ? 0
                                          : 11,
                                    ),
                                    child: _DoctorCard(
                                      isDark: isDark,
                                      doctor: _filteredDoctors[index],
                                      onCall: () =>
                                          _callDoctor(_filteredDoctors[index]),
                                      onBook: () =>
                                          _bookDoctor(_filteredDoctors[index]),
                                    ),
                                  ),
                                ),
                            ],
                          ),
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

class _FindDoctorSkeleton extends StatelessWidget {
  final bool isDark;
  final int doctorCount;
  final bool showEmptyState;
  final List<String> filters;
  final int selectedFilter;

  const _FindDoctorSkeleton({
    required this.isDark,
    required this.doctorCount,
    required this.showEmptyState,
    required this.filters,
    required this.selectedFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
      highlightColor:
          isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF6F8FC),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SkeletonBox(width: 315, height: 27, radius: 8),
            const SizedBox(height: 6),
            const _SkeletonBox(width: 260, height: 27, radius: 8),

            const SizedBox(height: 12),

            SizedBox(
              height: 27,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(left: 3),
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  return _DoctorFilterChipSkeleton(
                    title: filters[index],
                    selected: selectedFilter == index,
                  );
                },
              ),
            ),

            const SizedBox(height: 15),

            if (showEmptyState)
              const _EmptyDoctorsCardSkeleton()
            else
              ...List.generate(
                doctorCount,
                (index) => Padding(
                  padding: EdgeInsets.only(
                    bottom: index == doctorCount - 1 ? 0 : 11,
                  ),
                  child: const _DoctorCardSkeleton(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DoctorFilterChipSkeleton extends StatelessWidget {
  final String title;
  final bool selected;

  const _DoctorFilterChipSkeleton({
    required this.title,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 27,
      width: title == 'All'
          ? 55
          : title == 'Psychiatrist'
              ? 120
              : title == 'Therapist'
                  ? 95
                  : 62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _DoctorCardSkeleton extends StatelessWidget {
  const _DoctorCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 132,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                _SkeletonCircle(size: 48),

                SizedBox(width: 12),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(width: 145, height: 14, radius: 6),
                      SizedBox(height: 5),
                      _SkeletonBox(width: 110, height: 12, radius: 6),
                      SizedBox(height: 5),
                      _SkeletonBox(width: 150, height: 12, radius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          SizedBox(
            height: 40,
            child: Row(
              children: [
                Expanded(
                  child: _SkeletonBox(height: 40, radius: 6),
                ),
                SizedBox(width: 22),
                Expanded(
                  child: _SkeletonBox(height: 40, radius: 6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDoctorsCardSkeleton extends StatelessWidget {
  const _EmptyDoctorsCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 76,
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: _SkeletonBox(width: 205, height: 14, radius: 6),
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

class _DoctorFilterChip extends StatelessWidget {
  final String title;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _DoctorFilterChip({
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
            ? Colors.white.withOpacity(0.88)
            : const Color(0xFF252525);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 27,
        padding: EdgeInsets.symmetric(
          horizontal: title == 'All' ? 18 : 14,
        ),
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

class _DoctorCard extends StatelessWidget {
  final bool isDark;
  final DoctorModel doctor;
  final VoidCallback onCall;
  final VoidCallback onBook;

  const _DoctorCard({
    required this.isDark,
    required this.doctor,
    required this.onCall,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final cardColor =
        isDark ? const Color(0xFF2F2F2F) : const Color(0xFFF4F7FD);

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    final subTextColor = isDark
        ? Colors.white.withOpacity(0.68)
        : Colors.black.withOpacity(0.58);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _DoctorAvatar(
                imageUrl: doctor.imageUrl,
                isDark: isDark,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                        color: textColor,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      doctor.specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                        color: subTextColor,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      doctor.availability,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
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

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _DoctorActionButton(
                  text: 'Call',
                  assetIcon: 'assets/images/Phone.png',
                  backgroundColor:
                      isDark ? const Color(0xFF8579E0) : Colors.white,
                  textColor: isDark ? Colors.white : Colors.black,
                  iconColor: primary,
                  onTap: onCall,
                ),
              ),

              const SizedBox(width: 22),

              Expanded(
                child: _DoctorActionButton(
                  text: 'Book',
                  assetIcon: 'assets/images/Appointment.png',
                  backgroundColor:
                      isDark ? const Color(0xFF484848) : const Color(0xFFDCE1ED),
                  textColor: isDark ? Colors.white : Colors.black,
                  iconColor: isDark ? Colors.white : primary,
                  onTap: onBook,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoctorAvatar extends StatelessWidget {
  final String imageUrl;
  final bool isDark;

  const _DoctorAvatar({
    required this.imageUrl,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();

    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFFD9D9D9),
        backgroundImage: NetworkImage(url),
      );
    }

    return const CircleAvatar(
      radius: 24,
      backgroundImage: AssetImage('assets/images/Person.png'),
    );
  }
}

class _DoctorActionButton extends StatelessWidget {
  final String text;
  final String assetIcon;
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _DoctorActionButton({
    required this.text,
    required this.assetIcon,
    required this.backgroundColor,
    required this.textColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Image.asset(
        assetIcon,
        width: 16,
        height: 16,
        color: iconColor,
      ),
      label: Text(
        text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.0,
          color: textColor,
        ),
      ),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

class _EmptyDoctorsCard extends StatelessWidget {
  final bool isDark;

  const _EmptyDoctorsCard({
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor =
        isDark ? const Color(0xFF2F2F2F) : const Color(0xFFF4F7FD);

    final textColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.58);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'No doctors found for this filter.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textColor,
        ),
      ),
    );
  }
}