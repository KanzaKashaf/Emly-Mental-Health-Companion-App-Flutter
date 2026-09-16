import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/keyboard_safe_scaffold.dart';
import '../../../../routes/app_routes.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();

  String? _emailError;

  bool _isLoading = false;
  bool _lockButtonUntilChange = false;

  // ---------------- VALIDATION ----------------

  String? _validateEmail(String value) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (value.trim().isEmpty) return 'Email is required';
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }

    return null;
  }

  bool get _isFormValid {
    return !_isLoading &&
        !_lockButtonUntilChange &&
        _emailError == null &&
        _emailController.text.trim().isNotEmpty;
  }

  bool _isNetworkErrorMessage(String msg) {
    final m = msg.trim().toLowerCase();
    return m.contains('network error') ||
        m.contains('socket') ||
        m.contains('timeout') ||
        m.contains('timed out') ||
        m.contains('connection') ||
        m.contains('failed host') ||
        m.contains('no internet');
  }

  // ---------------- BACKEND FLOW ----------------

  Future<void> _sendResetOtp() async {
    setState(() {
      _emailError = _validateEmail(_emailController.text.trim());
    });

    if (_emailError != null) return;

    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();

      await AppServices.authRepository.sendOtp(
        email: email,
        purpose: 'password_reset',
      );

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        AppRoutes.forgetPasswordOtp,
        arguments: {
          'email': email,
        },
      );
    } on ApiError catch (e) {
      if (e.fieldErrors != null) {
        setState(() {
          _emailError = e.fieldErrors!['email']?.first;
        });
      }

      if (e.message.isNotEmpty) {
        _showError(e.message);
      }

      final isNetwork = _isNetworkErrorMessage(e.message);
      if (mounted) {
        setState(() => _lockButtonUntilChange = !isNetwork);
      }
    } catch (_) {
      _showError('Network error. Please try again.');
      if (mounted) {
        setState(() => _lockButtonUntilChange = false);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // ---------------- LIFECYCLE ----------------

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.08);

    final hintColor = Theme.of(context).colorScheme.onSurface.withOpacity(
          isDark ? 0.45 : 0.35,
        );

    return KeyboardSafeScaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          IconButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),

          const SizedBox(height: 40),

          Text(
            'Forget Password',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'Please enter your email to reset the password.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15.5,
              fontWeight: FontWeight.w400,
              height: 1.35,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),

          const SizedBox(height: 28),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) {
                      setState(() {
                        _emailError =
                            _validateEmail(_emailController.text.trim());
                      });
                    }
                  },
                  child: TextField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    cursorColor: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                    decoration: InputDecoration(
                      hintText: 'Email',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w400,
                        color: hintColor,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                    ),
                    onChanged: (v) {
                      if (_lockButtonUntilChange) {
                        setState(() => _lockButtonUntilChange = false);
                      }

                      if (_emailError != null) {
                        setState(() {
                          _emailError = _validateEmail(v.trim());
                        });
                      } else {
                        setState(() {});
                      }
                    },
                  ),
                ),
              ),

              if (_emailError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _emailError!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ],
          ),

          const Spacer(),

          Opacity(
            opacity: _isFormValid ? 1 : 0.5,
            child: IgnorePointer(
              ignoring: !_isFormValid,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: PrimaryButton(
                  text: _isLoading ? 'Sending OTP...' : 'Reset Password',
                  onTap: _sendResetOtp,
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
