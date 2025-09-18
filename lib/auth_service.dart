import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';

  Future<bool> isLoggedIn() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString(_tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<void> _saveToken(String token) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Mock register: accept any non-empty email/password; save a token
  Future<String?> register({required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (email.isEmpty || password.length < 6) {
      return '请输入有效邮箱，密码至少6位';
    }
    await _saveToken('mock_token_for_$email');
    return null; // null means success
  }

  // Mock login: accept any non-empty email/password; save a token
  Future<String?> login({required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (email.isEmpty || password.isEmpty) {
      return '邮箱和密码不能为空';
    }
    await _saveToken('mock_token_for_$email');
    return null;
  }
}



