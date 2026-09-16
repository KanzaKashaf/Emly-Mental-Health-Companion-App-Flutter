import 'package:flutter/material.dart';

class KeyboardSafeScaffold extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final EdgeInsetsGeometry padding;

  const KeyboardSafeScaffold({
    super.key,
    required this.child,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(), 
          child: SingleChildScrollView(
            padding: padding.add(
              EdgeInsets.only(bottom: bottomInset + 24),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenHeight - topPadding,
              ),
              child: IntrinsicHeight(
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
