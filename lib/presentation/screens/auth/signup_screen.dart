import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';

import '../../../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/keyboard_safe_scaffold.dart';
import '../../../../routes/app_routes.dart';
import '../../widgets/avatar_utils.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _dob = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  // State
  String? _gender;
  Uint8List? _profileImageBytes;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _lockLetsKeepGoingUntilChange = false;

  // Errors
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _genderError;
  String? _dobError;

  Color? _avatarBgColor;
  final ImagePicker _picker = ImagePicker();

  // ---------------- HELPERS ----------------

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _dob.dispose();

    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();

    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null) return;

    final bytes = kIsWeb
        ? await image.readAsBytes()
        : await File(image.path).readAsBytes();

    setState(() {
      _profileImageBytes = bytes;
      _avatarBgColor = null;
    });
  }

  // ---------------- VALIDATION ----------------

  String? _validateName(String v) {
    final value = v.trim();
    if (value.isEmpty) return 'Name is required';
    if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(value)) return 'Only letters allowed';
    return null;
  }

  String? _validateEmail(String v) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (v.trim().isEmpty) return 'Email is required';
    if (!emailRegex.hasMatch(v)) return 'Enter a valid email';
    return null;
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

  bool get _isFormValid =>
      !_isLoading &&
      !_lockLetsKeepGoingUntilChange &&
      _name.text.isNotEmpty &&
      _email.text.isNotEmpty &&
      _password.text.isNotEmpty &&
      _dob.text.isNotEmpty &&
      _gender != null &&
      _nameError == null &&
      _emailError == null &&
      _passwordError == null &&
      _genderError == null &&
      _dobError == null;

  void _clearInlineErrors() {
    _nameError = null;
    _emailError = null;
    _passwordError = null;
    _dobError = null;
    _genderError = null;
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

  String _bestMessageFromApiError(ApiError e) {
    final fe = e.fieldErrors;
    if (fe != null && fe.isNotEmpty) {
      for (final key in [
        'name',
        'email',
        'password',
        'gender',
        'dateOfBirth',
        'profileImage',
        'general',
      ]) {
        final list = fe[key];
        if (list != null && list.isNotEmpty) return list.first;
      }

      final firstKey = fe.keys.first;
      final list = fe[firstKey];
      if (list != null && list.isNotEmpty) return list.first;
    }

    if (e.message.isNotEmpty && e.message != 'Validation error') {
      return e.message;
    }

    return 'Please check your signup details and try again.';
  }

  void _showApiError(ApiError e) {
    setState(() {
      _clearInlineErrors();

      final fe = e.fieldErrors;
      if (fe != null) {
        _nameError = fe['name']?.first;
        _emailError = fe['email']?.first;
        _passwordError = fe['password']?.first;
        _genderError = fe['gender']?.first;
        _dobError = fe['dateOfBirth']?.first;
      }
    });

    // debugPrint('SIGNUP API ERROR: $e');
    _showError(_bestMessageFromApiError(e));
  }

  // ---------------- SUBMIT ----------------

  Future<void> _submit() async {
    setState(() {
      _nameError = _validateName(_name.text);
      _emailError = _validateEmail(_email.text);
      _passwordError = _validatePassword(_password.text);
      _genderError = _gender == null ? 'Gender is required' : null;
      _dobError = _dob.text.isEmpty ? 'Date of birth is required' : null;
    });

    if (!_isFormValid) return;

    setState(() => _isLoading = true);

    try {
      await AppServices.authRepository.signup(
        email: _email.text.trim(),
        password: _password.text,
        name: _name.text.trim(),
        gender: _gender!,
        dateOfBirth: _dob.text.trim(),
        profileImage: '',
      );

      if (_profileImageBytes != null) {
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            _profileImageBytes!,
            filename: 'avatar.jpg',
          ),
        });

        await AppServices.apiClient.dio.post(
          '/users/me/avatar',
          data: formData,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.accountCreationOtp,
        arguments: {
          'email': _email.text.trim(),
        },
      );
    } on ApiError catch (e) {
      _showApiError(e);
      final isNetwork = _isNetworkErrorMessage(e.message);
      if (mounted) setState(() => _lockLetsKeepGoingUntilChange = !isNetwork);
    } catch (e) {
      debugPrint('SIGNUP UNKNOWN ERROR: $e');
      _showError('Network error. Please try again.');
      if (mounted) setState(() => _lockLetsKeepGoingUntilChange = false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintColor = Theme.of(context).colorScheme.onSurface.withOpacity(
          isDark ? 0.45 : 0.35,
        );

    return KeyboardSafeScaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                MediaQuery.of(context).size.height -
                MediaQuery.of(context).padding.top,
          ),
          child: IntrinsicHeight(
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
                const Text(
                  'Finish up your profile!',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 16),

                /// SUBTITLE
                Text(
                  'Help us personalize your experience by completing these basic details.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),

                const SizedBox(height: 24),

                /// AVATAR
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _pickProfileImage,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 92,
                              height: 92,
                              alignment: Alignment.center,
                              color: isDark
                                  ? const Color(0xFF2B2B2B)
                                  : const Color(0xFFF4F7FD),
                              child: _profileImageBytes != null
                                  ? Image.memory(
                                      _profileImageBytes!,
                                      width: 92,
                                      height: 92,
                                      fit: BoxFit.cover,
                                    )
                                  : (_name.text.trim().isNotEmpty
                                        ? Container(
                                            width: 92,
                                            height: 92,
                                            alignment: Alignment.center,
                                            color: AvatarUtils.colorFromName(
                                              _name.text.trim(),
                                            ),
                                            child: Text(
                                              AvatarUtils.firstLetter(
                                                _name.text.trim().toUpperCase(),
                                              ),
                                              style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 28,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          )
                                        : Image.asset(
                                            isDark
                                                ? 'assets/images/Person_Icon_DarkMode.png'
                                                : 'assets/images/Person_Icon_LightMode.png',
                                            width: 40,
                                            height: 40,
                                          )),
                            ),
                          ),
                        ),
                      ),

                      /// EDIT ICON
                      Positioned(
                        bottom: -6,
                        right: -6,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: _pickProfileImage,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? AppColors.primaryDark
                                    : AppColors.primaryLight,
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/Pen_Icon.png',
                                  width: 16,
                                  height: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                /// FORM
                Form(
                  key: _formKey,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.08),
                      ),
                    ),
                    child: Column(
                      children: [
                        _AuthTextField(
                          controller: _name,
                          hintText: 'Name',
                          focusNode: _nameFocus,
                          errorText: _nameError,
                          hintColor: hintColor,
                          textColor: Theme.of(context).colorScheme.onSurface,
                          onBlur: () {
                            setState(
                              () => _nameError = _validateName(_name.text),
                            );
                          },
                          onChanged: (v) {
                            if (_lockLetsKeepGoingUntilChange) {
                              setState(
                                () => _lockLetsKeepGoingUntilChange = false,
                              );
                            }
                            if (_nameError != null) {
                              setState(() => _nameError = null);
                            }
                          },
                        ),

                        _divider(isDark),

                        _AuthTextField(
                          controller: _email,
                          hintText: 'Email',
                          focusNode: _emailFocus,
                          errorText: _emailError,
                          hintColor: hintColor,
                          textColor: Theme.of(context).colorScheme.onSurface,
                          onBlur: () {
                            setState(
                              () => _emailError = _validateEmail(_email.text),
                            );
                          },
                          onChanged: (v) {
                            if (_lockLetsKeepGoingUntilChange) {
                              setState(
                                () => _lockLetsKeepGoingUntilChange = false,
                              );
                            }
                            if (_emailError != null) {
                              setState(() => _emailError = null);
                            }
                          },
                        ),

                        _divider(isDark),

                        _passwordField(isDark),
                        _divider(isDark),

                        _genderField(),
                        _divider(isDark),

                        _dateField(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                Opacity(
                  opacity: _isFormValid ? 1 : 0.5,
                  child: IgnorePointer(
                    ignoring: !_isFormValid,
                    child: PrimaryButton(
                      text: _isLoading ? 'Creating...' : "Let's keep going!",
                      onTap: _submit,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      children: [
                        const TextSpan(text: "Already have an account? "),
                        TextSpan(
                          text: 'Login',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.primaryDark
                                : AppColors.primaryLight,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.login,
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
          ),
        ),
      ),
    );
  }

  // ---------------- FIELDS ----------------

  Widget _divider(bool isDark) => Divider(
    height: 1,
    thickness: 1,
    color: isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.06),
  );

  Widget _passwordField(bool isDark) {
    final hintColor = Theme.of(context).colorScheme.onSurface.withOpacity(
          isDark ? 0.45 : 0.35,
        );
    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          setState(() {
            _passwordError = _validatePassword(_password.text);
          });
        }
      },
      child: TextField(
        controller: _password,
        focusNode: _passwordFocus,
        obscureText: _obscurePassword,
        onChanged: (v) {
          if (_lockLetsKeepGoingUntilChange) {
            setState(() => _lockLetsKeepGoingUntilChange = false);
          }
          if (_passwordError != null) {
            setState(() => _passwordError = null);
          }
        },
        decoration: InputDecoration(
          hintText: 'Password',
          hintStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
            color: hintColor,
          ),
          errorText: _passwordError,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ),
    );
  }

  Widget _genderField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintColor = Theme.of(context).colorScheme.onSurface.withOpacity(
          isDark ? 0.45 : 0.35,
        );
    return DropdownButtonFormField<String>(
      value: _gender,
      decoration: InputDecoration(
        hintText: 'Gender',
        hintStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14.5,
          fontWeight: FontWeight.w400,
          color: hintColor,
        ),
        errorText: _genderError,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'Male', child: Text('Male')),
        DropdownMenuItem(value: 'Female', child: Text('Female')),
        DropdownMenuItem(value: 'Other', child: Text('Other')),
      ],
      onChanged: (v) => setState(() {
        _gender = v;
        _genderError = null;
        _lockLetsKeepGoingUntilChange = false;
      }),
    );
  }

  Widget _dateField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintColor = Theme.of(context).colorScheme.onSurface.withOpacity(
          isDark ? 0.45 : 0.35,
        );
    return TextField(
      controller: _dob,
      readOnly: true,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime(2002, 1, 1),
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          setState(() {
            _dob.text =
                '${date.day.toString().padLeft(2, '0')}/'
                '${date.month.toString().padLeft(2, '0')}/'
                '${date.year}';
            _dobError = null;
            _lockLetsKeepGoingUntilChange = false;
          });
        }
      },
      decoration: InputDecoration(
        hintText: 'Date of Birth',
        hintStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14.5,
          fontWeight: FontWeight.w400,
          color: hintColor,
        ),
        errorText: _dobError,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
    );
  }
}

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

  const _AuthTextField({
    required this.controller,
    required this.hintText,
    required this.focusNode,
    required this.onBlur,
    required this.onChanged,
    required this.hintColor,
    required this.textColor,
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
