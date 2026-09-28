import '../../../core/network/api_client.dart';
import 'loan_models.dart';

class LoanRepository {
  LoanRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<LoanApplication> createDraft({
    required num requestedAmount,
    required int requestedTenureDays,
  }) async {
    final data = await apiClient.post<Map<String, dynamic>>(
      '/loan-applications',
      data: {
        'requested_amount': requestedAmount,
        'requested_tenure_days': requestedTenureDays,
      },
    );
    return LoanApplication.fromJson(data);
  }

  Future<List<LoanApplication>> listApplications() async {
    final data = await apiClient.get<List<dynamic>>('/loan-applications');
    return data.map((e) => LoanApplication.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<LoanApplication> getApplication(String id) async {
    final data = await apiClient.get<Map<String, dynamic>>('/loan-applications/$id');
    return LoanApplication.fromJson(data);
  }

  Future<LoanApplication> submit(String id) async {
    final data = await apiClient.post<Map<String, dynamic>>('/loan-applications/$id/submit');
    return LoanApplication.fromJson(data);
  }

  Future<List<LoanApplicationEvent>> getEvents(String id) async {
    final data = await apiClient.get<List<dynamic>>('/loan-applications/$id/events');
    return data
        .map((e) => LoanApplicationEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
