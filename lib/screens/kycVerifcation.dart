import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:payflex/api_call/auth_service.dart';
import 'package:payflex/core/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _isLoadingProfile = false;
  String _currentTier = 'Tier 1';

  /// Tier 2 only accepts NIN
  static const List<Map<String, String>> _tier2DocTypes = [
    {'label': 'National Identity Card (NIN)', 'value': 'NIN_CARD'},
  ];

  /// Tier 3 only accepts BVN
  static const List<Map<String, String>> _tier3DocTypes = [
    {'label': 'Bank Verification Number (BVN)', 'value': 'BVN'},
  ];

  /// Returns the correct doc-type list based on the target tier
  List<Map<String, String>> get _docTypes =>
      _resolveTargetTier() == 3 ? _tier3DocTypes : _tier2DocTypes;

  @override
  void initState() {
    super.initState();
    _currentTier = widget.currentTier;
    final target = _resolveTargetTier();
    _selectedDocType = target == 3 ? 'BVN' : 'NIN_CARD';
    _fetchLatestTier();
  }

  Future<void> _fetchLatestTier() async {
    setState(() => _isLoadingProfile = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? prefs.getString('access_token') ?? prefs.getString('auth_token');
      if (token != null && token.isNotEmpty) {
        final resp = await _authService.getUserProfile(token: token);
        if (resp['success'] == true && resp['profile'] != null) {
          final profile = resp['profile'];
          String newTier = _currentTier;
          final dynamic rawTier = profile['kycTier'] ?? profile['tier'] ?? profile['verificationTier'];
          final String kycStatus = (profile['kycStatus'] ?? '').toString().toLowerCase();
          final bool kycVerified = profile['kycVerified'] == true;

          final dynamic rawPendingTier = profile['pendingTier'] ??
              profile['targetTier'] ??
              profile['kycPendingTier'] ??
              profile['kycTargetTier'];

          if (rawPendingTier != null) {
            int? pendingNum;
            if (rawPendingTier is int) {
              pendingNum = rawPendingTier;
            } else {
              final match = RegExp(r'\d+').firstMatch(rawPendingTier.toString());
              if (match != null) {
                pendingNum = int.tryParse(match.group(0)!);
              }
            }

            if (pendingNum != null) {
              if (kycStatus == 'pending') {
                if (pendingNum >= 3) newTier = 'Tier 3 (Pending Review)';
                else if (pendingNum == 2) newTier = 'Tier 2 (Pending Review)';
              } else if (kycStatus == 'verified') {
                if (pendingNum >= 3) newTier = 'Tier 3 (Fully Verified)';
                else if (pendingNum == 2) newTier = 'Tier 2 (Fully Verified)';
              }
            }
          }
          
          if (newTier == _currentTier && rawTier != null) {
            int t = 0;
            if (rawTier is int) {
              t = rawTier;
            } else {
              final match = RegExp(r'\d+').firstMatch(rawTier.toString());
              if (match != null) {
                t = int.tryParse(match.group(0)!) ?? 0;
              }
            }

            if (t >= 3) {
              newTier = 'Tier 3 (Fully Verified)';
            } else if (t == 2 && kycStatus == 'pending') {
              newTier = 'Tier 3 (Pending Review)';
            } else if (t == 2) {
              newTier = 'Tier 2 (Fully Verified)';
            } else if (t == 1 && kycStatus == 'pending') {
              newTier = 'Tier 2 (Pending Review)';
            } else if (t == 1) {
              newTier = 'Tier 1 (Basic Verified)';
            } else if (t == 0 && kycStatus == 'pending') {
              newTier = 'Tier 1 (Pending Review)';
            }
          } else if (newTier == _currentTier) {
            if (kycStatus == 'verified' || kycVerified) {
              newTier = 'Tier 2 (Fully Verified)';
            } else if (kycStatus == 'pending') {
              newTier = 'Tier 3 (Pending Review)';
            }
          }

          if (mounted) {
            setState(() {
              _currentTier = newTier;
              final target = _resolveTargetTier();
              _selectedDocType = target == 3 ? 'BVN' : 'NIN_CARD';
            });
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingProfile = false);
    }
  }

  bool get _isNinCard => _selectedDocType == 'NIN_CARD';
  bool get _isBvn => _selectedDocType == 'BVN';

  @override
  void dispose() {
    _documentNumberController.dispose();
    _ninController.dispose();
    super.dispose();
  }

  int _resolveTargetTier() {
    // If pending review, extract tier from the string (e.g. 'Tier 3 (Pending Review)')
    final pendingMatch = RegExp(r'Tier (\d+).*Pending').firstMatch(_currentTier);
    if (pendingMatch != null) {
      return int.tryParse(pendingMatch.group(1)!) ?? 3;
    }
    final match = RegExp(r'\d+').firstMatch(_currentTier);
    final current = match != null ? int.tryParse(match.group(0)!) ?? 0 : 0;
    // Tier 0/1 → upgrade to Tier 2; Tier 2 → upgrade to Tier 3
    return current < 2 ? 2 : 3;
  }

  /// Returns true if the user's KYC is pending admin review (any tier)
  bool get _isPendingReview => _currentTier.contains('Pending');

  /// Returns true if the user is already fully verified at Tier 3
  bool get _isAlreadyVerified =>
      _currentTier.contains('Tier 3') && _currentTier.contains('Fully Verified');

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

    // Build payload with only the fields the backend expects
    final Map<String, dynamic> fields = {
      'targetTier': targetTier,
      'documentType': _selectedDocType,
    };

    if (_isBvn) {
      fields['bvn'] = docNum;
      fields['documentNumber'] = docNum;
    } else if (_isNinCard) {
      fields['nin'] = ninNum;
    } else {
      // Passport or any other doc type
      fields['documentNumber'] = docNum;
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
      body: _isLoadingProfile
          ? const Center(
              child: CircularProgressIndicator(color: PayFlexColors.primary),
            )
          : _isAlreadyVerified
              ? _buildVerifiedView()
              : _isPendingReview
                  ? _buildPendingReviewView()
                  : SafeArea(
                      child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 12.0,
                    ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Tier Upgrade',
                                        style: TextStyle(
                                          color: PayFlexColors.primary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        nextTier == 2
                                            ? 'Verify your NIN to unlock Tier 2 daily limits.'
                                            : 'Provide your BVN and upload an official ID to apply for Tier 3 higher limits.',
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
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

                          // BVN / non-NIN document number field
                          if (!_isNinCard) ...[
                            _buildFieldLabel(
                              _isBvn ? '11-Digit BVN' : 'Document Number',
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _documentNumberController,
                              keyboardType: _isBvn
                                  ? TextInputType.number
                                  : TextInputType.text,
                              maxLength: _isBvn ? 11 : 25,
                              validator: (val) {
                                final trimmed = val?.trim() ?? '';
                                if (trimmed.isEmpty) {
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
                                icon: _isBvn
                                    ? Icons.numbers_rounded
                                    : Icons.badge_outlined,
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],

                          // NIN-specific: only the 11-digit NIN field
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

                          // Document upload — always visible for any tier submission
                          const SizedBox(height: 18),
                          _buildFieldLabel(
                            nextTier == 3
                                ? 'Upload Document Image (Required)'
                                : 'Upload Supporting Document (Optional)',
                          ),
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
                                          borderRadius:
                                              BorderRadius.circular(16),
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
                                                () => _selectedDocumentImage =
                                                    null,
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.cloud_upload_outlined,
                                          size: 36,
                                          color: PayFlexColors.primary,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          nextTier == 3
                                              ? 'Tap to upload BVN document'
                                              : 'Tap to upload a supporting document (optional)',
                                          style: const TextStyle(
                                            color: PayFlexColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitKyc,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PayFlexColors.primary,
                                disabledBackgroundColor:
                                    PayFlexColors.primaryLight,
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

  /// Shown when KYC has been fully verified — form is locked to prevent re-uploads
  Widget _buildVerifiedView() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified_rounded,
                size: 56,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Identity Verified',
              style: TextStyle(
                color: PayFlexColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your identity has been successfully verified. No further action is needed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PayFlexColors.textSecondary,
                fontSize: 14,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  _buildStatusRow(
                    icon: Icons.check_circle_rounded,
                    iconColor: Colors.green.shade600,
                    label: 'Verification Status',
                    value: 'Approved',
                    valueColor: Colors.green.shade700,
                  ),
                  const SizedBox(height: 12),
                  _buildStatusRow(
                    icon: Icons.lock_rounded,
                    iconColor: Colors.green.shade600,
                    label: 'Re-submission',
                    value: 'Locked',
                    valueColor: Colors.green.shade700,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: PayFlexColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PayFlexColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: PayFlexColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'To re-submit verification documents, please contact support. Multiple uploads are not permitted.',
                      style: TextStyle(
                        color: PayFlexColors.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.maybePop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: PayFlexColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Back to Profile',
                  style: TextStyle(
                    color: PayFlexColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Shown when KYC submission is awaiting admin review — form locked to prevent duplicate uploads
  Widget _buildPendingReviewView() {
    // Determine which tier is under review from the currentTier string
    final tierMatch = RegExp(r'Tier (\d+)').firstMatch(widget.currentTier);
    final tierLabel = tierMatch != null ? 'Tier ${tierMatch.group(1)}' : 'Your';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.hourglass_top_rounded,
                size: 56,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '$tierLabel — Under Review',
              style: const TextStyle(
                color: PayFlexColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your $tierLabel identity verification documents have been submitted and are currently being reviewed by our compliance team.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PayFlexColors.textSecondary,
                fontSize: 14,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  _buildStatusRow(
                    icon: Icons.check_circle_outline,
                    iconColor: Colors.green.shade600,
                    label: 'Documents Submitted',
                    value: 'Complete',
                    valueColor: Colors.green.shade700,
                  ),
                  const SizedBox(height: 12),
                  _buildStatusRow(
                    icon: Icons.pending_outlined,
                    iconColor: Colors.orange.shade700,
                    label: 'Admin Review',
                    value: 'In Progress',
                    valueColor: Colors.orange.shade800,
                  ),
                  const SizedBox(height: 12),
                  _buildStatusRow(
                    icon: Icons.lock_open_outlined,
                    iconColor: PayFlexColors.textSecondary,
                    label: '$tierLabel Activation',
                    value: 'Pending',
                    valueColor: PayFlexColors.textSecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: PayFlexColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PayFlexColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: PayFlexColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You will be notified once your $tierLabel verification is approved. This usually takes 1–3 business days.',
                      style: const TextStyle(
                        color: PayFlexColors.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.maybePop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: PayFlexColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Back to Profile',
                  style: TextStyle(
                    color: PayFlexColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: PayFlexColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
