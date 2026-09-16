import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    final subTextColor = isDark
        ? Colors.white.withOpacity(0.70)
        : Colors.black.withOpacity(0.58);

    final cardColor =
        isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF4F7FD);

    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

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
                  Expanded(
                    child: Text(
                      'Terms & Conditions',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),

              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  radius: const Radius.circular(10),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Please read before using EMLY.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.22,
                            color: textColor,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          'By creating an account or using EMLY, you agree to the terms below. These terms explain what EMLY does, what it does not do, and how your information is handled inside the app.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w400,
                            height: 1.55,
                            color: subTextColor,
                          ),
                        ),

                        const SizedBox(height: 20),

                        _ImportantNoticeCard(
                          isDark: isDark,
                          primary: primary,
                        ),

                        const SizedBox(height: 18),

                        _TermsSection(
                          number: '1',
                          title: 'Purpose of EMLY',
                          body:
                              'EMLY is a mental wellness support application designed to provide supportive conversation, structured symptom screening, mood tracking, CBT-based activities, progress summaries, and self-reflection tools. EMLY is intended to support personal awareness and wellness, not to replace professional care.',
                          cardColor: cardColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          primary: primary,
                        ),

                        _TermsSection(
                          number: '2',
                          title: 'Not a Medical or Diagnostic Service',
                          body:
                              'EMLY does not provide medical diagnosis, clinical treatment, emergency intervention, or professional medical advice. Any screening report, summary, confidence score, severity level, CBT plan, or recommendation provided by EMLY is for educational and supportive purposes only. You should consult a qualified mental health professional for diagnosis, treatment, medication, or clinical decisions.',
                          cardColor: cardColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          primary: primary,
                        ),

                        _TermsSection(
                          number: '3',
                          title: 'Emergency and Crisis Situations',
                          body:
                              'EMLY is not an emergency service. If you feel at risk of harming yourself or someone else, or if you are in immediate danger, you should contact local emergency services, a crisis helpline, or a trusted person immediately. EMLY may show crisis resources or emergency contact options, but it cannot replace emergency responders or clinical crisis care.',
                          cardColor: cardColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          primary: primary,
                        ),

                        _TermsSection(
                          number: '4',
                          title: 'AI Conversations and Limitations',
                          body:
                              'EMLY uses AI-assisted conversation to respond empathetically and help collect information for structured screening. AI responses may sometimes be incomplete, inaccurate, or not fully suited to your personal situation. You should not rely only on AI responses for important health, safety, legal, or medical decisions.',
                          cardColor: cardColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          primary: primary,
                        ),

                        _TermsSection(
                          number: '5',
                          title: 'Structured Screening Reports',
                          body:
                              'EMLY may generate screening reports based on your responses. These reports are not diagnoses. They are structured summaries intended to help you understand possible concerns and prepare for a conversation with a qualified professional. Report results depend on the information you provide and may not reflect your complete mental health condition.',
                          cardColor: cardColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          primary: primary,
                        ),

                        _TermsSection(
                          number: '6',
                          title: 'CBT Activities and Progress Tracking',
                          body:
                              'EMLY may provide CBT-based activities such as mood check-ins, thought records, sleep habits, gratitude logs, pleasant activities, self-compassion exercises, weekly reviews, and progress evaluation. These tools are for self-help and wellness support. They are not a replacement for therapy with a licensed professional.',
                          cardColor: cardColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          primary: primary,
                        ),

                        _TermsSection(
                          number: '7',
                          title: 'Appointments and Doctors',
                          body:
                              'EMLY may allow you to view doctors, request appointments, and manage appointment status. Appointment requests depend on backend availability and professional confirmation. EMLY does not guarantee that a doctor will accept, confirm, or respond to every request. Any medical care is provided by the professional, not by EMLY itself.',
                          cardColor: cardColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          primary: primary,
                        ),

                        _TermsSection(
                          number: '8',
                          title: 'Your Account Responsibility',
                          body:
                              'You are responsible for keeping your login information secure and for providing accurate information during signup, screening, CBT activities, and appointment requests. If you believe your account has been accessed without permission, you should change your password or contact support as soon as possible.',
                          cardColor: cardColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          primary: primary,
                        ),

                        _TermsSection(
                          number: '9',
                          title: 'Data and Privacy',
                          body:
                              'EMLY stores information needed to provide app features, such as profile details, chat sessions, screening responses, CBT activity progress, reports, appointments, emergency contacts, subscription status, and saved personalization details. Your data is used to support your app experience, maintain continuity, and generate relevant summaries or progress insights.',
                          cardColor: cardColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          primary: primary,
                        ),

                        _TermsSection(
                          number: '10',
                          title: 'Data Controls',
                          body:
                              'EMLY may remember selected details to make conversations feel continuous. You can review and delete saved memory from the Data Controls screen. You may also delete chat history, manage emergency contacts, update your profile, or cancel premium features where available.',
                          cardColor: cardColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          primary: primary,
                        ),

                        _TermsSection(
                          number: '11',
                          title: 'Premium Subscription',
                          body:
                              'Some features may be limited for free users and may require Premium access. Premium may provide expanded usage, additional sessions, voice conversations, or other advanced features. Subscription status, limits, expiry, and availability are controlled by the backend subscription system.',
                          cardColor: cardColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          primary: primary,
                        ),

                        _TermsSection(
                          number: '12',
                          title: 'Acceptable Use',
                          body:
                              'You agree not to misuse EMLY, attempt to access another user’s account, upload harmful content, abuse emergency features, interfere with the backend, or use the app for unlawful purposes. EMLY may restrict access if misuse is detected.',
                          cardColor: cardColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          primary: primary,
                        ),

                        _TermsSection(
                          number: '13',
                          title: 'Changes to the App or Terms',
                          body:
                              'EMLY may update features, screens, backend services, limits, or these terms as the project improves. Continued use of the app after changes means you accept the updated terms.',
                          cardColor: cardColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          primary: primary,
                        ),

                        _TermsSection(
                          number: '14',
                          title: 'Agreement',
                          body:
                              'By signing up, logging in, or checking the Terms & Conditions checkbox, you confirm that you understand EMLY is a supportive mental wellness app, not a clinical diagnosis or emergency service. You agree to use EMLY responsibly and seek professional or emergency help when needed.',
                          cardColor: cardColor,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          primary: primary,
                        ),

                        const SizedBox(height: 12),

                        Text(
                          'Last updated: May 2026',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: subTextColor,
                          ),
                        ),

                        const SizedBox(height: 20),
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

class _ImportantNoticeCard extends StatelessWidget {
  final bool isDark;
  final Color primary;

  const _ImportantNoticeCard({
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? const Color(0xFF2B2B2B)
        : const Color(0xFFFFF1DB);

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    final subTextColor = isDark
        ? Colors.white.withOpacity(0.74)
        : Colors.black.withOpacity(0.62);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : const Color(0xFFF4AD35).withOpacity(0.30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 22,
            color: isDark ? primary : const Color(0xFFF4AD35),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  color: subTextColor,
                ),
                children: [
                  TextSpan(
                    text: 'Important: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const TextSpan(
                    text:
                        'EMLY is not a doctor, therapist, emergency service, or diagnostic tool. If you are in immediate danger, contact emergency services or a trusted person right away.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  final String number;
  final String title;
  final String body;
  final Color cardColor;
  final Color textColor;
  final Color subTextColor;
  final Color primary;

  const _TermsSection({
    required this.number,
    required this.title,
    required this.body,
    required this.cardColor,
    required this.textColor,
    required this.subTextColor,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 27,
            height: 27,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  body,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    height: 1.48,
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