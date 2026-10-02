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

/// The camera capture itself is intentionally local-first. Network access is
/// required only when the user submits the captured image/reference.
///
/// A capture reference belongs to the captured selfie, not to an individual
/// HTTP attempt. This lets a retry reuse the same submission identifier after
/// a response-loss/network failure.
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
  String? _captureRef;
  bool _isBusy = false;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _ensurePolling(String status, {required bool awaitOnboardingCompletion}) {
    final shouldPoll = status == 'PROCESSING' ||
        status == 'PENDING' ||
        (status == 'VERIFIED' && awaitOnboardingCompletion);

    if (shouldPoll && _pollTimer == null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        await ref.read(onboardingControllerProvider.notifier).refreshQuietly();
      });
    } else if (!shouldPoll && _pollTimer != null) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _captureSelfie() async {
    setState(() => _isBusy = true);
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1280,
        imageQuality: 85,
      );
      if (photo != null && mounted) {
        final image = File(photo.path);
        final bytesLength = await image.length();
        setState(() {
          _capturedImage = image;
          _captureRef =
              'selfie_${DateTime.now().millisecondsSinceEpoch}_$bytesLength';
        });
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
    final captureRef = _captureRef;
    if (image == null || captureRef == null) return;

    setState(() => _isBusy = true);
    try {
      final currentIdentity = ref.read(onboardingControllerProvider).value?.identity;

      // Only these states mean the server has already accepted a capture.
      // FAILED and RETRY_REQUIRED must be allowed to submit a newly captured
      // selfie.
      if (currentIdentity?.status == 'PROCESSING' ||
          currentIdentity?.status == 'VERIFIED' ||
          currentIdentity?.status == 'MANUAL_REVIEW') {
        _ensurePolling(
          currentIdentity!.status,
          awaitOnboardingCompletion: !(_isOnboardingComplete()),
        );
        if (mounted) {
          setState(() {
            _capturedImage = null;
            _captureRef = null;
          });
        }
        return;
      }

      // If we have a stale PENDING snapshot, refresh before posting. The
      // previous request may already have reached the backend while its
      // response was lost.
      await ref
          .read(onboardingControllerProvider.notifier)
          .refreshQuietly();

      final refreshedIdentity =
          ref.read(onboardingControllerProvider).value?.identity;
      if (refreshedIdentity?.status == 'PROCESSING' ||
          refreshedIdentity?.status == 'VERIFIED' ||
          refreshedIdentity?.status == 'MANUAL_REVIEW') {
        _ensurePolling(
          refreshedIdentity!.status,
          awaitOnboardingCompletion: !(_isOnboardingComplete()),
        );
        if (mounted) {
          setState(() {
            _capturedImage = null;
            _captureRef = null;
          });
        }
        return;
      }

      if (refreshedIdentity == null) {
        await ref
            .read(onboardingControllerProvider.notifier)
            .startIdentity();
      }

      await ref
          .read(onboardingControllerProvider.notifier)
          .submitIdentityCapture(captureRef);

      if (mounted) {
        setState(() {
          _capturedImage = null;
          _captureRef = null;
        });
      }
    } on ApiException catch (e) {
      // Keep both the image and captureRef. If the request reached the server
      // but its response was lost, the next Submit will refresh server state
      // before attempting another POST.
      if (mounted) showAppSnackbar(context, e.message, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  bool _isOnboardingComplete() {
    return ref.read(onboardingControllerProvider).value?.record.isCompleted ?? false;
  }

  void _retake() {
    setState(() {
      _capturedImage = null;
      _captureRef = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ref.listen(onboardingControllerProvider, (previous, next) {
      final wasCompleted = previous?.value?.record.isCompleted ?? false;
      final isCompleted = next.value?.record.isCompleted ?? false;
      if (!wasCompleted && isCompleted) {
        _pollTimer?.cancel();
        _pollTimer = null;
        context.go(RoutePaths.onboardingComplete);
      }
    });

    final snapshotAsync = ref.watch(onboardingControllerProvider);
    final identity = snapshotAsync.value?.identity;
    final isOnboardingComplete = snapshotAsync.value?.record.isCompleted ?? false;
    if (identity != null) {
      _ensurePolling(
        identity.status,
        awaitOnboardingCompletion: !isOnboardingComplete,
      );
    }

    final showStatusCard = _capturedImage == null &&
        identity != null &&
        identity.status != 'PENDING' &&
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
        identity.status != 'PENDING' &&
        identity.status != 'FAILED' &&
        identity.status != 'RETRY_REQUIRED') {
      return null;
    }

    return PrimaryButton(
      label: identity == null || identity.status == 'PENDING'
          ? 'Take a selfie'
          : 'Retake selfie',
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
    final isProcessing = status == 'PROCESSING';

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
            if (isProcessing)
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
              )
            else if (reason != null)
              Text(reason!, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
