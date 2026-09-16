import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routes/app_routes.dart';

// API
import '../../../../main.dart';
import '../../../../core/data/api/api_error.dart';
import '../../../../core/data/repositories/knowledge_repository.dart';

class DataControlsScreen extends StatefulWidget {
  const DataControlsScreen({super.key});

  @override
  State<DataControlsScreen> createState() => _DataControlsScreenState();
}

class _DataControlsScreenState extends State<DataControlsScreen> {
  List<KnowledgeItemModel> _items = [];

  bool _loading = true;
  bool _clearingAll = false;
  bool _error = false;
  String? _deletingItemId;

  @override
  void initState() {
    super.initState();
    _loadKnowledge();
  }

  Future<void> _loadKnowledge() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final items = await AppServices.knowledgeRepository.getKnowledge();

      if (!mounted) return;

      setState(() {
        _items = items;
        _loading = false;
        _error = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = true;
      });

      _showError(
        e.message.isNotEmpty ? e.message : 'Failed to load saved memory.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = true;
      });

      _showError('Failed to load saved memory.');
    }
  }

  List<KnowledgeItemModel> get _personalItems {
    return _items.where((item) => !item.isClinical).toList();
  }

  List<KnowledgeItemModel> get _clinicalItems {
    return _items.where((item) => item.isClinical).toList();
  }

  bool get _hasItems => _items.isNotEmpty;

  Future<void> _deleteSingleMemory({required KnowledgeItemModel item}) async {
    if (_deletingItemId != null || _clearingAll) return;

    final confirmed = await _showDeleteMemoryConfirmation(
      title: 'Delete ${item.title}?',
      description:
          'This will remove this saved detail from EMLY’s memory. Your chat history will not be deleted.',
      confirmText: 'Yes, Delete',
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _deletingItemId = item.id);

    try {
      await AppServices.knowledgeRepository.deleteKnowledgeItem(item.id);

      if (!mounted) return;

      setState(() {
        _items.removeWhere((e) => e.id == item.id);
        _deletingItemId = null;
      });

      _showSuccess('${item.title} removed from EMLY’s memory.');
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() => _deletingItemId = null);

      _showError(
        e.message.isNotEmpty
            ? e.message
            : 'Failed to delete this saved memory.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _deletingItemId = null);
      _showError('Failed to delete this saved memory.');
    }
  }

  Future<void> _forgetEverything() async {
    if (!_hasItems || _clearingAll || _deletingItemId != null) return;

    final confirmed = await _showDeleteMemoryConfirmation(
      title: 'Clear EMLY’s memory?',
      description:
          'This will remove stored details used for personalization. Your chat history will not be deleted.',
      confirmText: 'Yes, Clear All',
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _clearingAll = true);

    try {
      await AppServices.knowledgeRepository.clearKnowledge();

      if (!mounted) return;

      setState(() {
        _items.clear();
        _clearingAll = false;
      });

      _showSuccess('EMLY’s memory has been cleared.');
    } on ApiError catch (e) {
      if (!mounted) return;

      setState(() => _clearingAll = false);

      _showError(
        e.message.isNotEmpty ? e.message : 'Failed to clear EMLY’s memory.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _clearingAll = false);
      _showError('Failed to clear EMLY’s memory.');
    }
  }

  Future<bool?> _showDeleteMemoryConfirmation({
    required String title,
    required String description,
    required String confirmText,
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
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 21),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.15),
                ),
              ),

              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                  color: isDark
                      ? Colors.white.withOpacity(0.78)
                      : const Color(0xFF676767),
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
                          'Cancel',
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

                  const SizedBox(width: 16),

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
                        child: Text(
                          confirmText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
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

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _startConversation() {
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.chat,
      arguments: {'startFresh': true},
    );
  }

  Widget _buildBody({
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required List<KnowledgeItemModel> personalItems,
    required List<KnowledgeItemModel> clinicalItems,
  }) {
    if (_loading) {
      return _DataControlsSkeleton(
        isDark: isDark,
        personalCount: personalItems.isNotEmpty ? personalItems.length : 3,
        clinicalCount: clinicalItems.length,
      );
    }

    if (_error && !_hasItems) {
      return RefreshIndicator(
        onRefresh: _loadKnowledge,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.62,
              child: _DataControlsEmptyState(
                isDark: isDark,
                icon: Icons.cloud_off_rounded,
                title: 'Memory did not load',
                subtitle:
                    'Your saved personalization details could not be loaded. Check your connection and try again.',
                buttonText: 'Retry',
                onTap: _loadKnowledge,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadKnowledge,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What Emly Knows',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 21,
                fontWeight: FontWeight.w700,
                height: 1.0,
                color: textColor,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Facts EMLY remembers to make conversations\nfeel continuous. Remove anything you’d rather\nshe forget.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: subTextColor,
              ),
            ),

            const SizedBox(height: 25),

            if (!_hasItems)
              _DataControlsEmptyState(
                isDark: isDark,
                icon: Icons.privacy_tip_rounded,
                title: 'No saved memory yet',
                subtitle:
                    'EMLY has not saved any personal or clinical details yet. As you chat, useful details for personalization may appear here.',
                buttonText: 'Start Conversation',
                onTap: _startConversation,
              ),

            if (personalItems.isNotEmpty) ...[
              const _SectionLabel(text: 'Personal'),
              const SizedBox(height: 8),

              ...List.generate(personalItems.length, (index) {
                final item = personalItems[index];
                final deletingThis = _deletingItemId == item.id;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: _MemoryCard(
                    item: item,
                    isDark: isDark,
                    isDeleting: deletingThis,
                    onDelete: deletingThis || _clearingAll
                        ? () {}
                        : () => _deleteSingleMemory(item: item),
                  ),
                );
              }),

              const SizedBox(height: 17),
            ],

            if (clinicalItems.isNotEmpty) ...[
              const _SectionLabel(text: 'Clinical'),
              const SizedBox(height: 8),

              ...List.generate(clinicalItems.length, (index) {
                final item = clinicalItems[index];
                final deletingThis = _deletingItemId == item.id;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: _MemoryCard(
                    item: item,
                    isDark: isDark,
                    isDeleting: deletingThis,
                    onDelete: deletingThis || _clearingAll
                        ? () {}
                        : () => _deleteSingleMemory(item: item),
                  ),
                );
              }),
            ],

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    final subTextColor = isDark
        ? Colors.white.withOpacity(0.56)
        : Colors.black.withOpacity(0.48);

    final personalItems = _personalItems;
    final clinicalItems = _clinicalItems;

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
                    onPressed: _clearingAll || _deletingItemId != null
                        ? null
                        : () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, size: 26, color: textColor),
                  ),
                  Text(
                    'Data Controls',
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
                child: _buildBody(
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  personalItems: personalItems,
                  clinicalItems: clinicalItems,
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: _loading
                    ? _DataControlsBottomButtonSkeleton(
                        isDark: isDark,
                        disabled: !_hasItems,
                      )
                    : GestureDetector(
                        onTap:
                            (!_hasItems ||
                                _clearingAll ||
                                _deletingItemId != null)
                            ? null
                            : _forgetEverything,
                        behavior: HitTestBehavior.opaque,
                        child: Opacity(
                          opacity:
                              (!_hasItems ||
                                  _clearingAll ||
                                  _deletingItemId != null)
                              ? 0.45
                              : 1,
                          child: Container(
                            width: double.infinity,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B40),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _clearingAll
                                      ? 'Clearing...'
                                      : 'Forget Everything',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    height: 1.0,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
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

class _DataControlsEmptyState extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onTap;

  const _DataControlsEmptyState({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final cardColor = isDark
        ? const Color(0xFF2B2B2B)
        : const Color(0xFFF4F7FD);

    final chipColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.94);

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.20)
                  : Colors.black.withOpacity(0.06),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 122,
                  height: 122,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary.withOpacity(isDark ? 0.18 : 0.10),
                  ),
                ),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary,
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.34),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 40, color: Colors.white),
                ),
                Positioned(
                  right: 0,
                  top: 14,
                  child: _MemoryMiniBadge(
                    isDark: isDark,
                    icon: Icons.lock_rounded,
                  ),
                ),
                Positioned(
                  left: 2,
                  bottom: 14,
                  child: _MemoryMiniBadge(
                    isDark: isDark,
                    icon: Icons.shield_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.15,
                color: onSurface,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: onSurface.withOpacity(0.62),
              ),
            ),

            const SizedBox(height: 18),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _MemoryFeatureChip(
                  label: 'Private control',
                  icon: Icons.tune_rounded,
                  color: primary,
                  backgroundColor: chipColor,
                ),
                _MemoryFeatureChip(
                  label: 'Easy delete',
                  icon: Icons.delete_sweep_rounded,
                  color: primary,
                  backgroundColor: chipColor,
                ),
              ],
            ),

            const SizedBox(height: 24),

            GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, primary.withOpacity(0.82)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      buttonText,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: Colors.white,
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
}

