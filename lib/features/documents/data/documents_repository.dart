import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';

class AppDocument {
  const AppDocument({
    required this.id,
    required this.documentType,
    required this.contentType,
    required this.sizeBytes,
    required this.version,
    required this.isImmutable,
    required this.createdAt,
    required this.documentFamilyId,
  });

  final String id;
  final String documentType;
  final String contentType;
  final int sizeBytes;
  final int version;
  final bool isImmutable;
  final DateTime createdAt;
  final String documentFamilyId;

  bool get isImage => contentType.startsWith('image/');

  String get readableSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory AppDocument.fromJson(Map<String, dynamic> json) => AppDocument(
        id: json['id'] as String,
        documentType: json['document_type'] as String,
        contentType: json['content_type'] as String,
        sizeBytes: json['size_bytes'] as int,
        version: json['version'] as int,
        isImmutable: json['is_immutable'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
        documentFamilyId: json['document_family_id'] as String,
      );
}

class DocumentsRepository {
  DocumentsRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<AppDocument>> listDocuments() async {
    final data = await apiClient.get<Map<String, dynamic>>('/documents');
    final items = data['items'] as List<dynamic>;
    return items.map((e) => AppDocument.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AppDocument>> listVersions(String documentFamilyId) async {
    final data = await apiClient.get<Map<String, dynamic>>(
      '/documents/family/$documentFamilyId/versions',
    );
    final items = data['items'] as List<dynamic>;
    return items.map((e) => AppDocument.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<int>> getContent(String documentId) {
    return apiClient.getBytes('/documents/$documentId/content');
  }
}

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  return DocumentsRepository(apiClient: ref.watch(apiClientProvider));
});

final documentsListProvider = FutureProvider.autoDispose<List<AppDocument>>((ref) {
  return ref.watch(documentsRepositoryProvider).listDocuments();
});
