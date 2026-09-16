import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/keyboard_safe_scaffold.dart';
import '../../../../routes/app_routes.dart';
import 'package:flutter/gestures.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';
import '../../../../core/data/api/google_oauth_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _loginFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  String? _loginError;
  String? _passwordError;

  bool _agreeTerms = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isGoogleInitialized = false;

  bool _obscurePassword = true;

  bool _lockContinueUntilChange = false;

  // ---------------- VALIDATION ----------------

  String? _validateEmail(String value) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    if (value.isEmpty) return 'Email is required';
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String value) {
    final passwordRegex =
        RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*?&]).{8,}$');

    if (value.isEmpty) return 'Password is required';
    if (!passwordRegex.hasMatch(value)) {
      return 'Password must be at least 8 characters \n and contain letter, number & \n special character';
    }
    return null;
  }

  bool get _isFormValid {
    return _loginError == null &&
        _passwordError == null &&
        _loginController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _agreeTerms &&
        !_isLoading &&
        !_isGoogleLoading &&
        !_lockContinueUntilChange;
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

  Future<void> _ensureGoogleInitialized() async {
    if (_isGoogleInitialized) return;

    await GoogleSignIn.instance.initialize(
      serverClientId: GoogleOAuthConfig.webClientId,
    );

    _isGoogleInitialized = true;
  }

  Future<void> _routeAfterAuth({String? fallbackEmail}) async {
    final profile = await AppServices.userRepository.getMe();

    if (!mounted) return;

    if (!profile.isEmailVerified) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.accountCreationOtp,
        arguments: {
          'email': profile.email.isNotEmpty
              ? profile.email
              : (fallbackEmail ?? ''),
        },
      );
      return;
    }

    if (profile.needsProfileCompletion) {
      Navigator.pushReplacementNamed(context, AppRoutes.profileCompletion);
      return;
    }

    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  // ---------------- LOGIN FLOW ----------------
  Future<void> _handleLogin() async {
    setState(() {
      _loginError = _validateEmail(_loginController.text.trim());
      _passwordError = _validatePassword(_passwordController.text);
    });

    if (_loginError != null || _passwordError != null || !_agreeTerms) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AppServices.authRepository.login(
        email: _loginController.text.trim(),
        password: _passwordController.text,
      );

      await _routeAfterAuth(
        fallbackEmail: _loginController.text.trim(),
      );
    } on ApiError catch (e) {
      if (e.fieldErrors != null) {
        setState(() {
          _loginError = e.fieldErrors!['email']?.first;
          _passwordError = e.fieldErrors!['password']?.first;
        });
      }

      if (e.message.isNotEmpty) {
        _showError(e.message);
      }

      final isNetwork = _isNetworkErrorMessage(e.message);

      if (mounted) {
        setState(() => _lockContinueUntilChange = !isNetwork);
      }
    } catch (_) {
      _showError('Unable to sign in. Please try again.');
      if (mounted) {
        setState(() => _lockContinueUntilChange = false);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isLoading || _isGoogleLoading) return;

    if (!_agreeTerms) {
      _showError('Please agree to the Terms & Conditions first.');
      return;
    }

    HapticFeedback.selectionClick();

    setState(() => _isGoogleLoading = true);

    try {
      await _ensureGoogleInitialized();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        _showError('Google Sign-In is not supported on this device.');
        return;
      }

      final account = await GoogleSignIn.instance.authenticate();

      final authentication = account.authentication;
      final idToken = authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        _showError(
          'Could not get Google ID token. Please check Google OAuth setup.',
        );
        return;
      }

      await AppServices.authRepository.loginWithGoogle(
        idToken: idToken,
      );

      await _routeAfterAuth(
        fallbackEmail: account.email,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return;
      }

      _showError(
        e.description ?? 'Google Sign-In failed. Please try again.',
      );
    } on ApiError catch (e) {
      _showError(
        e.message.isNotEmpty
            ? e.message
            : 'Google Sign-In failed. Please try again.',
      );
    } catch (e) {
      debugPrint('GOOGLE LOGIN ERROR: $e');
      _showError('Google Sign-In failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
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
    _loginController.dispose();
    _passwordController.dispose();
    _loginFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.08);

    final dividerColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.06);

    final hintColor = Theme.of(context).colorScheme.onSurface.withOpacity(
          isDark ? 0.45 : 0.35,
        );

    final linkColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return KeyboardSafeScaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),

          const SizedBox(height: 40),

          /// TITLE
          Text(
            'Hello there!',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 14),

          /// SUBTITLE
          Text(
            'Sign in to continue your personalized\nmental wellness experience.',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15.5,
              fontWeight: FontWeight.w400,
              height: 1.35,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
          ),

          const SizedBox(height: 28),

          /// FORM
          Form(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Inputs container (rounded, subtle border)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _AuthTextField(
                        controller: _loginController,
                        hintText: 'Email',
                        focusNode: _loginFocus,
                        errorText: _loginError,
                        hintColor: hintColor,
                        textColor: Theme.of(context).colorScheme.onSurface,
                        keyboardType: TextInputType.emailAddress,
                        onBlur: () {
                          setState(() {
                            _loginError = _validateEmail(_loginController.text);
                          });
                        },
                        onChanged: (v) {
                          if (_lockContinueUntilChange) {
                            setState(() => _lockContinueUntilChange = false);
                          }
                          if (_loginError != null) {
                            setState(() => _loginError = _validateEmail(v));
                          }
                        },
                      ),

                      Divider(
                        height: 1,
                        thickness: 1,
                        color: dividerColor,
                      ),

                      _AuthTextField(
                        controller: _passwordController,
                        hintText: 'Password',
                        obscureText: _obscurePassword,
                        focusNode: _passwordFocus,
                        errorText: _passwordError,
                        hintColor: hintColor,
                        textColor: Theme.of(context).colorScheme.onSurface,
                        keyboardType: TextInputType.visiblePassword,
                        onBlur: () {
                          setState(() {
                            _passwordError =
                                _validatePassword(_passwordController.text);
                          });
                        },
                        onChanged: (v) {
                          if (_lockContinueUntilChange) {
                            setState(() => _lockContinueUntilChange = false);
                          }
                          if (_passwordError != null) {
                            setState(
                                () => _passwordError = _validatePassword(v));
                          }
                        },
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 20,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.55),
                          ),
                          onPressed: () => setState(() {
                            _obscurePassword = !_obscurePassword;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                /// Forget Password? (right aligned)
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.forgetPassword);
                    },
                    child: Text(
                      'Forget Password?',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: linkColor,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                /// TERMS (checkbox row)
                Row(
                  children: [
                    Checkbox(
                      value: _agreeTerms,
                      onChanged: (v) => setState(() {
                        _agreeTerms = v ?? false;
                        _lockContinueUntilChange = false;
                      }),
                      activeColor: linkColor,
                      checkColor: Colors.white,
                      shape: const CircleBorder(),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.25),
                        width: 1.2,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity:
                          const VisualDensity(horizontal: -2, vertical: -2),
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.8,
                            fontWeight: FontWeight.w400,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                          children: [
                            const TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: linkColor,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.termsConditions,
                                  );
                                },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          /// CONTINUE BUTTON (pill like design)
          Opacity(
            opacity: _isFormValid ? 1 : 0.5,
            child: IgnorePointer(
              ignoring: !_isFormValid,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: PrimaryButton(
                  // text: _isLoading ? 'Signing in...' : 'Continue',
                  text: _isLoading ? 'Checking...' : 'Continue',
                  onTap: _handleLogin,
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          /// OR divider row (short lines, centered)
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120, // adjust if you want slightly shorter/longer
                  height: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(isDark ? 0.18 : 0.14),
                ),
                const SizedBox(width: 22),
                Text(
                  'Or',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.45),
                  ),
                ),
                const SizedBox(width: 22),
                Container(
                  width: 120, // same width as left
                  height: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(isDark ? 0.18 : 0.14),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          /// Google login button (outlined pill)
          _GoogleButton(
            isDark: isDark,
            borderColor: borderColor,
            isLoading: _isGoogleLoading,
            onTap: _handleGoogleLogin,
          ),

          const SizedBox(height: 18),

          /// Bottom text
          Center(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
                children: [
                  const TextSpan(text: "Don't have an account? "),
                  TextSpan(
                    text: 'Sign up',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: linkColor,
                    ),
                    recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.signup,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

// ---------------- GOOGLE BUTTON ----------------

class _GoogleButton extends StatelessWidget {
  final bool isDark;
  final Color borderColor;
  final bool isLoading;
  final VoidCallback onTap;

  const _GoogleButton({
    required this.isDark,
    required this.borderColor,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.white.withOpacity(0.03)
        : Colors.black.withOpacity(0.01);

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: borderColor),
        ),
        child: isLoading
          ? const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/Google.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Text(
                  'Login with Google',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.8),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

// ---------------- FIELD WIDGET ----------------

class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final FocusNode focusNode;
  final String? errorText;
  final VoidCallback onBlur;
  final ValueChanged<String> onChanged;
  final Widget? suffixIcon;

  final Color hintColor;
  final Color textColor;
  final TextInputType keyboardType;

  const _AuthTextField({
    required this.controller,
    required this.hintText,
    required this.focusNode,
    required this.onBlur,
    required this.onChanged,
    required this.hintColor,
    required this.textColor,
    required this.keyboardType,
    this.errorText,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus) onBlur();
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        onChanged: onChanged,
        keyboardType: keyboardType,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
        cursorColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
            color: hintColor,
          ),
          border: InputBorder.none,
          errorText: errorText,
          errorStyle: const TextStyle(height: 0.8),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