class _MemoryMiniBadge extends StatelessWidget {
  final bool isDark;
  final IconData icon;

  const _MemoryMiniBadge({required this.isDark, required this.icon});

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A3A3A) : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.22 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, size: 17, color: primary),
    );
  }
}

class _MemoryFeatureChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _MemoryFeatureChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.0,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DataControlsSkeleton extends StatelessWidget {
  final bool isDark;
  final int personalCount;
  final int clinicalCount;

  const _DataControlsSkeleton({
    required this.isDark,
    required this.personalCount,
    required this.clinicalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
      highlightColor: isDark
          ? const Color(0xFF3A3A3A)
          : const Color(0xFFF6F8FC),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SkeletonBox(width: 185, height: 24, radius: 8),

            const SizedBox(height: 10),

            const _SkeletonBox(width: double.infinity, height: 14, radius: 6),
            const SizedBox(height: 8),
            const _SkeletonBox(width: double.infinity, height: 14, radius: 6),
            const SizedBox(height: 8),
            const _SkeletonBox(width: 250, height: 14, radius: 6),

            const SizedBox(height: 25),

            if (personalCount > 0) ...[
              const _SkeletonBox(width: 72, height: 14, radius: 6),
              const SizedBox(height: 8),

              ...List.generate(
                personalCount,
                (index) => const Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: _MemoryCardSkeleton(),
                ),
              ),

              const SizedBox(height: 17),
            ],

            if (clinicalCount > 0) ...[
              const _SkeletonBox(width: 70, height: 14, radius: 6),
              const SizedBox(height: 8),

              ...List.generate(
                clinicalCount,
                (index) => const Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: _MemoryCardSkeleton(),
                ),
              ),
            ],

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}

