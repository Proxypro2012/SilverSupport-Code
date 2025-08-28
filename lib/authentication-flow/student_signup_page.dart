import 'package:flutter/material.dart';
import 'package:silver_support/services/auth_service.dart';
import 'onboard_content.dart';
import 'package:go_router/go_router.dart';

class StudentSignupPage extends StatefulWidget {
  const StudentSignupPage({super.key});

  @override
  State<StudentSignupPage> createState() => _StudentSignupPageState();
}

class _StudentSignupPageState extends State<StudentSignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _auth = AuthService();

  bool _isLoading = false;
  String? _error;

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = "Please fill in all fields.");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _auth.registerUser(
        email: email,
        password: password,
        name: name,
        role: "student",
      );

      if (!mounted) return;

      context.go("/dashboard/student"); // ✅ direct route, no modal pop
    } catch (e) {
      setState(() => _error = "Signup failed: ${e.toString()}");
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final parentState = context.findAncestorStateOfType<OnboardContentState>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Student Sign Up",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: "Full name",
              prefixIcon: Icon(Icons.person, color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: "Email address",
              prefixIcon: Icon(Icons.mail, color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: "Password",
              prefixIcon: Icon(Icons.lock, color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Sign Up"),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => parentState?.goToPage(3),
              child: const Text("Already have an account? Log in"),
            ),
          ),
        ],
      ),
    );
  }
}
