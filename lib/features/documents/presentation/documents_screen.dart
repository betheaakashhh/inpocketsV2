import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/feedback.dart';
import '../data/documents_repository.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final documentsAsync = ref.watch(documentsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(documentsListProvider),
        child: documentsAsync.when(
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 3,
            itemBuilder: (context, index) => const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: ShimmerBox(height: 64, borderRadius: AppSpacing.radiusMd),
            ),
          ),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 100),
              Center(
                child: Text("Couldn't load your documents.", style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
          data: (documents) {
            if (documents.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.inbox_outlined,
                      size: 48, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: Text('Nothing here yet', style: theme.textTheme.titleMedium),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Center(
                    child: Text(
                      'Documents collected during KYC will appear here.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: documents.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final doc = documents[index];
                return _DocumentTile(document: doc);
              },
            );
          },
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document});

  final AppDocument document;

  IconData get _icon {
    if (document.isImage) return Icons.image_outlined;
    if (document.contentType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    return Icons.description_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _DocumentPreviewSheet(document: document),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(_icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_titleize(document.documentType), style: theme.textTheme.titleMedium),
                    Text(
                      'v${document.version} · ${document.readableSize} · '
                      '${AppFormatters.date(document.createdAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  String _titleize(String raw) =>
      raw.split('_').map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}').join(' ');
}

class _DocumentPreviewSheet extends ConsumerStatefulWidget {
  const _DocumentPreviewSheet({required this.document});

  final AppDocument document;

  @override
  ConsumerState<_DocumentPreviewSheet> createState() => _DocumentPreviewSheetState();
}

class _DocumentPreviewSheetState extends ConsumerState<_DocumentPreviewSheet> {
  Uint8List? _bytes;
  bool _loading = false;
  String? _error;

  Future<void> _loadPreview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final content = await ref.read(documentsRepositoryProvider).getContent(widget.document.id);
      setState(() => _bytes = Uint8List.fromList(content));
    } catch (_) {
      setState(() => _error = "Couldn't load a preview for this file.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doc = widget.document;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightBorder,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(doc.documentType, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Version ${doc.version} · ${doc.readableSize} · ${doc.contentType}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_bytes != null && doc.isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Image.memory(_bytes!, fit: BoxFit.contain),
            )
          else if (_bytes != null)
            Text(
              'Preview isn\u2019t available for this file type yet, but the '
              'file loaded successfully (${doc.readableSize}).',
              style: theme.textTheme.bodyMedium,
            )
          else if (_error != null)
            Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.danger))
          else
            OutlinedButton.icon(
              onPressed: _loading ? null : _loadPreview,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.visibility_outlined),
              label: Text(_loading ? 'Loading…' : 'View content'),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
