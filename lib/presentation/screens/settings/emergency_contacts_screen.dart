import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';
import '../../../../core/data/repositories/emergency_contact_repository.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<EmergencyContactModel> _contacts = [];

  static const int _maxContacts = 3;

  bool _loading = true;
  bool _savingContact = false;
  bool _hasLoadedContactsOnce = false;
  String? _deletingContactId;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);

    try {
      final contacts =
          await AppServices.emergencyContactRepository.getContacts();

      if (!mounted) return;

      setState(() {
        _contacts = contacts;
        _loading = false;
        _hasLoadedContactsOnce = true;
      });
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _hasLoadedContactsOnce = true;
      });

      _showError(
        e.message.isNotEmpty
            ? e.message
            : 'Failed to load emergency contacts.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _hasLoadedContactsOnce = true;
      });
      _showError('Failed to load emergency contacts.');
    }
  }

  Future<void> _callNumber(String phone) async {
    final cleaned = phone.trim();

    if (cleaned.isEmpty) {
      _showError('Phone number is not available.');
      return;
    }

    final uri = Uri(scheme: 'tel', path: cleaned);

    try {
      final launched = await launchUrl(uri);

      if (!launched) {
        _showError('Could not open phone dialer.');
      }
    } catch (_) {
      _showError('Could not open phone dialer.');
    }
  }

  Future<void> _deleteContact(EmergencyContactModel contact) async {
    if (_deletingContactId != null) return;

    final confirmed = await _showDeleteContactConfirmation(
      context,
      contactName: contact.name,
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _deletingContactId = contact.id);

    try {
      await AppServices.emergencyContactRepository.deleteContact(contact.id);

      final contacts =
          await AppServices.emergencyContactRepository.getContacts();

      if (!mounted) return;

      setState(() {
        _contacts = contacts;
        _deletingContactId = null;
      });

      _showSuccess('${contact.name} removed from emergency contacts.');
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() => _deletingContactId = null);

      _showError(
        e.message.isNotEmpty
            ? e.message
            : 'Failed to delete emergency contact.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _deletingContactId = null);
      _showError('Failed to delete emergency contact.');
    }
  }

  Future<bool?> _showDeleteContactConfirmation(
    BuildContext context, {
    required String contactName,
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
                'Delete Contact?',
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
                'Are you sure you want to remove $contactName from your emergency contacts?',
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
                          'No, Keep It',
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
                          color: const Color(0xFFFF3B40),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'Yes, Delete',
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

  Future<void> _openAddContactSheet() async {
    if (_contacts.length >= _maxContacts || _savingContact) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return const _AddEmergencyContactSheet();
      },
    );

    if (saved != true) return;
    if (!mounted) return;

    await _loadContacts();

    if (!mounted) return;
    _showSuccess('Emergency contact saved.');
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
                    'Emergency Contacts',
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
                child: _loading
                    ? _EmergencyContactsSkeleton(
                        isDark: isDark,
                        contactCount: _contacts.isNotEmpty ? _contacts.length : 3,
                        showEmptyState:
                            _hasLoadedContactsOnce && _contacts.isEmpty,
                        maxContacts: _maxContacts,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadContacts,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding:
                              const EdgeInsets.fromLTRB(16, 24, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add people you trust.',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                  color: textColor,
                                ),
                              ),

                              const SizedBox(height: 11),

                              if (_contacts.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 15),
                                  child: _EmptyContactsCard(isDark: isDark),
                                )
                              else
                                ...List.generate(
                                  _contacts.length,
                                  (index) {
                                    final contact = _contacts[index];
                                    final deletingThis =
                                        _deletingContactId == contact.id;

                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 15),
                                      child: _EmergencyContactCard(
                                        contact: contact,
                                        isDark: isDark,
                                        deleteText: deletingThis
                                            ? 'Deleting...'
                                            : 'Delete',
                                        onCall: () =>
                                            _callNumber(contact.phone),
                                        onDelete: deletingThis
                                            ? () {}
                                            : () => _deleteContact(contact),
                                      ),
                                    );
                                  },
                                ),

                              if (_contacts.length < _maxContacts) ...[
                                Opacity(
                                  opacity: _savingContact ? 0.6 : 1,
                                  child: IgnorePointer(
                                    ignoring: _savingContact,
                                    child: _AddAnotherContactButton(
                                      isDark: isDark,
                                      count: _contacts.length,
                                      max: _maxContacts,
                                      onTap: _openAddContactSheet,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 19),
                              ],

                              Text(
                                'CRISIS HOTLINES',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  height: 1.0,
                                  color: textColor,
                                ),
                              ),

                              const SizedBox(height: 19),

                              _HotlineCard(
                                isDark: isDark,
                                title: '988 Suicide & Crisis Lifeline',
                                phone: '988',
                                onCall: () => _callNumber('988'),
                              ),

                              const SizedBox(height: 6),

                              _HotlineCard(
                                isDark: isDark,
                                title: 'Rozan Counseling',
                                phone: '+92 304 1111741',
                                onCall: () =>
                                    _callNumber('+92 304 1111741'),
                              ),

                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.15,
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

class _EmergencyContactsSkeleton extends StatelessWidget {
  final bool isDark;
  final int contactCount;
  final bool showEmptyState;
  final int maxContacts;

  const _EmergencyContactsSkeleton({
    required this.isDark,
    required this.contactCount,
    required this.showEmptyState,
    required this.maxContacts,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
      highlightColor:
          isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF6F8FC),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SkeletonBox(width: 220, height: 21, radius: 8),

            const SizedBox(height: 11),

            if (showEmptyState) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 15),
                child: _EmptyContactsCardSkeleton(),
              ),
              const _AddAnotherContactButtonSkeleton(),
              const SizedBox(height: 19),
            ] else ...[
              ...List.generate(
                contactCount,
                (index) => const Padding(
                  padding: EdgeInsets.only(bottom: 15),
                  child: _EmergencyContactCardSkeleton(),
                ),
              ),

              if (contactCount < maxContacts) ...[
                const _AddAnotherContactButtonSkeleton(),
                const SizedBox(height: 19),
              ],
            ],

            const _SkeletonBox(width: 120, height: 14, radius: 6),

            const SizedBox(height: 19),

            const _HotlineCardSkeleton(),

            const SizedBox(height: 6),

            const _HotlineCardSkeleton(),

            SizedBox(
              height: MediaQuery.of(context).size.height * 0.15,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyContactCardSkeleton extends StatelessWidget {
  const _EmergencyContactCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 158,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Column(
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                _SkeletonCircle(size: 40),

                SizedBox(width: 11),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(width: 135, height: 16, radius: 6),
                      SizedBox(height: 5),
                      _SkeletonBox(width: 90, height: 16, radius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 17),

          SizedBox(
            height: 13,
            child: Row(
              children: [
                _SkeletonBox(width: 58, height: 13, radius: 6),
                SizedBox(width: 4),
                Expanded(
                  child: _SkeletonBox(height: 13, radius: 6),
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          SizedBox(
            height: 42,
            child: Row(
              children: [
                Expanded(
                  child: _SkeletonBox(height: 42, radius: 6),
                ),
                SizedBox(width: 24),
                Expanded(
                  child: _SkeletonBox(height: 42, radius: 6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyContactsCardSkeleton extends StatelessWidget {
  const _EmptyContactsCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 65,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Center(
        child: _SkeletonBox(width: 210, height: 14, radius: 6),
      ),
    );
  }
}

class _AddAnotherContactButtonSkeleton extends StatelessWidget {
  const _AddAnotherContactButtonSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 75,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          _SkeletonBox(width: 23, height: 23, radius: 12),
          SizedBox(width: 14),
          _SkeletonBox(width: 210, height: 16, radius: 6),
        ],
      ),
    );
  }
}

class _HotlineCardSkeleton extends StatelessWidget {
  const _HotlineCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 67,
      padding: const EdgeInsets.fromLTRB(11, 12, 13, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 43,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(width: 210, height: 16, radius: 6),
                  Spacer(),
                  _SkeletonBox(width: 130, height: 16, radius: 6),
                ],
              ),
            ),
          ),
          _SkeletonBox(width: 23, height: 23, radius: 12),
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

class _EmergencyContactCard extends StatelessWidget {
  final EmergencyContactModel contact;
  final bool isDark;
  final String deleteText;
  final VoidCallback onCall;
  final VoidCallback onDelete;

  const _EmergencyContactCard({
    required this.contact,
    required this.isDark,
    required this.deleteText,
    required this.onCall,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final cardColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    final subTextColor = isDark
        ? Colors.white.withOpacity(0.68)
        : Colors.black.withOpacity(0.58);

    final callButtonColor =
        isDark ? const Color(0xFF8579E0)  : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFD9D9D9),
                child: Icon(
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
                      contact.name,
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
                      contact.relation,
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
            ],
          ),

          const SizedBox(height: 17),

          Row(
            children: [
              Text(
                'Contact:',
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
                  contact.phone,
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

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _ContactActionButton(
                  text: 'Call',
                  icon: Icons.phone,
                  backgroundColor: callButtonColor,
                  textColor: isDark ? Colors.white : const Color(0xFF252525),
                  iconColor: primary,
                  onTap: onCall,
                ),
              ),

              const SizedBox(width: 24),

              Expanded(
                child: _ContactActionButton(
                  text: deleteText,
                  icon: null,
                  backgroundColor: const Color(0xFFFF3B40),
                  textColor: Colors.white,
                  iconColor: Colors.white,
                  onTap: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyContactsCard extends StatelessWidget {
  final bool isDark;

  const _EmptyContactsCard({
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    final textColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.58);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        'No emergency contacts added yet.',
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

class _AddAnotherContactButton extends StatelessWidget {
  final bool isDark;
  final int count;
  final int max;
  final VoidCallback onTap;

  const _AddAnotherContactButton({
    required this.isDark,
    required this.count,
    required this.max,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isDark ? Colors.white.withOpacity(0.38) : Colors.black.withOpacity(0.28);

    final textColor = isDark
        ? Colors.white.withOpacity(0.46)
        : Colors.black.withOpacity(0.40);

    final background =
        isDark ? const Color(0xFF4A4A4A) : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: borderColor,
          radius: 8,
        ),
        child: Container(
          width: double.infinity,
          height: 75,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.add,
                size: 23,
                color: textColor,
              ),
              const SizedBox(width: 14),
              Text(
                'Add another contact($count/$max)',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.0,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HotlineCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final String phone;
  final VoidCallback onCall;

  const _HotlineCard({
    required this.isDark,
    required this.title,
    required this.phone,
    required this.onCall,
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
      height: 67,
      padding: const EdgeInsets.fromLTRB(11, 12, 13, 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
                const Spacer(),
                Text(
                  phone,
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
          GestureDetector(
            onTap: onCall,
            behavior: HitTestBehavior.opaque,
            child: Icon(
              Icons.phone,
              size: 23,
              color: primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactActionButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _ContactActionButton({
    required this.text,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 21,
                color: iconColor,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.0,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEmergencyContactSheet extends StatefulWidget {
  const _AddEmergencyContactSheet();

  @override
  State<_AddEmergencyContactSheet> createState() =>
      _AddEmergencyContactSheetState();
}

class _AddEmergencyContactSheetState extends State<_AddEmergencyContactSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _relation = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _relationFocus = FocusNode();

  String? _nameError;
  String? _phoneError;
  String? _relationError;

  bool _isSaving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relation.dispose();

    _nameFocus.dispose();
    _phoneFocus.dispose();
    _relationFocus.dispose();

    super.dispose();
  }

  String? _validateName(String v) {
    final value = v.trim();
    if (value.isEmpty) return 'Name is required';
    if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(value)) return 'Only letters allowed';
    return null;
  }

  String? _validatePhone(String v) {
    final value = v.trim();
    if (value.isEmpty) return 'Phone number is required';

    final phoneRegex = RegExp(r'^\+?[0-9 ]{10,16}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter a valid phone number';
    }

    return null;
  }

  String? _validateRelation(String v) {
    final value = v.trim();
    if (value.isEmpty) return 'Relation is required';
    if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(value)) return 'Only letters allowed';
    return null;
  }

  bool get _isFormValid {
    return !_isSaving &&
        _name.text.trim().isNotEmpty &&
        _phone.text.trim().isNotEmpty &&
        _relation.text.trim().isNotEmpty &&
        _nameError == null &&
        _phoneError == null &&
        _relationError == null;
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    setState(() {
      _nameError = _validateName(_name.text);
      _phoneError = _validatePhone(_phone.text);
      _relationError = _validateRelation(_relation.text);
    });

    if (!_isFormValid) return;

    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);

    try {
      await AppServices.emergencyContactRepository.addContact(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        relation: _relation.text.trim(),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message.isNotEmpty
                ? e.message
                : 'Failed to save emergency contact.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save emergency contact.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final sheetColor = isDark ? const Color(0xFF1B1B1B) : Colors.white;

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    final labelColor = isDark
        ? Colors.white.withOpacity(0.76)
        : Colors.black.withOpacity(0.58);

    final infoColor = isDark
        ? Colors.white.withOpacity(0.66)
        : Colors.black.withOpacity(0.52);

    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.5, sigmaY: 5.5),
              child: Container(
                color: isDark
                    ? Colors.black.withOpacity(0.46)
                    : const Color(0xFF7A7692).withOpacity(0.50),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                decoration: BoxDecoration(
                  color: sheetColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Add Emergency Contact',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),

                      const SizedBox(height: 28),

                      _SheetInputField(
                        label: 'Name',
                        controller: _name,
                        focusNode: _nameFocus,
                        errorText: _nameError,
                        labelColor: labelColor,
                        textColor: textColor,
                        isDark: isDark,
                        enabled: !_isSaving,
                        keyboardType: TextInputType.name,
                        onBlur: () {
                          setState(() {
                            _nameError = _validateName(_name.text);
                          });
                        },
                        onChanged: (_) {
                          if (_nameError != null) {
                            setState(() => _nameError = null);
                          } else {
                            setState(() {});
                          }
                        },
                      ),

                      const SizedBox(height: 10),

                      _SheetInputField(
                        label: 'Phone no.',
                        controller: _phone,
                        focusNode: _phoneFocus,
                        errorText: _phoneError,
                        labelColor: labelColor,
                        textColor: textColor,
                        isDark: isDark,
                        enabled: !_isSaving,
                        keyboardType: TextInputType.phone,
                        onBlur: () {
                          setState(() {
                            _phoneError = _validatePhone(_phone.text);
                          });
                        },
                        onChanged: (_) {
                          if (_phoneError != null) {
                            setState(() => _phoneError = null);
                          } else {
                            setState(() {});
                          }
                        },
                      ),

                      const SizedBox(height: 10),

                      _SheetInputField(
                        label: 'Relation',
                        controller: _relation,
                        focusNode: _relationFocus,
                        errorText: _relationError,
                        labelColor: labelColor,
                        textColor: textColor,
                        isDark: isDark,
                        enabled: !_isSaving,
                        keyboardType: TextInputType.text,
                        onBlur: () {
                          setState(() {
                            _relationError =
                                _validateRelation(_relation.text);
                          });
                        },
                        onChanged: (_) {
                          if (_relationError != null) {
                            setState(() => _relationError = null);
                          } else {
                            setState(() {});
                          }
                        },
                      ),

                      const SizedBox(height: 14),

                      Opacity(
                        opacity: _isFormValid ? 1 : 0.45,
                        child: IgnorePointer(
                          ignoring: !_isFormValid,
                          child: GestureDetector(
                            onTap: _submit,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 263,
                              height: 51,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: Text(
                                _isSaving ? 'Saving...' : 'Save Contact',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  height: 1.0,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 26),

                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: const Color(0xFFF4AD35),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You can add up to 3 emergency contacts',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: infoColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final Color labelColor;
  final Color textColor;
  final bool isDark;
  final bool enabled;
  final TextInputType keyboardType;
  final VoidCallback onBlur;
  final ValueChanged<String> onChanged;

  const _SheetInputField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.errorText,
    required this.labelColor,
    required this.textColor,
    required this.isDark,
    required this.enabled,
    required this.keyboardType,
    required this.onBlur,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = errorText != null
        ? Colors.redAccent
        : isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.08);

    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus) onBlur();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.0,
              color: labelColor,
            ),
          ),

          const SizedBox(height: 8),

          Container(
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              enabled: enabled,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                color: textColor,
              ),
              onChanged: onChanged,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
              ),
            ),
          ),

          if (errorText != null) ...[
            const SizedBox(height: 5),
            Text(
              errorText!,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.redAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 3.0;
    const dashSpace = 3.0;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final extractPath = metric.extractPath(
          distance,
          distance + dashWidth,
        );
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

