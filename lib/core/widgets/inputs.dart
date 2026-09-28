import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.prefixIcon,
    this.prefixText,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.maxLength,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final String? prefixText;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          obscureText: obscureText,
          enabled: enabled,
          autofocus: autofocus,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          maxLength: maxLength,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 20, color: theme.colorScheme.onSurface.withOpacity(0.5))
                : null,
            prefixText: prefixText,
            prefixStyle: theme.textTheme.bodyLarge,
          ),
        ),
        AnimatedSize(
          duration: AppMotion.fast,
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.danger),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          errorText!,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// A 6-digit OTP entry widget: individually boxed digits, auto-advancing
/// focus, backspace jumps to the previous box, and a horizontal shake
/// when [hasError] flips true (e.g. after a rejected OTP comes back
/// from the server).
class OtpInputField extends StatefulWidget {
  const OtpInputField({
    super.key,
    required this.length,
    required this.onCompleted,
    this.onChanged,
    this.hasError = false,
    this.enabled = true,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool hasError;
  final bool enabled;

  @override
  State<OtpInputField> createState() => OtpInputFieldState();
}

class OtpInputFieldState extends State<OtpInputField>
    with SingleTickerProviderStateMixin {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _nodes = List.generate(widget.length, (_) => FocusNode());
    _shakeController = AnimationController(
      vsync: this,
      duration: AppMotion.medium,
    );
  }

  @override
  void didUpdateWidget(covariant OtpInputField old) {
    super.didUpdateWidget(old);
    if (widget.hasError && !old.hasError) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  /// Called externally after a failed attempt so the boxes clear and
  /// focus returns to the first box, ready to retype.
  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    _nodes.first.requestFocus();
    setState(() {});
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _handleChange(int index, String value) {
    if (value.length > 1) {
      // Handles pasted OTPs landing in a single box.
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < widget.length; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      final lastIndex = (digits.length - 1).clamp(0, widget.length - 1);
      _nodes[lastIndex].requestFocus();
    } else if (value.isNotEmpty) {
      if (index < widget.length - 1) {
        _nodes[index + 1].requestFocus();
      } else {
        _nodes[index].unfocus();
      }
    }

    setState(() {});
    widget.onChanged?.call(_code);
    if (_code.length == widget.length) {
      widget.onCompleted(_code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final t = _shakeController.value;
        final offset = t == 0 ? 0.0 : (8 * (1 - t)) * _shakeSign(t);
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(widget.length, (index) {
          final filled = _controllers[index].text.isNotEmpty;
          final borderColor = widget.hasError
              ? AppColors.danger
              : filled
                  ? theme.colorScheme.primary
                  : (theme.brightness == Brightness.light
                      ? AppColors.lightBorder
                      : AppColors.darkBorder);

          return SizedBox(
            width: 48,
            height: 56,
            child: AnimatedContainer(
              duration: AppMotion.instant,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: borderColor, width: filled ? 1.8 : 1.2),
                color: theme.brightness == Brightness.light
                    ? AppColors.lightSurfaceAlt
                    : AppColors.darkSurfaceAlt,
              ),
              child: Center(
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _nodes[index],
                  enabled: widget.enabled,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: widget.length, // allows paste-into-one-box
                  style: theme.textTheme.headlineSmall,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => _handleChange(index, v),
                  onTap: () {
                    _controllers[index].selection = TextSelection.fromPosition(
                      TextPosition(offset: _controllers[index].text.length),
                    );
                  },
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  double _shakeSign(double t) {
    // Oscillates +1/-1 a few times over the animation's lifetime.
    final wave = (t * 6).floor();
    return wave.isEven ? 1 : -1;
  }
}
