import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../../../core/theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/keyboard_safe_scaffold.dart';
import '../../widgets/avatar_utils.dart';
import '../../../../routes/app_routes.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';

class PersonalInfoScreen extends StatefulWidget {
  final bool isProfileCompletion;

  const PersonalInfoScreen({
    super.key,
    this.isProfileCompletion = false,
  });

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  // ───────── CONTROLLERS
  late final TextEditingController _nameController;
  late final TextEditingController _dobController;

  // ───────── INITIAL VALUES (FROM BACKEND)
  String _initialName = '';
  String _initialDob = '';
  Uint8List? _initialProfileImageBytes;

  // ───────── STATE
  String? _nameError;
  bool _loading = true;
  bool _saving = false;

  Uint8List? _profileImageBytes;
  String? _profileImageUrl;

  final ImagePicker _picker = ImagePicker();

  String? _gender;
  String _initialGender = '';
  String? _genderError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _dobController = TextEditingController();
    _nameController.addListener(_onNameChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  // ───────── LOAD PROFILE
  Future<void> _loadProfile() async {
    try {
      final res = await AppServices.apiClient.dio.get('/users/me');
      final user = res.data;

      setState(() {
        _initialName = user['name'] ?? '';
        _initialDob = user['dateOfBirth'] ?? '';
        _gender = _normalizeGender(user['gender']);
        _initialGender = _gender ?? '';
        _profileImageUrl = user['profileImageUrl'];

        _nameController.text = _initialName;
        _dobController.text = _initialDob;

        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // ───────── VALIDATION
  void _onNameChanged() {
    final value = _nameController.text.trim();
    setState(() {
      _nameError = value.isEmpty ? 'User name cannot be empty' : null;
    });
  }

  bool get _hasChanges {
    return _nameController.text.trim() != _initialName ||
        _dobController.text.trim() != _initialDob ||
        _profileImageBytes != _initialProfileImageBytes;
  }

  bool get _isFormValid {
    if (_saving) return false;
    if (_nameError != null) return false;

    if (widget.isProfileCompletion) {
      return _nameController.text.trim().isNotEmpty &&
          _dobController.text.trim().isNotEmpty &&
          _gender != null;
    }

    return _hasChanges;
  }

  String? _normalizeGender(dynamic value) {
    final raw = (value ?? '').toString().trim();

    if (raw.isEmpty) return null;

    final lower = raw.toLowerCase();

    if (lower == 'male') return 'Male';
    if (lower == 'female') return 'Female';
    if (lower == 'other') return 'Other';

    // Backend may return: not_specified, unknown, null, etc.
    // Dropdown should show empty selection for these.
    return null;
  }

  // ───────── IMAGE PICKER
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
    });
  }

  // ───────── DATE PICKER
  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2002, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _dobController.text =
            '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/'
            '${date.year}';
      });
    }
  }

  // ───────── SAVE
  Future<void> _save() async {
    if (!_isFormValid) return;

    if (widget.isProfileCompletion) {
      setState(() {
        _nameError = _nameController.text.trim().isEmpty
            ? 'User name cannot be empty'
            : null;
        _genderError = _gender == null ? 'Gender is required' : null;
      });

      if (_nameError != null ||
          _genderError != null ||
          _dobController.text.trim().isEmpty) {
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'dateOfBirth': _dobController.text.trim(),
      };

      if (widget.isProfileCompletion && _gender != null) {
        payload['gender'] = _gender;
      }

      final res = await AppServices.userRepository.updateProfile(payload);

      if (_profileImageBytes != null) {
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            _profileImageBytes!,
            filename: 'avatar.jpg',
          ),
        });

        final avatarRes = await AppServices.apiClient.dio.post(
          '/users/me/avatar',
          data: formData,
        );

        _profileImageUrl = avatarRes.data['profileImageUrl'];
        _profileImageBytes = null;
      }

      _initialName = res.name ?? _initialName;
      _initialDob = _dobController.text.trim();
      _initialGender = _gender ?? _initialGender;

      if (!mounted) return;

      if (widget.isProfileCompletion) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (route) => false,
        );
      } else {
        Navigator.pop(context, true);
      }
    } on ApiError catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Failed to save profile');
    } finally {
      if (mounted) setState(() => _saving = false);
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

  // ───────── UI
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
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
                    if (!widget.isProfileCompletion)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                      )
                    else
                      const SizedBox(width: 48),
                    const SizedBox(width: 4),
                    Text(
                      widget.isProfileCompletion
                          ? 'Complete Profile'
                          : 'Personal Info',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              /// CONTENT SKELETON
              Expanded(
                child: KeyboardSafeScaffold(
                  backgroundColor: Colors.transparent,
                  child: _PersonalInfoSkeleton(
                    isDark: isDark,
                    showGenderField: widget.isProfileCompletion,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
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
                  if (!widget.isProfileCompletion)
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    )
                  else
                    const SizedBox(width: 48),
                  const SizedBox(width: 4),
                  Text(
                    widget.isProfileCompletion ? 'Complete Profile' : 'Personal Info',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            /// CONTENT
            Expanded(
              child: KeyboardSafeScaffold(
                backgroundColor: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 52),

                    /// AVATAR
                    Center(
                      child: Stack(
                        children: [
                          ClipOval(
                            child: Container(
                              width: 140,
                              height: 140,
                              alignment: Alignment.center,
                              color: _profileImageBytes == null &&
                                      _profileImageUrl == null
                                  ? AvatarUtils.colorFromName(
                                      _nameController.text)
                                  : (isDark
                                      ? const Color(0xFF2B2B2B)
                                      : const Color(0xFFF1F3F8)),
                              child: _profileImageBytes != null
                                  ? Image.memory(
                                      _profileImageBytes!,
                                      fit: BoxFit.cover,
                                      width: 140,
                                      height: 140,
                                    )
                                  : (_profileImageUrl != null
                                      ? Image.network(
                                          _profileImageUrl!,
                                          fit: BoxFit.cover,
                                          width: 140,
                                          height: 140,
                                        )
                                      : Text(
                                          AvatarUtils.firstLetter(
                                              _nameController.text),
                                          style: const TextStyle(
                                            fontSize: 48,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        )),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
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
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 56),

                    _label('User Name'),
                    const SizedBox(height: 8),
                    _editableField(
                      controller: _nameController,
                      icon: 'assets/images/Pen_Icon.png',
                      isDark: isDark,
                      errorText: _nameError,
                    ),

                    const SizedBox(height: 20),

                    _label('Date of Birth'),
                    const SizedBox(height: 8),
                    _editableField(
                      controller: _dobController,
                      icon: 'assets/images/Calender.png',
                      isDark: isDark,
                      readOnly: true,
                      onIconTap: _pickDate,
                    ),

                    if (widget.isProfileCompletion) ...[
                      const SizedBox(height: 20),

                      _label('Gender'),
                      const SizedBox(height: 8),
                      _genderField(isDark),
                    ],

                    SizedBox(
                      height: widget.isProfileCompletion ? 116 : 136,
                    ),

                    Opacity(
                      opacity: _isFormValid ? 1 : 0.5,
                      child: IgnorePointer(
                        ignoring: !_isFormValid,
                        child: PrimaryButton(
                          text: _saving ? 'Saving...' : 'Save',
                          onTap: _save,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────── HELPERS
  Widget _label(String text) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
  );

  Widget _editableField({
    required TextEditingController controller,
    required String icon,
    required bool isDark,
    VoidCallback? onIconTap,
    bool readOnly = false,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: errorText != null
                  ? Colors.redAccent
                  : isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: readOnly,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onIconTap,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Image.asset(
                    icon,
                    width: 18,
                    height: 18,
                    color: isDark
                        ? Colors.white.withOpacity(0.6)
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          const Text(
            'User name cannot be empty',
            style: TextStyle(fontSize: 12, color: Colors.redAccent),
          ),
        ],
      ],
    );
  }

  Widget _genderField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _genderError != null
                  ? Colors.redAccent
                  : isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.08),
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: ['Male', 'Female', 'Other'].contains(_gender) ? _gender : null,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            hint: const Text('Select gender'),
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (v) {
              setState(() {
                _gender = v;
                _genderError = null;
              });
            },
          ),
        ),
        if (_genderError != null) ...[
          const SizedBox(height: 6),
          Text(
            _genderError!,
            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
          ),
        ],
      ],
    );
  }
}

class _PersonalInfoSkeleton extends StatelessWidget {
  final bool isDark;
  final bool showGenderField;

  const _PersonalInfoSkeleton({
    required this.isDark,
    required this.showGenderField,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
      highlightColor:
          isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF6F8FC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 52),

          /// AVATAR SKELETON
          Center(
            child: Stack(
              children: const [
                _SkeletonCircle(size: 140),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _SkeletonCircle(size: 36),
                ),
              ],
            ),
          ),

          const SizedBox(height: 56),

          const _SkeletonBox(width: 74, height: 13, radius: 6),
          const SizedBox(height: 8),
          const _ProfileFieldSkeleton(),

          const SizedBox(height: 20),

          const _SkeletonBox(width: 82, height: 13, radius: 6),
          const SizedBox(height: 8),
          const _ProfileFieldSkeleton(),

          if (showGenderField) ...[
            const SizedBox(height: 20),

            const _SkeletonBox(width: 50, height: 13, radius: 6),
            const SizedBox(height: 8),
            const _ProfileFieldSkeleton(),
          ],

          SizedBox(
            height: showGenderField ? 116 : 136,
          ),

          const _SkeletonBox(
            width: double.infinity,
            height: 54,
            radius: 28,
          ),
        ],
      ),
    );
  }
}

class _ProfileFieldSkeleton extends StatelessWidget {
  const _ProfileFieldSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Row(
        children: [
          Expanded(
            child: _SkeletonBox(
              width: double.infinity,
              height: 16,
              radius: 6,
            ),
          ),
          SizedBox(width: 14),
          _SkeletonBox(width: 18, height: 18, radius: 5),
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
