import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';


class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  int? _expandedIndex;
  int _activeTab = 0; // 0 = FAQ, 1 = Contact

  final List<_FaqItem> _faqs = const [
    _FaqItem(
      question: 'What is this app used for?',
      answer:
          'This app helps users analyze their mental well-being by using questionnaires, mood tracking, and AI-based analysis. It provides insights, not medical diagnoses.',
    ),
    _FaqItem(
      question: 'Is this app a replacement for a therapist?',
      answer:
          'No. This app is not a substitute for professional mental health care. It is designed to support self-awareness and early understanding. For serious concerns, please consult a licensed mental health professional.',
    ),
    _FaqItem(
      question: 'How does the mental health analysis work?',
      answer:
          'The app uses your responses, mood logs, and behavior patterns to generate insights using AI models trained on psychological frameworks.',
    ),
    _FaqItem(
      question: 'Can I edit my profile information?',
      answer:
          'Yes, you can edit your username, date of birth, and profile picture from the Settings > Personal Information section.',
    ),
  ];

  Future<void> _callNumber(String phone) async {
    final cleaned = phone.trim();

    if (cleaned.isEmpty) {
      _showError('Phone number is not available.');
      return;
    }

    final uri = Uri(
      scheme: 'tel',
      path: cleaned,
    );

    try {
      final launched = await launchUrl(uri);

      if (!launched) {
        _showError('Could not open phone dialer.');
      }
    } catch (_) {
      _showError('Could not open phone dialer.');
    }
  }

  Future<void> _sendEmail(String email) async {
    final cleaned = email.trim();

    if (cleaned.isEmpty) {
      _showError('Email address is not available.');
      return;
    }

    final uri = Uri(
      scheme: 'mailto',
      path: cleaned,
    );

    try {
      final launched = await launchUrl(uri);

      if (!launched) {
        _showError('Could not open email app.');
      }
    } catch (_) {
      _showError('Could not open email app.');
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

    return PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) return;

      Navigator.pop(context);
    },
    child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,

        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              /// APP BAR
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Help center',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              /// TABS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeTab = 0;
                                _expandedIndex = null;
                              });
                            },
                            child: Center(
                              child: Text(
                                'FAQ',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _activeTab == 0
                                      ? (isDark
                                          ? AppColors.primaryDark
                                          : AppColors.primaryLight)
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _activeTab = 1;
                                _expandedIndex = null;
                              });
                            },
                            child: Center(
                              child: Text(
                                'Contact',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _activeTab == 1
                                      ? (isDark
                                          ? AppColors.primaryDark
                                          : AppColors.primaryLight)
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    /// SHARED DIVIDER + SLIDING INDICATOR
                    Stack(
                      children: [
                        Divider(
                          thickness: 1,
                          height: 1,
                          color: isDark
                              ? Colors.white.withOpacity(0.3)
                              : Colors.black.withOpacity(0.1),
                        ),
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          alignment: _activeTab == 0
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: 0.5,
                            child: Container(
                              height: 2,
                              color: isDark
                                  ? AppColors.primaryDark
                                  : AppColors.primaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// BODY
              Expanded(
                child: _activeTab == 0
                    ? _buildFaqList(isDark)
                    : _buildContactList(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// FAQ LIST
  Widget _buildFaqList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _faqs.length,
      itemBuilder: (context, index) {
        final isExpanded = _expandedIndex == index;
        return _FaqCard(
          item: _faqs[index],
          isExpanded: isExpanded,
          isDark: isDark,
          onTap: () {
            setState(() {
              _expandedIndex = isExpanded ? null : index;
            });
          },
        );
      },
    );
  }

  /// CONTACT LIST (REAL UI)
  Widget _buildContactList(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _ContactCard(
          name: 'Kanza Kashaf',
          role: 'AI Engineer @EMLY',
          phone: '03240497445',
          email: 'kanzakashaf56@gmail.com',
          imagePath: 'assets/images/kanza_dp.png',
          onCall: () => _callNumber('03240497445'),
          onEmail: () => _sendEmail('kanzakashaf56@gmail.com'),
        ),

        const SizedBox(height: 9),

        _ContactCard(
          name: 'Hassaan Raza',
          role: 'AI Engineer @EMLY',
          phone: '03200096255',
          email: 'hassaanxhk11@gmail.com',
          imagePath: 'assets/images/hassaan_dp.png',
          onCall: () => _callNumber('03200096255'),
          onEmail: () => _sendEmail('hassaanxhk11@gmail.com'),
        ),
      ],
    );
  }
}

/// ───────────────── FAQ CARD ─────────────────
class _FaqCard extends StatelessWidget {
  final _FaqItem item;
  final bool isExpanded;
  final bool isDark;
  final VoidCallback onTap;

  const _FaqCard({
    required this.item,
    required this.isExpanded,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2F2F2F)
            : const Color(0xFFF4F7FD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.question,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onTap,
                child: AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Image.asset(
                    'assets/images/LeftArrow.png',
                    width: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 12),
            Text(
              item.answer,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                height: 1.45,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ───────────────── CONTACT CARD ─────────────────

class _ContactCard extends StatelessWidget {
  final String name;
  final String role;
  final String phone;
  final String email;
  final String imagePath;
  final VoidCallback onCall;
  final VoidCallback onEmail;

  const _ContactCard({
    required this.name,
    required this.role,
    required this.phone,
    required this.email,
    required this.imagePath,
    required this.onCall,
    required this.onEmail,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    final subTextColor = isDark
        ? Colors.white.withOpacity(0.68)
        : Colors.black.withOpacity(0.58);

    final cardColor =
        isDark ? const Color(0xFF2F2F2F) : const Color(0xFFF4F7FD);

    final callButtonColor =
        isDark ? const Color(0xFF8579E0) : Colors.white;

    final emailButtonColor =
        isDark ? const Color(0xFF484848) : const Color(0xFFDCE1ED);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFD9D9D9),
                backgroundImage: AssetImage(imagePath),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
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

                    const SizedBox(height: 6),

                    Text(
                      role,
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
            ],
          ),

          const SizedBox(height: 27),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCall,
                  icon: Image.asset(
                    'assets/images/Phone.png',
                    width: 18,
                    height: 18,
                    color: primary,
                  ),
                  label: const Text('Call'),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: callButtonColor,
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 24),

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onEmail,
                  icon: Image.asset(
                    'assets/images/Email.png',
                    width: 18,
                    height: 18,
                    color: primary,
                  ),
                  label: const Text('E-mail'),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: emailButtonColor,
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ───────────────── MODEL ─────────────────
class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({
    required this.question,
    required this.answer,
  });
}