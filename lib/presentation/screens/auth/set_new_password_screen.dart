import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/keyboard_safe_scaffold.dart';
import '../../../../routes/app_routes.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';

class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  String? _passwordError;
  String? _confirmError;

  bool _isLoading = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _confirmChecked = false;

  String? _resetToken;
  String? _email;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_resetToken != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map) {
      _resetToken = args['resetToken']?.toString();
      _email = args['email']?.toString();
    }
  }

  String? _validatePassword(String value) {
    final passwordRegex = RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*?&]).{8,}$',
    );

    if (value.isEmpty) return 'Password is required';
    if (!passwordRegex.hasMatch(value)) {
      return 'Password must be at least 8 characters \n and contain letter, number & \n special character';
    }

    return null;
  }

  String? _validateConfirmPassword(String value) {
    if (value.isEmpty) return 'Confirm password is required';
    if (value != _password.text) return 'Passwords do not match';
    return null;
  }

  bool get _isFormValid {
    return !_isLoading &&
        _confirmChecked &&
        _password.text.isNotEmpty &&
        _confirmPassword.text.isNotEmpty &&
        _passwordError == null &&
        _confirmError == null &&
        _password.text == _confirmPassword.text;
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

  Future<void> _submit() async {
    setState(() {
      _passwordError = _validatePassword(_password.text);
      _confirmError = _validateConfirmPassword(_confirmPassword.text);
      _confirmChecked = true;
    });

    if (!_isFormValid) return;

    final token = _resetToken;

    if (token == null || token.trim().isEmpty) {
      _showError('Reset token is missing. Please request a new OTP.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final result = await AppServices.authRepository.resetPassword(
        resetToken: token,
        newPassword: _password.text,
      );

      if (!mounted) return;

      _showSuccess(
        result.message.trim().isNotEmpty
            ? result.message
            : 'Password updated successfully.',
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } on ApiError catch (e) {
      if (e.fieldErrors != null) {
        setState(() {
          _passwordError = e.fieldErrors!['password']?.first;
        });
      }

      final message = e.message.isNotEmpty
          ? e.message
          : 'Unable to update password. Please try again.';

      _showError(message);

      final isNetwork = _isNetworkErrorMessage(message);

      if (!isNetwork && message.toLowerCase().contains('expired')) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.forgetPassword,
          (route) => false,
        );
      }
    } catch (_) {
      _showError('Network error. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
  void dispose() {
    _password.dispose();
    _confirmPassword.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.08);

    final dividerColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.06);

    final hintColor = Theme.of(context)
        .colorScheme
        .onSurface
        .withOpacity(isDark ? 0.45 : 0.35);

    final titleColor = Theme.of(context).colorScheme.onSurface;
    final subColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.55);

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
            'Set a new password',
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
            _email == null
                ? 'Create a new password. Ensure it differs from previous ones for security.'
                : 'Create a new password for $_email. Ensure it differs from previous ones for security.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15.5,
              fontWeight: FontWeight.w400,
              height: 1.35,
              color: subColor,
            ),
          ),

          const SizedBox(height: 28),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) {
                      setState(() {
                        _passwordError = _validatePassword(_password.text);

                        if (_confirmChecked) {
                          _confirmChecked = false;
                          _confirmError = null;
                        }
                      });
                    }
                  },
                  child: TextField(
                    controller: _password,
                    focusNode: _passwordFocus,
                    enabled: !_isLoading,
                    obscureText: _obscurePassword,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                    cursorColor: titleColor.withOpacity(0.6),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w400,
                        color: hintColor,
                      ),
                      border: InputBorder.none,
                      errorText: _passwordError,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                          color: titleColor.withOpacity(0.55),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () => setState(() {
                                  _obscurePassword = !_obscurePassword;
                                }),
                      ),
                    ),
                    onChanged: (v) {
                      if (_passwordError != null) {
                        setState(() => _passwordError = _validatePassword(v));
                      } else {
                        setState(() {});
                      }

                      if (_confirmChecked) {
                        setState(() {
                          _confirmChecked = false;
                          _confirmError = null;
                        });
                      }
                    },
                  ),
                ),

                Divider(height: 1, thickness: 1, color: dividerColor),

                Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) {
                      setState(() {
                        _confirmError = _validateConfirmPassword(
                          _confirmPassword.text,
                        );
                        _confirmChecked = true;
                      });
                    }
                  },
                  child: TextField(
                    controller: _confirmPassword,
                    focusNode: _confirmFocus,
                    enabled: !_isLoading,
                    obscureText: _obscureConfirmPassword,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                    cursorColor: titleColor.withOpacity(0.6),
                    decoration: InputDecoration(
                      hintText: 'Confirm Password',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w400,
                        color: hintColor,
                      ),
                      border: InputBorder.none,
                      errorText: _confirmError,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                          color: titleColor.withOpacity(0.55),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () => setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                }),
                      ),
                    ),
                    onChanged: (v) {
                      if (_confirmChecked) {
                        setState(() {
                          _confirmChecked = false;
                          _confirmError = null;
                        });
                      } else {
                        setState(() {});
                      }
                    },
                  ),
                ),
              ],
            ),
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
                  text: _isLoading ? 'Updating...' : 'Update Password',
                  onTap: _submit,
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
