import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  late String baseUrl;
  static const String _tokenKey = 'auth_token';

  ApiService() {
    baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:5000/api';
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
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
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
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: await _getHeaders(auth: false),
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await setToken(data['token']);
        return data;
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Signup failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: await _getHeaders(auth: false),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await setToken(data['token']);
        return data;
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Login failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> googleAuth({
    required String email,
    required String name,
    String? profileImage,
    String? googleId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google'),
        headers: await _getHeaders(auth: false),
        body: jsonEncode({
          'email': email,
          'name': name,
          if (profileImage != null) 'profileImage': profileImage,
          if (googleId != null) 'googleId': googleId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await setToken(data['token']);
        return data;
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Google authentication failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendPhoneOtp({required String phone}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/phone/send-otp'),
        headers: await _getHeaders(auth: false),
        body: jsonEncode({'phone': phone}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to send verification code');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyPhoneOtp({
    required String phone,
    required String otp,
    String? name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/phone/verify-otp'),
        headers: await _getHeaders(auth: false),
        body: jsonEncode({
          'phone': phone,
          'otp': otp,
          if (name != null) 'name': name,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await setToken(data['token']);
        return data;
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Phone verification failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get profile');
      }
    } catch (e) {
      rethrow;
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
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (profileImage != null) body['profile_image'] = profileImage;
      if (theme != null) body['theme'] = theme;
      if (aiEnabled != null) body['ai_enabled'] = aiEnabled;
      if (aiSuggestionsEnabled != null) body['ai_suggestions_enabled'] = aiSuggestionsEnabled;
      if (notificationsEnabled != null) body['notifications_enabled'] = notificationsEnabled;

      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to update profile');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to change password');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/auth/account'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        await clearToken();
        return jsonDecode(response.body);
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to delete account');
      }
    } catch (e) {
      rethrow;
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
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/activities'),
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
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to create activity');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getActivities({String? date}) async {
    try {
      final uri = date != null && date.isNotEmpty
          ? Uri.parse('$baseUrl/activities?date=$date')
          : Uri.parse('$baseUrl/activities');
      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get activities');
      }
    } catch (e) {
      rethrow;
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

      final response = await http.put(
        Uri.parse('$baseUrl/activities/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to update activity');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteActivity(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/activities/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to delete activity');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteGroup(String groupName) async {
    try {
      final encoded = Uri.encodeComponent(groupName);
      final response = await http.delete(
        Uri.parse('$baseUrl/activities/group/$encoded'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to delete group');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> renameGroup({
    required String oldGroupName,
    required String newGroupName,
  }) async {
    try {
      final encoded = Uri.encodeComponent(oldGroupName);
      final response = await http.put(
        Uri.parse('$baseUrl/activities/group/$encoded/rename'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'newGroupName': newGroupName,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to rename group');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Completion endpoints
  Future<Map<String, dynamic>> completeActivity({
    required String activityId,
    String? date,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/completions/complete'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'activity_id': activityId,
          if (date != null) 'date': date,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to complete activity');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uncompleteActivity({
    required String activityId,
    String? date,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/completions/uncomplete'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'activity_id': activityId,
          if (date != null) 'date': date,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to uncomplete activity');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCompletionsByDate({String? date}) async {
    try {
      final uri = Uri.parse('$baseUrl/completions/by-date');
      final queryUri = date != null ? uri.replace(queryParameters: {'date': date}) : uri;

      final response = await http.get(
        queryUri,
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get completions for date');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Progress endpoints
  Future<Map<String, dynamic>> getDailyProgress({String? date}) async {
    try {
      final uri = Uri.parse('$baseUrl/progress/daily');
      final queryUri = date != null ? uri.replace(queryParameters: {'date': date}) : uri;
      
      final response = await http.get(
        queryUri,
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get daily progress');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getWeeklyProgress() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/progress/weekly'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get weekly progress');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMonthlyProgress({int? month, int? year}) async {
    try {
      final queryParameters = <String, String>{};
      if (month != null) queryParameters['month'] = month.toString();
      if (year != null) queryParameters['year'] = year.toString();

      final uri = Uri.parse('$baseUrl/progress/monthly')
          .replace(queryParameters: queryParameters.isNotEmpty ? queryParameters : null);

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get monthly progress');
      }
    } catch (e) {
      rethrow;
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
    final response = await http.get(
      Uri.parse('$baseUrl/progress/range').replace(queryParameters: query),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to get historical progress');
  }

  // Chat endpoints
  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    bool includeHistory = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/message'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'message': message,
          'includeHistory': includeHistory,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(data['error'] ?? data['response'] ?? 'Failed to send message');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getChatHistory({int? limit}) async {
    try {
      final queryParameters = limit != null ? {'limit': limit.toString()} : null;
      final uri = Uri.parse('$baseUrl/chat/history')
          .replace(queryParameters: queryParameters);

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get chat history');
      }
    } catch (e) {
      rethrow;
    }
  }
}