class _MemoryCardSkeleton extends StatelessWidget {
  const _MemoryCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.fromLTRB(12, 12, 17, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 135, height: 16, radius: 6),
                SizedBox(height: 9),
                _SkeletonBox(width: double.infinity, height: 16, radius: 6),
              ],
            ),
          ),

          SizedBox(width: 14),

          _SkeletonBox(width: 24, height: 24, radius: 12),
        ],
      ),
    );
  }
}

class _DataControlsBottomButtonSkeleton extends StatelessWidget {
  final bool isDark;
  final bool disabled;

  const _DataControlsBottomButtonSkeleton({
    required this.isDark,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Shimmer.fromColors(
        baseColor: isDark ? const Color(0xFF2B2B2B) : const Color(0xFFE8ECF3),
        highlightColor: isDark
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF6F8FC),
        child: const _SkeletonBox(
          width: double.infinity,
          height: 48,
          radius: 25,
        ),
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

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.0,
        color: primary,
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final KnowledgeItemModel item;
  final bool isDark;
  final bool isDeleting;
  final VoidCallback onDelete;

  const _MemoryCard({
    required this.item,
    required this.isDark,
    required this.isDeleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark
        ? const Color(0xFF2B2B2B)
        : const Color(0xFFF4F7FD);

    final textColor = isDark ? Colors.white : const Color(0xFF252525);

    final subTextColor = isDark
        ? Colors.white.withOpacity(0.68)
        : Colors.black.withOpacity(0.58);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.fromLTRB(12, 12, 17, 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: Opacity(
              opacity: isDeleting ? 0.55 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    item.value.trim().isEmpty ? 'No detail' : item.value,
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
          ),

          GestureDetector(
            onTap: onDelete,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: isDeleting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.delete_outline_rounded,
                      size: 24,
                      color: Color(0xFFFF3B40),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
