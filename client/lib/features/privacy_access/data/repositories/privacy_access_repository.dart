import 'package:dio/dio.dart';
import 'package:sports_z/features/m4_common/m4_http.dart';
import 'package:sports_z/features/privacy_access/data/models/access_grant_item.dart';
import 'package:sports_z/features/privacy_access/data/models/privacy_models.dart';

class PrivacyAccessRepository {
  PrivacyAccessRepository(this._dio);
  final Dio _dio;

  // ---------- access grants (PR06, PR07) ----------
  Future<List<AccessGrantItem>> grants({String? role}) async {
    final response = await _dio.get<Object?>(
      '/access-grants',
      queryParameters: {'limit': 50, 'role': ?role},
    );
    return dataList(response).map(AccessGrantItem.fromJson).toList();
  }

  Future<AccessGrantItem> approve(String id) => _act(id, 'grant');
  Future<AccessGrantItem> decline(String id) => _act(id, 'decline');
  Future<AccessGrantItem> revoke(String id) => _act(id, 'revoke');

  Future<AccessGrantItem> _act(String id, String action) async {
    final response = await _dio.post<Object?>(
      '/access-grants/${Uri.encodeComponent(id)}/$action',
    );
    return AccessGrantItem.fromJson(dataMap(response));
  }

  /// Owner shares proactively (open item in the v3 doc; the route exists).
  Future<AccessGrantItem> share(
    String granteeUserId,
    List<String> scopes,
  ) async {
    final response = await _dio.post<Object?>(
      '/access-grants',
      data: {'grantee_user_id': granteeUserId, 'scopes': scopes},
    );
    return AccessGrantItem.fromJson(dataMap(response));
  }

  // ---------- privacy (PR01) ----------
  Future<PrivacySchema> schema() async {
    final response = await _dio.get<Object?>('/me/privacy/schema');
    return PrivacySchema.fromJson(dataMap(response));
  }

  /// M1 owns the profile; privacy settings live under profile.privacy.
  Future<PrivacySettingsValue> mySettings() async {
    final response = await _dio.get<Object?>('/me/profile/athlete');
    final privacy = dataMap(response)['privacy'];
    return PrivacySettingsValue.fromJson(
      privacy is Map ? Map<String, dynamic>.from(privacy) : null,
    );
  }

  Future<void> saveSettings(PrivacySettingsValue value) async {
    await _dio.patch<Object?>(
      '/me/profile/athlete',
      data: {'privacy': value.toJson()},
    );
  }

  // ---------- view as (PR08) ----------
  Future<Map<String, dynamic>> previewAs(String audience) async {
    final response = await _dio.get<Object?>(
      '/me/profile/preview',
      queryParameters: {'as': audience},
    );
    return dataMap(response);
  }
}
