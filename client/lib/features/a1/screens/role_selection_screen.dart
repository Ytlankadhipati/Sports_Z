import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final AuthService _authService = AuthService();
  String? _selectedRole;
  bool _isLoading = false;
  String? _errorMessage;

  final List<Map<String, dynamic>> _roles = [
    {'title': 'Athlete', 'icon': Icons.directions_run, 'value': 'athlete'},
    {'title': 'Coach', 'icon': Icons.sports, 'value': 'coach'},
    {'title': 'Recruiter', 'icon': Icons.work_outline, 'value': 'recruiter'},
    {'title': 'Institute', 'icon': Icons.school_outlined, 'value': 'institute'},
  ];

  Future<void> _handleContinue() async {
    if (_selectedRole == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final data = await _authService.selectRoleOnBackend(_selectedRole!);

    setState(() {
      _isLoading = false;
    });

    if (data == null) {
      setState(() {
        _errorMessage =
        'Role save nahi hua. Backend chal raha hai check karo.';
      });
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role set successfully! 🎉')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
      );
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
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
                const SizedBox(height: 8),
              ],
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