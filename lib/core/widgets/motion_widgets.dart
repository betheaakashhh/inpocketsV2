import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// Wraps a child so it fades + slides up into place once, after an
/// optional [delay]. Stack a few of these with increasing delays (25-60ms
/// apart) to get a staggered list-entrance effect cheaply, without a
/// dependency on flutter_animate for the app's signature moments.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 16,
    this.duration = AppMotion.medium,
  });

  final Widget child;
  final Duration delay;
  final double offset;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: AppMotion.standard);
  late final Animation<Offset> _slide = Tween(
    begin: Offset(0, widget.offset / 100),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.emphasized));

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// The horizontal progress used across every Onboarding screen — a
/// pill-track that animates its fill width and a row of step dots that
/// morph from hollow -> filled -> check as the user advances.
class AnimatedStepProgress extends StatelessWidget {
  const AnimatedStepProgress({
    super.key,
    required this.totalSteps,
    required this.currentStep, // 0-indexed
  });

  final int totalSteps;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackColor = theme.brightness == Brightness.light
        ? AppColors.lightBorder
        : AppColors.darkBorder;

    return Row(
      children: List.generate(totalSteps, (index) {
        final isDone = index < currentStep;
        final isActive = index == currentStep;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 6),
            child: AnimatedContainer(
              duration: AppMotion.medium,
              curve: AppMotion.standard,
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                color: (isDone || isActive)
                    ? theme.colorScheme.primary
                    : trackColor,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// A slow, continuously-drifting soft gradient used behind the splash
/// and auth screens so they never feel like a static, empty form.
/// Cheap: two blurred circles animated with a single controller.
class AnimatedGradientBackground extends StatefulWidget {
  const AnimatedGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: bg),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            return Stack(
              children: [
                Positioned(
                  top: -140 + (t * 30),
                  right: -100 - (t * 20),
                  child: _blob(AppColors.indigo500.withOpacity(isDark ? 0.28 : 0.22), 320),
                ),
                Positioned(
                  bottom: -160 - (t * 20),
                  left: -120 + (t * 30),
                  child: _blob(AppColors.teal400.withOpacity(isDark ? 0.22 : 0.18), 280),
                ),
              ],
            );
          },
        ),
        widget.child,
      ],
    );
  }

  Widget _blob(Color color, double size) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
