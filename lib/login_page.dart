  import 'package:flutter/material.dart';
  import 'package:supabase_flutter/supabase_flutter.dart';
  import 'create_account_page.dart';
  import 'studen_home_page.dart';
  import 'professor_home_page.dart';
  import 'theme_controller.dart';

  class LoginPage extends StatefulWidget {
    const LoginPage({super.key});

    @override
    State<LoginPage> createState() => _LoginPageState();
  }

  class _LoginPageState extends State<LoginPage> {
    final TextEditingController _emailController = TextEditingController();
    final TextEditingController _passwordController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    Future<void> loginWithEmail() async {
      if (!_formKey.currentState!.validate()) return;

      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      print('Attempting login with email: "$email"');

      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email, 
          password: password,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged in successfully')),
        );
        
        // Check if user is professor or student and navigate accordingly
        await _navigateToUserDashboard();
      } catch (e) {
        print('Login error: $e');
        String errorMessage = 'Login failed';
        
        if (e is AuthApiException && e.code == 'email_address_invalid') {
          errorMessage = 'Invalid email address format';
        } else if (e is AuthApiException) {
          errorMessage = e.message ;
        } else {
          errorMessage = e.toString();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }

    Future<void> _navigateToUserDashboard() async {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;

        // Check if user is a professor
        final professorCheck = await Supabase.instance.client
            .from('professors')
            .select('id')
            .eq('id', user.id)
            .maybeSingle();

        if (professorCheck != null) {
          // User is a professor
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ProfessorHomePage()),
          );
        } else {
          // User is a student
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const StudentHomePage()),
          );
        }
      } catch (e) {
        print('Error navigating to dashboard: $e');
        // Default to student home page if check fails
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const StudentHomePage()),
        );
      }
    }

    Future<void> loginWithGoogle() async {
      try {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.flutter://login-callback',
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-in failed: $e')),
        );
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.brightness_6),
              tooltip: 'Toggle theme',
              onPressed: ThemeController.toggle,
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Login', style: TextStyle(fontSize: 20, color: Colors.black)),
                    const SizedBox(height: 50),

                    // EMAIL
                    SizedBox(
                      height: 60,
                      child: TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value.trim())) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                    ),

                    // PASSWORD
                    SizedBox(
                      height: 60,
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Password is required';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // LOGIN BUTTON
                    ElevatedButton(
                      onPressed: loginWithEmail,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      child: const Text('Login', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),

                    const SizedBox(height: 50),

                    // Divider OR
                    Row(
                      children: const [
                        Expanded(child: Divider(color: Colors.black)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('or', style: TextStyle(fontSize: 12, color: Colors.black)),
                        ),
                        Expanded(child: Divider(color: Colors.black)),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // GOOGLE BUTTON
                    ElevatedButton.icon(
                      onPressed: loginWithGoogle,
                      icon: const Icon(Icons.login, color: Colors.white),
                      label: const Text('Sign in with Google', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // CREATE ACCOUNT
                    ElevatedButton(
                      onPressed: () async {
                        final resultEmail = await Navigator.of(context).push<String>(
                          MaterialPageRoute(builder: (_) => const CreateAccountPage()),
                        );

                        if (resultEmail != null) {
                          _emailController.text = resultEmail;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('You can now log in with $resultEmail')),
                          );
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(width: 10),
                          Text('Create new account', style: TextStyle(color: Colors.deepPurple, fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
