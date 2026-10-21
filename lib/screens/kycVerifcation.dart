import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:payflex/api_call/auth_service.dart';
import 'package:payflex/core/theme.dart';

class KycVerificationScreen extends StatefulWidget {
  final String currentTier;

  const KycVerificationScreen({super.key, this.currentTier = 'Tier 1'});

  @override
  State<KycVerificationScreen> createState() => _KycVerificationScreenState();
}

class _KycVerificationScreenState extends State<KycVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  String _selectedDocType = 'NIN_CARD';
  File? _selectedDocumentImage;

  final TextEditingController _documentNumberController =
      TextEditingController();
  final TextEditingController _ninController = TextEditingController();

  bool _isSubmitting = false;

  final List<Map<String, String>> _docTypes = [
    {'label': 'National Identity Card (NIN)', 'value': 'NIN_CARD'},
    {'label': 'Bank Verification Number (BVN)', 'value': 'BVN'},
    {'label': 'International Passport', 'value': 'PASSPORT'},
    {"label": "Voter's Card", 'value': 'VOTERS_CARD'},
  ];

  bool get _isNinCard => _selectedDocType == 'NIN_CARD';
  bool get _isBvn => _selectedDocType == 'BVN';

  @override
  void dispose() {
    _documentNumberController.dispose();
    _ninController.dispose();
    super.dispose();
  }

  int _resolveTargetTier() {
    final match = RegExp(r'\d+').firstMatch(widget.currentTier);
    final current = match != null ? int.tryParse(match.group(0)!) ?? 0 : 0;
    return current < 2 ? 2 : 3;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() => _selectedDocumentImage = File(image.path));
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: PayFlexColors.primary,
                ),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: PayFlexColors.primary,
                ),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitKyc() async {
    if (!_formKey.currentState!.validate()) return;

    final int targetTier = _resolveTargetTier();

    if (targetTier == 3 && _selectedDocumentImage == null) {
      _showErrorSnackBar(
        'Please upload a clear image of your document for Tier 3.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final String docNum = _documentNumberController.text.trim();
    final String ninNum = _ninController.text.trim();

    final Map<String, dynamic> fields = {
      'targetTier': targetTier,
      'documentType': _selectedDocType,
      'documentNumber': docNum,
    };

    if (_isBvn) {
      fields['bvn'] = docNum;
    } else if (_isNinCard) {
      fields['nin'] = ninNum;
    }

    try {
      // Fixed: Passing 'data' parameter to match AuthService signature
      final response = await _authService.submitKycVerification(
        data: fields,
        documentFile: _selectedDocumentImage,
        fields: {},
      );

      if (!mounted) return;

      if (response['success'] == true) {
        _showSuccessBottomSheet(
          response['message'] ?? 'Verification details submitted successfully.',
        );
      } else {
        _showErrorSnackBar(response['message'] ?? 'KYC Verification failed.');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Network error submitting verification details.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: PayFlexColors.error),
    );
  }

  void _showSuccessBottomSheet(String message) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: PayFlexColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: PayFlexColors.primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Verification Submitted',
              style: TextStyle(
                color: PayFlexColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PayFlexColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PayFlexColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Back to Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int nextTier = _resolveTargetTier();

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
          'Identity Verification',
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PayFlexColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: PayFlexColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: PayFlexColors.primary,
                        size: 32,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upgrade to Tier $nextTier',
                              style: const TextStyle(
                                color: PayFlexColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nextTier == 2
                                  ? 'Verify your BVN or NIN to instantly unlock Tier 2 daily limits.'
                                  : 'Upload an official ID document to apply for Tier 3 higher limits.',
                              style: const TextStyle(
                                color: PayFlexColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                _buildFieldLabel('Document Type'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: PayFlexColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: PayFlexColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDocType,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: PayFlexColors.primary,
                      ),
                      items: _docTypes.map((doc) {
                        return DropdownMenuItem<String>(
                          value: doc['value'],
                          child: Text(
                            doc['label']!,
                            style: const TextStyle(
                              color: PayFlexColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedDocType = val;
                            _documentNumberController.clear();
                            _ninController.clear();
                          });
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                _buildFieldLabel(
                  _isBvn
                      ? '11-Digit BVN'
                      : _isNinCard
                      ? 'NIN Slip / Card Serial Number (Optional)'
                      : 'Document Number',
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _documentNumberController,
                  keyboardType: _isBvn || _isNinCard
                      ? TextInputType.number
                      : TextInputType.text,
                  maxLength: _isBvn ? 11 : 25,
                  validator: (val) {
                    final trimmed = val?.trim() ?? '';
                    if (!_isNinCard && trimmed.isEmpty) {
                      return 'Please enter document number';
                    }
                    if (_isBvn && trimmed.length != 11) {
                      return 'BVN must be exactly 11 digits';
                    }
                    return null;
                  },
                  style: const TextStyle(
                    color: PayFlexColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: _buildInputDecoration(
                    hintText: _isBvn
                        ? 'Enter 11-digit BVN'
                        : 'Enter document number',
                    icon: _isBvn ? Icons.numbers_rounded : Icons.badge_outlined,
                  ),
                ),

                if (_isNinCard) ...[
                  const SizedBox(height: 12),
                  _buildFieldLabel('11-Digit NIN'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _ninController,
                    keyboardType: TextInputType.number,
                    maxLength: 11,
                    validator: (val) {
                      final trimmed = val?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return 'Please enter your 11-digit NIN';
                      }
                      if (trimmed.length != 11) {
                        return 'NIN must be exactly 11 digits';
                      }
                      return null;
                    },
                    style: const TextStyle(
                      color: PayFlexColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: _buildInputDecoration(
                      hintText: 'Enter 11-digit NIN',
                      icon: Icons.pin_outlined,
                    ),
                  ),
                ],

                if (nextTier == 3) ...[
                  const SizedBox(height: 18),
                  _buildFieldLabel('Upload Document Image'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _showImagePickerOptions,
                    child: Container(
                      width: double.infinity,
                      height: 140,
                      decoration: BoxDecoration(
                        color: PayFlexColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedDocumentImage != null
                              ? PayFlexColors.primary
                              : PayFlexColors.border,
                        ),
                      ),
                      child: _selectedDocumentImage != null
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    _selectedDocumentImage!,
                                    width: double.infinity,
                                    height: 140,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(
                                        () => _selectedDocumentImage = null,
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 36,
                                  color: PayFlexColors.primary,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tap to upload NIN Card / Passport image',
                                  style: TextStyle(
                                    color: PayFlexColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitKyc,
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
                            'Verify Identity',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: PayFlexColors.textSecondary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Your identity data is securely encrypted',
                        style: TextStyle(
                          color: PayFlexColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
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

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      counterText: '',
      hintText: hintText,
      hintStyle: const TextStyle(
        color: PayFlexColors.textSecondary,
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: PayFlexColors.primary, size: 20),
      filled: true,
      fillColor: PayFlexColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        borderSide: const BorderSide(color: PayFlexColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PayFlexColors.error),
      ),
    );
  }
}
