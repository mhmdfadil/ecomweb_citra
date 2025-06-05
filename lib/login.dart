import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'screens/admin_screen.dart';
import 'register.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isCheckingSession = true;

  // Session duration - set to 1 year (365 days)
  static const Duration _sessionDuration = Duration(days: 365);

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString('admin_id');
      final expiryDate = prefs.getString('session_expiry');

      if (savedUserId != null && expiryDate != null) {
        final expiry = DateTime.parse(expiryDate);
        if (expiry.isAfter(DateTime.now())) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminScreen()),
            );
          }
          return;
        } else {
          // Clear expired session
          await prefs.remove('admin_id');
          await prefs.remove('session_expiry');
        }
      }
    } catch (e) {
      print('Error checking session: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingSession = false);
      }
    }
  }

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _saveSession(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_id', userId);
      final expiryDate = DateTime.now().add(_sessionDuration);
      await prefs.setString('session_expiry', expiryDate.toIso8601String());
    } catch (e) {
      print('Error saving session: $e');
      rethrow;
    }
  }

  void _showNotification(BuildContext context, {required String message, required bool isSuccess}) {
    OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 10,
        right: 10,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  message,
                  style: TextStyle(color: isSuccess ? Colors.green : Colors.red),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Show overlay
    Overlay.of(context).insert(overlayEntry);

    // Remove overlay after some time
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  Future<void> _login(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final username = _usernameController.text.trim();
        final password = _passwordController.text;
        final hashedPassword = _hashPassword(password);

        // Check user in users table
        final response = await supabase
            .from('users')
            .select()
            .eq('username', username)
            .maybeSingle();

        if (response == null) {
          _showNotification(
            context,
            message: 'Username not found',
            isSuccess: false,
          );
          return;
        }

        // Verify password
        if (response['password'] != hashedPassword) {
          _showNotification(
            context,
            message: 'Incorrect password',
            isSuccess: false,
          );
          return;
        }

        // Verify role if needed
        if (response['roles'] != 'Admin') {
          _showNotification(
            context,
            message: 'You do not have access',
            isSuccess: false,
          );
          return;
        }

        // Save session
        await _saveSession(response['id'].toString());

        _showNotification(
          context,
          message: 'Login successful',
          isSuccess: true,
        );

        if (mounted) {
          Future.delayed(const Duration(seconds: 1), () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminScreen()),
            );
          });
        }
      } catch (e) {
        _showNotification(
          context,
          message: 'Error: ${e.toString()}',
          isSuccess: false,
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _navigateToRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Center(
          child: Container(
            width: isMobile ? MediaQuery.of(context).size.width * 0.9 : 800,
            height: isMobile ? null : 600,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 5,
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: isMobile
                ? Column(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(32),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Username',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _usernameController,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFFD9D9D9),
                                        border: const OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Username cannot be empty';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Password',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFFD9D9D9),
                                        border: const OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Password cannot be empty';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _isLoading ? null : () => _login(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF273F0),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 50),
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text('Login'),
                                ),
                                const SizedBox(height: 15),
                                // GestureDetector(
                                //   onTap: () => _navigateToRegister(context),
                                //   child: RichText(
                                //     text: TextSpan(
                                //       text: 'Don\'t have an account? ',
                                //       style: const TextStyle(color: Colors.black),
                                //       children: [
                                //         TextSpan(
                                //           text: 'Register',
                                //           style: TextStyle(
                                //             color: Colors.blue,
                                //             fontWeight: FontWeight.bold,
                                //           ),
                                //         ),
                                //       ],
                                //     ),
                                //   ),
                                // ),
                                const SizedBox(height: 22),
                                Image.asset(
                                  'assets/images/logo.png',
                                  width: 300,
                                  height: 200,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/images/background.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(32),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Username',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _usernameController,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFFD9D9D9),
                                        border: const OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Username cannot be empty';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Password',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFFD9D9D9),
                                        border: const OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Password cannot be empty';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _isLoading ? null : () => _login(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF273F0),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 50),
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text('Login'),
                                ),
                                const SizedBox(height: 15),
                                // GestureDetector(
                                //   onTap: () => _navigateToRegister(context),
                                //   child: RichText(
                                //     text: TextSpan(
                                //       text: 'Don\'t have an account? ',
                                //       style: const TextStyle(color: Colors.black),
                                //       children: [
                                //         TextSpan(
                                //           text: 'Register',
                                //           style: TextStyle(
                                //             color: Colors.blue,
                                //             fontWeight: FontWeight.bold,
                                //           ),
                                //         ),
                                //       ],
                                //     ),
                                //   ),
                                // ),
                                const SizedBox(height: 22),
                                Image.asset(
                                  'assets/images/logo.png',
                                  width: 300,
                                  height: 200,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}