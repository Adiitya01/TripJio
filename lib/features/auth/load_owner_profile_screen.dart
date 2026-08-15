import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/session_service.dart';
import '../../data/repositories/user_repository.dart';
import 'location_permission_screen.dart';

class LoadOwnerProfileScreen extends StatefulWidget {
  const LoadOwnerProfileScreen({super.key});

  @override
  State<LoadOwnerProfileScreen> createState() =>
      _LoadOwnerProfileScreenState();
}

class _LoadOwnerProfileScreenState extends State<LoadOwnerProfileScreen> {
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  String? _selectedCity;
  bool _isSaving = false;

  static const _cities = [
    'Mumbai', 'Delhi', 'Bangalore', 'Chennai', 'Hyderabad',
    'Kolkata', 'Pune', 'Ahmedabad', 'Jaipur', 'Surat',
    'Nagpur', 'Lucknow', 'Indore', 'Bhopal', 'Coimbatore',
  ];

  bool get _canContinue =>
      _nameController.text.trim().isNotEmpty && !_isSaving;

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? '';
      final phone = user?.phoneNumber ?? '';

      // ⚛️ ACID: atomic load owner signup (single transaction)
      await UserRepository().signupLoadOwnerAtomic(
        uid: uid,
        phone: phone,
        name: _nameController.text.trim(),
        companyName: _companyController.text.trim().isNotEmpty
            ? _companyController.text.trim()
            : null,
        city: _selectedCity,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userType', 'load_owner');
      await prefs.setString('uid', uid);

      // Register this device as the active session
      await SessionService.registerSession(uid);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) =>
                const LocationPermissionScreen(isDriver: false)),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save profile. Please try again.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Complete profile',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tell us about yourself',
                      style:
                          TextStyle(fontSize: 15, color: Colors.black54),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF003F7D),
                                width: 2,
                              ),
                            ),
                            child: const Icon(Icons.person,
                                size: 54, color: Colors.black87),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF003F7D),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _label('FULL NAME'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      onChanged: (_) => setState(() {}),
                      decoration: _inputDeco('Rajesh Sharma'),
                    ),
                    const SizedBox(height: 20),
                    _label('COMPANY NAME (OPTIONAL)'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _companyController,
                      decoration: _inputDeco('Sharma Textiles'),
                    ),
                    const SizedBox(height: 20),
                    _label('CITY'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCity,
                      hint: const Text('Select city',
                          style: TextStyle(color: Colors.black38)),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFF003F7D)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      items: _cities
                          .map((c) => DropdownMenuItem(
                              value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedCity = v),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _canContinue ? _saveProfile : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003F7D),
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Continue',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
          letterSpacing: 0.5,
        ),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF003F7D)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
