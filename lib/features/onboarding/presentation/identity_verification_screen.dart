import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../application/onboarding_controller.dart';
import 'onboarding_step_scaffold.dart';

/// KNOWN BACKEND GAP: there is currently no public endpoint to persist
/// the actual selfie image against an identity-verification record —
/// only `capture_ref` (an opaque string) is accepted. This screen
/// captures a real selfie for a genuine on-device UX and generates a
/// local reference for it, but the image itself is not uploaded
/// anywhere yet. Before launch, expose an endpoint (e.g. multipart on
/// POST /onboarding/identity-verification/capture, or reuse the
/// Documents API with an IDENTITY_VERIFICATION owner type) and wire the
/// upload in `_submitCapture` below.
class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends ConsumerState<IdentityVerificationScreen> {
  final _picker = ImagePicker();
  Timer? _pollTimer;
  File? _capturedImage;
  bool _isBusy = false;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _ensurePolling(String status) {
    final shouldPoll = status == 'PENDING' || status == 'PROCESSING';
    if (shouldPoll && _pollTimer == null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        ref.read(onboardingControllerProvider.notifier).refreshQuietly();
      });
    } else if (!shouldPoll && _pollTimer != null) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _captureSelfie() async {
    setState(() => _isBusy = true);
    try {
      final identity = ref.read(onboardingControllerProvider).value?.identity;
      if (identity == null) {
        await ref.read(onboardingControllerProvider.notifier).startIdentity();
      }

      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1280,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() => _capturedImage = File(photo.path));
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnackbar(context, e.message, type: ToastType.error);
    } catch (_) {
      if (mounted) {
        showAppSnackbar(
          context,
          "Couldn't open the camera. Check camera permissions and try again.",
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _submitCapture() async {
    final image = _capturedImage;
    if (image == null) return;

    setState(() => _isBusy = true);
    try {
      final bytesLength = await image.length();
      // Placeholder reference — see the file-level note on the missing
      // upload endpoint. Once that endpoint exists, upload `image` there
      // first and use its real document/version id as the ref instead.
      final captureRef =
          'selfie_${DateTime.now().millisecondsSinceEpoch}_$bytesLength';

      await ref.read(onboardingControllerProvider.notifier).submitIdentityCapture(captureRef);
      if (mounted) setState(() => _capturedImage = null);
    } on ApiException catch (e) {
      if (mounted) showAppSnackbar(context, e.message, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _retake() {
    setState(() => _capturedImage = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ref.listen(onboardingControllerProvider, (previous, next) {
      final wasCompleted = previous?.value?.record.isCompleted ?? false;
      final isCompleted = next.value?.record.isCompleted ?? false;
      if (!wasCompleted && isCompleted) {
        context.go(RoutePaths.onboardingComplete);
      }
    });

    final snapshotAsync = ref.watch(onboardingControllerProvider);
    final identity = snapshotAsync.value?.identity;
    if (identity != null) _ensurePolling(identity.status);

    final showStatusCard = _capturedImage == null &&
        identity != null &&
        identity.status != 'RETRY_REQUIRED' &&
        identity.status != 'FAILED';

    return OnboardingStepScaffold(
      stepIndex: 3,
      title: 'One last check',
      subtitle: 'A quick selfie confirms the person applying is really you.',
      footer: _buildFooter(identity),
      child: _capturedImage != null
          ? _CapturePreview(file: _capturedImage!)
          : showStatusCard
              ? _IdentityStatusCard(status: identity!.status, reason: identity.failureReason)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Bullet(
                      icon: Icons.wb_sunny_outlined,
                      text: 'Good lighting, look straight at the camera.',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const _Bullet(
                      icon: Icons.block_outlined,
                      text: 'No filters, hats, or sunglasses.',
                    ),
                    if (identity?.status == 'FAILED' || identity?.status == 'RETRY_REQUIRED')
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Text(
                          identity?.failureReason ??
                              "That didn't go through — let's try once more.",
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget? _buildFooter(dynamic identity) {
    if (_capturedImage != null) {
      return Row(
        children: [
          Expanded(
            child: SecondaryButton(label: 'Retake', onPressed: _isBusy ? null : _retake),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: 'Submit',
              isLoading: _isBusy,
              onPressed: _submitCapture,
            ),
          ),
        ],
      );
    }

    if (identity != null &&
        identity.status != 'FAILED' &&
        identity.status != 'RETRY_REQUIRED') {
      return null; // status card is showing; nothing actionable right now
    }

    return PrimaryButton(
      label: identity == null ? 'Take a selfie' : 'Retake selfie',
      isLoading: _isBusy,
      onPressed: _captureSelfie,
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class _CapturePreview extends StatelessWidget {
  const _CapturePreview({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Image.file(file, fit: BoxFit.cover),
      ),
    );
  }
}

class _IdentityStatusCard extends StatelessWidget {
  const _IdentityStatusCard({required this.status, required this.reason});

  final String status;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = status == 'PENDING' || status == 'PROCESSING';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Identity check', style: theme.textTheme.titleLarge),
                StatusChip.forVerificationStatus(status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (isPending)
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      "We're reviewing your selfie. This updates automatically.",
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              )
            else if (status == 'MANUAL_REVIEW')
              Text(
                'Your selfie is under manual review by our team.',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
