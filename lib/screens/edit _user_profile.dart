import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:payflex/api_call/auth_service.dart';
import 'package:payflex/core/theme.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final String token;

  const EditProfileScreen({
    super.key,
    required this.userProfile,
    required this.token,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImageFile;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _otherNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing backend profile data
    _firstNameController = TextEditingController(
      text: widget.userProfile['firstName'] ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.userProfile['lastName'] ?? '',
    );
    _otherNameController = TextEditingController(
      text: widget.userProfile['otherName'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.userProfile['email'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.userProfile['phone'] ?? '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _otherNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1000,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: PayFlexColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_rounded,
                    color: PayFlexColors.primary,
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(
                      color: PayFlexColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_rounded,
                    color: PayFlexColors.primary,
                  ),
                  title: const Text(
                    'Take Photo',
                    style: TextStyle(
                      color: PayFlexColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleProfileUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final updatedData = {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'otherName': _otherNameController.text.trim(),
      'phone': _phoneController.text.trim(),
    };

    try {
      final response = await _authService.updateUserProfile(
        data: updatedData,
        token: widget.token,
        imageFile: _selectedImageFile,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Profile updated successfully!',
            ),
            backgroundColor: PayFlexColors.primary,
          ),
        );
        // Return updated user payload to trigger refresh in ProfileDetailScreen
        Navigator.pop(context, response['user'] ?? true);
      } else {
        _showErrorSnackBar(response['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('An error occurred while saving profile changes.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: PayFlexColors.error),
    );
  }

  String _getInitials() {
    final first = _firstNameController.text.trim().isNotEmpty
        ? _firstNameController.text.trim()[0]
        : '';
    final last = _lastNameController.text.trim().isNotEmpty
        ? _lastNameController.text.trim()[0]
        : '';
    final combined = '$first$last'.toUpperCase();
    return combined.isNotEmpty ? combined : 'PF';
  }

  @override
  Widget build(BuildContext context) {
    final String existingImageUrl = widget.userProfile['profileImage'] ?? '';

    return Scaffold(
      backgroundColor: PayFlexColors.background,
      appBar: AppBar(
        backgroundColor: PayFlexColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: PayFlexColors.textPrimary,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: PayFlexColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Preview Header with Camera Button
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: PayFlexColors.primary.withOpacity(0.2),
                                width: 3,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 46,
                              backgroundColor: PayFlexColors.primaryLight,
                              backgroundImage: _selectedImageFile != null
                                  ? FileImage(_selectedImageFile!)
                                        as ImageProvider
                                  : (existingImageUrl.isNotEmpty
                                        ? NetworkImage(existingImageUrl)
                                        : null),
                              child:
                                  (_selectedImageFile == null &&
                                      existingImageUrl.isEmpty)
                                  ? Text(
                                      _getInitials(),
                                      style: const TextStyle(
                                        color: PayFlexColors.primary,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: _showImagePickerModal,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: PayFlexColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Tap camera icon to change profile picture',
                        style: TextStyle(
                          color: PayFlexColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Form Fields Group
                _buildFieldLabel('First Name'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _firstNameController,
                  hintText: 'Enter first name',
                  icon: Icons.person_outline_rounded,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'First name is required'
                      : null,
                ),

                const SizedBox(height: 18),

                _buildFieldLabel('Middle / Other Name'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _otherNameController,
                  hintText: 'Enter middle or other name',
                  icon: Icons.person_outline_rounded,
                ),

                const SizedBox(height: 18),

                _buildFieldLabel('Last Name'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _lastNameController,
                  hintText: 'Enter last name',
                  icon: Icons.person_outline_rounded,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Last name is required'
                      : null,
                ),

                const SizedBox(height: 18),

                _buildFieldLabel('Phone Number'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _phoneController,
                  hintText: 'Enter phone number',
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Phone number is required'
                      : null,
                ),

                const SizedBox(height: 18),

                _buildFieldLabel('Email Address (Read Only)'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _emailController,
                  hintText: 'Email address',
                  icon: Icons.email_outlined,
                  readOnly: true,
                ),

                const SizedBox(height: 32),

                // Save Changes Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleProfileUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PayFlexColors.primary,
                      disabledBackgroundColor: PayFlexColors.primaryLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
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
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: PayFlexColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: (_) => setState(() {}),
      style: TextStyle(
        color: readOnly
            ? PayFlexColors.textSecondary
            : PayFlexColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: PayFlexColors.textSecondary,
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: PayFlexColors.primary, size: 20),
        filled: true,
        fillColor: readOnly
            ? PayFlexColors.border.withOpacity(0.3)
            : PayFlexColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PayFlexColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PayFlexColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: PayFlexColors.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PayFlexColors.error),
        ),
      ),
    );
  }
}
