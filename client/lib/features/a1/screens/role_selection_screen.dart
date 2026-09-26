import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoleSelectionScreen extends StatefulWidget {
  final String? fullName;
  final String? email;

  const RoleSelectionScreen({
    super.key,
    this.fullName,
    this.email,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _roles = [
    {'title': 'Athlete', 'icon': Icons.directions_run, 'value': 'athlete'},
    {'title': 'Coach', 'icon': Icons.sports, 'value': 'coach'},
    {'title': 'Employer / Recruiter', 'icon': Icons.work_outline, 'value': 'employer'},
    {'title': 'Institute', 'icon': Icons.school_outlined, 'value': 'institute'},
  ];

  Future<void> _handleContinue() async {
    if (_selectedRole == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'user_id': user.uid,
          'full_name': widget.fullName ?? (user.displayName ?? 'User'),
          'email': widget.email ?? (user.email ?? ''),
          'role': _selectedRole,
          'created_at': FieldValue.serverTimestamp(),
          'is_verified': false,
          'is_active': true,
        }, SetOptions(merge: true));
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully! 🎉')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              const Text(
                'Who Are You? 🤔',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select your role to personalize your experience',
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),

              const SizedBox(height: 32),

              Expanded(
                child: ListView.builder(
                  itemCount: _roles.length,
                  itemBuilder: (context, index) {
                    final role = _roles[index];
                    final isSelected = _selectedRole == role['value'];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRole = role['value'];
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.deepOrange.withOpacity(0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.deepOrange
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              role['icon'],
                              size: 32,
                              color: isSelected
                                  ? Colors.deepOrange
                                  : Colors.black54,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              role['title'],
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.deepOrange
                                    : Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.deepOrange,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_selectedRole == null || _isLoading)
                      ? null
                      : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}