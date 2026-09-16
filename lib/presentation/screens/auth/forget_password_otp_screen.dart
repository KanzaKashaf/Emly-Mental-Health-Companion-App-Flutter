import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../widgets/keyboard_safe_scaffold.dart';
import '../../../../routes/app_routes.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';

class ForgetPasswordOtpScreen extends StatefulWidget {
  const ForgetPasswordOtpScreen({super.key});

  @override
  State<ForgetPasswordOtpScreen> createState() =>
      _ForgetPasswordOtpScreenState();
}

class _ForgetPasswordOtpScreenState extends State<ForgetPasswordOtpScreen> {
  static const int _otpLength = 6;

  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());

  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;

  int _resendSeconds = 60;
  Timer? _resendTimer;

  String? _email;
  String? _screenError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_email != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map && args['email'] != null) {
      _email = args['email'].toString();
    }

    // Start cooldown because OTP was just sent from ForgetPasswordScreen.
    _startResendCooldown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();

    for (final c in _controllers) {
      c.dispose();
    }

    for (final f in _focusNodes) {
      f.dispose();
    }

    super.dispose();
  }

  String get _otp => _controllers.map((e) => e.text).join();

  bool get _isOtpComplete =>
      _controllers.every((c) => c.text.trim().isNotEmpty);

  bool get _canConfirm =>
      _isOtpComplete && !_isVerifying && !_isResending && _email != null;

  bool get _canResend =>
      !_isVerifying && !_isResending && _resendSeconds == 0 && _email != null;

  void _startResendCooldown() {
    _resendTimer?.cancel();

    setState(() => _resendSeconds = 60);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void _clearOtp() {
    for (final c in _controllers) {
      c.clear();
    }

    if (_focusNodes.isNotEmpty) {
      _focusNodes.first.requestFocus();
    }

    setState(() {});
  }

  void _onChanged(int index, String value) {
    if (_screenError != null) {
      setState(() => _screenError = null);
    }

    if (value.isEmpty) {
      setState(() {});
      return;
    }

    // Paste support
    if (value.length > 1) {
      final chars = value.replaceAll(RegExp(r'[^0-9]'), '').split('');

      int i = index;
      for (final ch in chars) {
        if (i >= _otpLength) break;

        _controllers[i].text = ch;
        _controllers[i].selection = TextSelection.fromPosition(
          const TextPosition(offset: 1),
        );
        i++;
      }

      if (i < _otpLength) {
        _focusNodes[i].requestFocus();
      } else {
        _focusNodes[_otpLength - 1].unfocus();
      }

      setState(() {});
      return;
    }

    // Normal single digit: move next
    if (index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }

    setState(() {});
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _focusNodes[index - 1].requestFocus();

        _controllers[index - 1].selection = TextSelection.fromPosition(
          TextPosition(offset: _controllers[index - 1].text.length),
        );

        setState(() {});
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Future<void> _verifyOtp() async {
    if (!_canConfirm) return;

    final email = _email;
    if (email == null || email.trim().isEmpty) {
      _showError('Email is missing. Please try again.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isVerifying = true;
      _screenError = null;
    });

    try {
      final result = await AppServices.authRepository.verifyOtp(
        email: email,
        code: _otp,
        purpose: 'password_reset',
      );

      if (!mounted) return;

      if (result.verified && result.resetToken != null) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.setNewPassword,
          arguments: {
            'resetToken': result.resetToken,
            'email': email,
          },
        );
        return;
      }

      final message = result.message.trim().isNotEmpty
          ? result.message
          : 'Invalid OTP. Please try again.';

      setState(() => _screenError = message);
      _showError(message);
      _clearOtp();
    } on ApiError catch (e) {
      final message = e.message.isNotEmpty
          ? e.message
          : 'Invalid OTP. Please try again.';

      if (mounted) {
        setState(() => _screenError = message);
      }

      _showError(message);
      _clearOtp();
    } catch (_) {
      _showError('Network error. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;

    final email = _email;
    if (email == null || email.trim().isEmpty) {
      _showError('Email is missing. Please go back and enter email again.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isResending = true;
      _screenError = null;
    });

    try {
      await AppServices.authRepository.sendOtp(
        email: email,
        purpose: 'password_reset',
      );

      if (!mounted) return;

      _clearOtp();
      _startResendCooldown();

      _showSuccess('Code resent. Check your email.');
    } on ApiError catch (e) {
      _showError(
        e.message.isNotEmpty ? e.message : 'Unable to resend code.',
      );
    } catch (_) {
      _showError('Network error. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
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

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final otpBoxColor =
        isDark ? const Color(0xFF454545) : const Color(0xFFEBEBEB);

    final titleColor = Theme.of(context).colorScheme.onSurface;
    final subColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.55);

    final emailText = _email ?? 'your email';

    return KeyboardSafeScaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          IconButton(
            onPressed: _isVerifying || _isResending
                ? null
                : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),

          const SizedBox(height: 40),

          Text(
            'Check your email',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: titleColor,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'We have sent OTP 6 digit code verification to $emailText.\n'
            'Enter code below.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15.5,
              fontWeight: FontWeight.w400,
              height: 1.35,
              color: subColor,
            ),
          ),

          const SizedBox(height: 36),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_otpLength, (i) {
              return _OtpBox(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                fillColor: otpBoxColor,
                textColor: titleColor,
                enabled: !_isVerifying && !_isResending,
                onChanged: (v) => _onChanged(i, v),
                onKey: (e) => _onKey(i, e),
              );
            }),
          ),

          if (_screenError != null) ...[
            const SizedBox(height: 12),
            Text(
              _screenError!,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: Colors.redAccent,
              ),
            ),
          ],

          const Spacer(),

          Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: _canResend ? 1 : 0.5,
                  child: IgnorePointer(
                    ignoring: !_canResend,
                    child: _PillButton(
                      text: _resendSeconds > 0
                          ? 'Resend $_resendSeconds'
                          : (_isResending ? 'Sending...' : 'Resend'),
                      isPrimary: false,
                      isDark: isDark,
                      onTap: _resendOtp,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Opacity(
                  opacity: _canConfirm ? 1 : 0.5,
                  child: IgnorePointer(
                    ignoring: !_canConfirm,
                    child: _PillButton(
                      text: _isVerifying ? 'Checking...' : 'Confirm',
                      isPrimary: true,
                      isDark: isDark,
                      onTap: _verifyOtp,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color fillColor;
  final Color textColor;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final KeyEventResult Function(KeyEvent event) onKey;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.fillColor,
    required this.textColor,
    required this.enabled,
    required this.onChanged,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Focus(
        onKeyEvent: (_, event) => onKey(event),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          cursorColor: textColor.withOpacity(0.6),
          decoration: InputDecoration(
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: textColor.withOpacity(0.22),
                width: 1.2,
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String text;
  final bool isPrimary;
  final bool isDark;
  final VoidCallback onTap;

  const _PillButton({
    required this.text,
    required this.isPrimary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final bg = isPrimary
        ? primary
        : (isDark ? Colors.white.withOpacity(0.10) : const Color(0xFFF3F5FF));

    final fg = isPrimary
        ? Colors.white
        : (isDark ? Colors.white.withOpacity(0.9) : primary);

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14.5,
            color: fg,
          ),
        ),
      ),
    );
  }
}