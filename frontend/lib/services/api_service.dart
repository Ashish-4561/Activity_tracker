import 'dart:async';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isNetworkError;

  ApiException(this.message, {this.statusCode, this.isNetworkError = false});

  @override
  String toString() => message;
}

class ApiService {
  String get baseUrl => ApiConfig.getBaseUrl();
  static const String _tokenKey = 'auth_token';
  static const Duration requestTimeout = Duration(milliseconds: 3000);

  ApiService();

  Never _handleError(dynamic error, [Uri? uri]) {
    if (error is SocketException) {
      final host = uri?.host ?? 'server';
      throw ApiException(
        'Unable to reach server ($host). Ensure the backend is running and reachable from this network.',
        statusCode: 0,
        isNetworkError: true,
      );
    }
    if (error is http.ClientException) {
      final host = uri?.host ?? 'server';
      throw ApiException(
        'Connection refused to $host. Please ensure the backend is running and accessible.',
        statusCode: 0,
        isNetworkError: true,
      );
    }
    if (error is TimeoutException) {
      throw ApiException(
        'Request timed out. The backend server took too long to respond.',
        statusCode: 408,
        isNetworkError: true,
      );
    }
    if (error is ApiException) {
      throw error;
    }
    throw ApiException(error.toString().replaceAll('Exception: ', ''));
  }

