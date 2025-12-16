
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';

class ProfessorAccountPage extends StatefulWidget {
  const ProfessorAccountPage({super.key});

  @override
  State<ProfessorAccountPage> createState() => _ProfessorAccountPageState();
}

class _ProfessorAccountPageState extends State<ProfessorAccountPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  List<String> _selectedClasses = [];
  final List<String> classOptions = [
    '1ere GLSI',
    '2eme GLSI',
    '3eme GLSI',
    'Cycle Ingenieur',
  ];

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitProfessorAccount() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one class')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;

    try {
      // 1) Sign up with Supabase Auth
      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = response.user;

      if (user == null) {
        // Email confirmation required
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created. Please confirm your email.'),
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
        return;
      }

      final userId = user.id;

      // Debug print inserted row
      print('=== Debug: Insert Professor ===');
      print('User ID: $userId');
      print('Name: ${_nameController.text}');
      print('Email: ${_emailController.text}');
      print('Subject: ${_subjectController.text}');
      print('Classes: $_selectedClasses');

      // 2) Insert profile into the "professors" table
      final insertResponse = await supabase
          .from('professors')
          .insert({
        'id': userId,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'subject': _subjectController.text.trim(),
        'classes_taught': _selectedClasses,
      })
          .select()
          .single();

      // Success
      print('Inserted professor: $insertResponse');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Professor account created successfully!')),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      // All errors handled here
      print('Supabase error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating account: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Professor Account Setup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create a Professor Account', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Email is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Password is required';
                  if (value.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Subject
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject Taught',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Subject is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Class selection
              const Text('Select Classes You Teach', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Column(
                children: classOptions.map((className) {
                  return CheckboxListTile(
                    title: Text(className),
                    value: _selectedClasses.contains(className),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          if (!_selectedClasses.contains(className)) _selectedClasses.add(className);
                        } else {
                          _selectedClasses.remove(className);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitProfessorAccount,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Create Professor Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
