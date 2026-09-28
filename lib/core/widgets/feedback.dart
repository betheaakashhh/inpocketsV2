import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// Self-contained shimmer effect (no external package) — a soft
/// highlight band sweeps across a placeholder shape on a loop, used
/// everywhere content is loading instead of a plain spinner.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = AppSpacing.radiusSm,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt;
    final highlight = isDark ? AppColors.darkBorder : Colors.white;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final t = _controller.value;
              return LinearGradient(
                begin: Alignment(-1 - t * 2, 0),
                end: Alignment(1 - t * 2, 0),
                colors: [base, highlight, base],
                stops: const [0.35, 0.5, 0.65],
              ).createShader(bounds);
            },
            child: Container(
              width: widget.width,
              height: widget.height,
              color: base,
            ),
          ),
        );
      },
    );
  }
}

enum StatusTone { success, warning, danger, info, neutral }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.tone});

  factory StatusChip.forLoanStatus(String status) {
    switch (status) {
      case 'APPROVED':
        return StatusChip(label: 'Approved', tone: StatusTone.success);
      case 'REJECTED':
        return StatusChip(label: 'Rejected', tone: StatusTone.danger);
      case 'CANCELLED':
        return StatusChip(label: 'Cancelled', tone: StatusTone.neutral);
      case 'EXPIRED':
        return StatusChip(label: 'Expired', tone: StatusTone.neutral);
      case 'MANUAL_REVIEW':
        return StatusChip(label: 'In review', tone: StatusTone.warning);
      case 'PENDING_ADDITIONAL_INFORMATION':
        return StatusChip(label: 'Action needed', tone: StatusTone.warning);
      case 'PROCESSING':
        return StatusChip(label: 'Processing', tone: StatusTone.info);
      case 'SUBMITTED':
        return StatusChip(label: 'Submitted', tone: StatusTone.info);
      case 'DRAFT':
      default:
        return StatusChip(label: 'Draft', tone: StatusTone.neutral);
    }
  }

  factory StatusChip.forVerificationStatus(String status) {
    switch (status) {
      case 'VERIFIED':
        return StatusChip(label: 'Verified', tone: StatusTone.success);
      case 'FAILED':
        return StatusChip(label: 'Failed', tone: StatusTone.danger);
      case 'MANUAL_REVIEW':
        return StatusChip(label: 'In review', tone: StatusTone.warning);
      case 'RETRY_REQUIRED':
        return StatusChip(label: 'Retry needed', tone: StatusTone.warning);
      case 'PROCESSING':
        return StatusChip(label: 'Processing', tone: StatusTone.info);
      case 'PENDING':
        return StatusChip(label: 'Pending', tone: StatusTone.info);
      case 'NOT_STARTED':
      default:
        return StatusChip(label: 'Not started', tone: StatusTone.neutral);
    }
  }

  final String label;
  final StatusTone tone;

  ({Color fg, Color bg}) _colors() {
    switch (tone) {
      case StatusTone.success:
        return (fg: AppColors.success, bg: AppColors.successBg);
      case StatusTone.warning:
        return (fg: AppColors.warning, bg: AppColors.warningBg);
      case StatusTone.danger:
        return (fg: AppColors.danger, bg: AppColors.dangerBg);
      case StatusTone.info:
        return (fg: AppColors.info, bg: AppColors.infoBg);
      case StatusTone.neutral:
        return (fg: AppColors.lightTextSecondary, bg: const Color(0xFFEDEEF5));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c.fg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// A circle that draws itself, then a checkmark strokes in across it —
/// hand-built with [CustomPainter] + [PathMetric] so there's no
/// dependency on a Lottie asset file. Used after a loan submission,
/// after OTP success, and once onboarding completes.
class SuccessCheckAnimation extends StatefulWidget {
  const SuccessCheckAnimation({super.key, this.size = 96, this.color});

  final double size;
  final Color? color;

  @override
  State<SuccessCheckAnimation> createState() => _SuccessCheckAnimationState();
}

class _SuccessCheckAnimationState extends State<SuccessCheckAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.deliberate,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.success;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _CheckPainter(progress: _controller.value, color: color),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final circleProgress = (progress / 0.65).clamp(0.0, 1.0);
    final checkProgress = ((progress - 0.55) / 0.45).clamp(0.0, 1.0);

    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    // Soft filled backdrop grows in with the circle stroke.
    final fillPaint = Paint()..color = color.withOpacity(0.12 * circleProgress);
    canvas.drawCircle(center, radius, fillPaint);

    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      -math.pi / 2,
      2 * math.pi * circleProgress,
      false,
      circlePaint,
    );

    if (checkProgress <= 0) return;

    final checkPath = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.74, size.height * 0.34);

    final metrics = checkPath.computeMetrics().first;
    final extractedPath = metrics.extractPath(0, metrics.length * checkProgress);

    final checkPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(extractedPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

enum ToastType { success, error, info }

void showAppSnackbar(
  BuildContext context,
  String message, {
  ToastType type = ToastType.info,
}) {
  final theme = Theme.of(context);
  final Color bg;
  final IconData icon;
  switch (type) {
    case ToastType.success:
      bg = AppColors.success;
      icon = Icons.check_circle_rounded;
      break;
    case ToastType.error:
      bg = AppColors.danger;
      icon = Icons.error_rounded;
      break;
    case ToastType.info:
      bg = theme.colorScheme.primary;
      icon = Icons.info_rounded;
      break;
  }

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        margin: const EdgeInsets.all(AppSpacing.md),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
}