  Future<String?> getToken() async {
    try {
      final supabaseToken = Supabase.instance.client.auth.currentSession?.accessToken;
      if (supabaseToken != null && supabaseToken.isNotEmpty) {
        return supabaseToken;
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, String>> _getHeaders({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    
    if (auth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    
    return headers;
  }

  // Auth endpoints
  Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/signup');
    try {
      final response = await http
          .post(
            uri,
            headers: await _getHeaders(auth: false),
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await setToken(data['token']);
        return data;
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Signup failed';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    try {
      final response = await http
          .post(
            uri,
            headers: await _getHeaders(auth: false),
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await setToken(data['token']);
        return data;
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Login failed';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> googleAuth({
    required String email,
    required String name,
    String? profileImage,
    String? googleId,
    String? idToken,
    String? accessToken,
    String? supabaseToken,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/google');
    try {
      final response = await http
          .post(
            uri,
            headers: await _getHeaders(auth: false),
            body: jsonEncode({
              'email': email,
              'name': name,
              if (profileImage != null) 'profileImage': profileImage,
              if (googleId != null) 'googleId': googleId,
              if (idToken != null) 'idToken': idToken,
              if (accessToken != null) 'accessToken': accessToken,
              if (supabaseToken != null) 'supabaseToken': supabaseToken,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await setToken(data['token']);
        return data;
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Google authentication failed';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> sendPhoneOtp({required String phone}) async {
    final uri = Uri.parse('$baseUrl/auth/phone/send-otp');
    try {
      final response = await http
          .post(
            uri,
            headers: await _getHeaders(auth: false),
            body: jsonEncode({'phone': phone}),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to send verification code';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> verifyPhoneOtp({
    required String phone,
    required String otp,
    String? name,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/phone/verify-otp');
    try {
      final response = await http
          .post(
            uri,
            headers: await _getHeaders(auth: false),
            body: jsonEncode({
              'phone': phone,
              'otp': otp,
              if (name != null) 'name': name,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await setToken(data['token']);
        return data;
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Phone verification failed';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    final uri = Uri.parse('$baseUrl/auth/profile');
    try {
      final response = await http
          .get(
            uri,
            headers: await _getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to get profile';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? profileImage,
    String? theme,
    bool? aiEnabled,
    bool? aiSuggestionsEnabled,
    bool? notificationsEnabled,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/profile');
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (profileImage != null) body['profile_image'] = profileImage;
      if (theme != null) body['theme'] = theme;
      if (aiEnabled != null) body['ai_enabled'] = aiEnabled;
      if (aiSuggestionsEnabled != null) body['ai_suggestions_enabled'] = aiSuggestionsEnabled;
      if (notificationsEnabled != null) body['notifications_enabled'] = notificationsEnabled;

      final response = await http
          .put(
            uri,
            headers: await _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to update profile';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/change-password');
    try {
      final response = await http
          .post(
            uri,
            headers: await _getHeaders(),
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to change password';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    final uri = Uri.parse('$baseUrl/auth/account');
    try {
      final response = await http
          .delete(
            uri,
            headers: await _getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        await clearToken();
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to delete account';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  // Activity endpoints
  Future<Map<String, dynamic>> createActivity({
    required String name,
    required String frequency,
    String? groupName,
    String? icon,
    int frequencyValue = 1,
    String frequencyUnit = 'days',
    int durationValue = 12,
    String durationUnit = 'months',
    String? startDate,
    String? color,
    String? description,
  }) async {
    final uri = Uri.parse('$baseUrl/activities');
    try {
      final response = await http
          .post(
            uri,
            headers: await _getHeaders(),
            body: jsonEncode({
              'name': name,
              'frequency': frequency,
              'group_name': groupName,
              'icon': icon,
              'frequency_value': frequencyValue,
              'frequency_unit': frequencyUnit,
              'duration_value': durationValue,
              'duration_unit': durationUnit,
              'start_date': startDate,
              'color': color,
              'description': description,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to create activity';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> getActivities({String? date}) async {
    final uri = date != null && date.isNotEmpty
        ? Uri.parse('$baseUrl/activities?date=$date')
        : Uri.parse('$baseUrl/activities');
    try {
      final response = await http
          .get(
            uri,
            headers: await _getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to get activities';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> updateActivity({
    required String id,
    String? name,
    String? frequency,
    String? groupName,
    String? icon,
    String? color,
    int? frequencyValue,
    String? frequencyUnit,
    int? durationValue,
    String? durationUnit,
    String? startDate,
  }) async {
    final uri = Uri.parse('$baseUrl/activities/$id');
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (frequency != null) body['frequency'] = frequency;
      if (groupName != null) body['group_name'] = groupName;
      if (icon != null) body['icon'] = icon;
      if (color != null) body['color'] = color;
      if (frequencyValue != null) body['frequency_value'] = frequencyValue;
      if (frequencyUnit != null) body['frequency_unit'] = frequencyUnit;
      if (durationValue != null) body['duration_value'] = durationValue;
      if (durationUnit != null) body['duration_unit'] = durationUnit;
      if (startDate != null) body['start_date'] = startDate;

      final response = await http
          .put(
            uri,
            headers: await _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to update activity';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> deleteActivity(String id) async {
    final uri = Uri.parse('$baseUrl/activities/$id');
    try {
      final response = await http
          .delete(
            uri,
            headers: await _getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to delete activity';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> deleteGroup(String groupName) async {
    final encoded = Uri.encodeComponent(groupName);
    final uri = Uri.parse('$baseUrl/activities/group/$encoded');
    try {
      final response = await http
          .delete(
            uri,
            headers: await _getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to delete group';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> renameGroup({
    required String oldGroupName,
    required String newGroupName,
  }) async {
    final encoded = Uri.encodeComponent(oldGroupName);
    final uri = Uri.parse('$baseUrl/activities/group/$encoded/rename');
    try {
      final response = await http
          .put(
            uri,
            headers: await _getHeaders(),
            body: jsonEncode({
              'newGroupName': newGroupName,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to rename group';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  // Completion endpoints
  Future<Map<String, dynamic>> completeActivity({
    required String activityId,
    String? date,
  }) async {
    final uri = Uri.parse('$baseUrl/completions/complete');
    try {
      final response = await http
          .post(
            uri,
            headers: await _getHeaders(),
            body: jsonEncode({
              'activity_id': activityId,
              if (date != null) 'date': date,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to complete activity';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> uncompleteActivity({
    required String activityId,
    String? date,
  }) async {
    final uri = Uri.parse('$baseUrl/completions/uncomplete');
    try {
      final response = await http
          .post(
            uri,
            headers: await _getHeaders(),
            body: jsonEncode({
              'activity_id': activityId,
              if (date != null) 'date': date,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to uncomplete activity';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> getCompletionsByDate({String? date}) async {
    final baseUri = Uri.parse('$baseUrl/completions/by-date');
    final uri = date != null ? baseUri.replace(queryParameters: {'date': date}) : baseUri;
    try {
      final response = await http
          .get(
            uri,
            headers: await _getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to get completions for date';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  // Progress endpoints
  Future<Map<String, dynamic>> getDailyProgress({String? date}) async {
    final baseUri = Uri.parse('$baseUrl/progress/daily');
    final uri = date != null ? baseUri.replace(queryParameters: {'date': date}) : baseUri;
    try {
      final response = await http
          .get(
            uri,
            headers: await _getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to get daily progress';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> getWeeklyProgress({String? date}) async {
    final baseUri = Uri.parse('$baseUrl/progress/weekly');
    final uri = date != null && date.isNotEmpty
        ? baseUri.replace(queryParameters: {'date': date})
        : baseUri;
    try {
      final response = await http
          .get(
            uri,
            headers: await _getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to get weekly progress';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> getMonthlyProgress({int? month, int? year}) async {
    final queryParameters = <String, String>{};
    if (month != null) queryParameters['month'] = month.toString();
    if (year != null) queryParameters['year'] = year.toString();

    final uri = Uri.parse('$baseUrl/progress/monthly')
        .replace(queryParameters: queryParameters.isNotEmpty ? queryParameters : null);
    try {
      final response = await http
          .get(
            uri,
            headers: await _getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to get monthly progress';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> getRangeProgress({
    required String from,
    required String to,
    String? group,
    String? activityId,
  }) async {
    final query = <String, String>{'from': from, 'to': to};
    if (group != null && group != 'All Groups') query['group'] = group;
    if (activityId != null && activityId != 'All Activities') query['activity_id'] = activityId;
    final uri = Uri.parse('$baseUrl/progress/range').replace(queryParameters: query);

    try {
      final response = await http
          .get(
            uri,
            headers: await _getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) return jsonDecode(response.body);
      final err = jsonDecode(response.body)['error'] ?? 'Failed to get historical progress';
      throw ApiException(err, statusCode: response.statusCode);
    } catch (e) {
      _handleError(e, uri);
    }
  }

  // Chat endpoints
  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    bool includeHistory = false,
  }) async {
    final uri = Uri.parse('$baseUrl/chat/message');
    try {
      final response = await http
          .post(
            uri,
            headers: await _getHeaders(),
            body: jsonEncode({
              'message': message,
              'includeHistory': includeHistory,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final err = data['error'] ?? data['response'] ?? 'Failed to send message';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  Future<Map<String, dynamic>> getChatHistory({int? limit}) async {
    final queryParameters = limit != null ? {'limit': limit.toString()} : null;
    final uri = Uri.parse('$baseUrl/chat/history')
        .replace(queryParameters: queryParameters);
    try {
      final response = await http
          .get(
            uri,
            headers: await _getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to get chat history';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  // ── Personal Growth Garden APIs ──────────────────────────────────────────

  /// Fetches all group gardens for the authenticated user
  Future<Map<String, dynamic>> getGardens() async {
    final uri = Uri.parse('$baseUrl/gardens');
    try {
      final response = await http
          .get(
            uri,
            headers: await _getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to get group gardens';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  /// Fetches the garden for a specific group by ID
  Future<Map<String, dynamic>> getGardenById(String groupId) async {
    final encoded = Uri.encodeComponent(groupId);
    final uri = Uri.parse('$baseUrl/gardens/$encoded');
    try {
      final response = await http
          .get(
            uri,
            headers: await _getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to get group garden';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  /// Creates or retrieves a group with its personal garden
  Future<Map<String, dynamic>> createOrGetGroup(String name) async {
    final uri = Uri.parse('$baseUrl/gardens/group');
    try {
      final response = await http
          .post(
            uri,
            headers: await _getHeaders(),
            body: jsonEncode({'name': name}),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to create group';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  /// Renames a group while keeping its group ID and attached garden intact
  Future<Map<String, dynamic>> renameGroupWithGarden(String groupId, String newName) async {
    final encoded = Uri.encodeComponent(groupId);
    final uri = Uri.parse('$baseUrl/gardens/group/$encoded/rename');
    try {
      final response = await http
          .put(
            uri,
            headers: await _getHeaders(),
            body: jsonEncode({'newGroupName': newName}),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to rename group';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }

  /// Deletes a group and handles its attached garden
  Future<Map<String, dynamic>> deleteGroupWithGarden(String groupId) async {
    final encoded = Uri.encodeComponent(groupId);
    final uri = Uri.parse('$baseUrl/gardens/group/$encoded');
    try {
      final response = await http
          .delete(
            uri,
            headers: await _getHeaders(),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Failed to delete group';
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      _handleError(e, uri);
    }
  }
}
