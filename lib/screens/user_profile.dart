import 'package:flutter/material.dart';
import 'package:payflex/api_call/auth_service.dart';
import 'package:payflex/core/theme.dart';
import 'package:payflex/screens/edit%20_user_profile.dart';
import 'package:payflex/screens/kycVerifcation.dart';

class ProfileDetailScreen extends StatefulWidget {
  final String? token;

  const ProfileDetailScreen({super.key, this.token});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  String? _errorMessage;

  // Active JWT Auth Token state
  late String _authToken;

  // Extracted fields matching backend JSON
  Map<String, dynamic> _profile = {};
  String _verificationTier = 'Tier 0 (Unverified)';

  // Interactive local UI state
  bool _biometricsEnabled = false;
  bool _pushNotifications = true;
  bool _twoFactorAuth = false;

  @override
  void initState() {
    super.initState();
    _authToken = widget.token ?? '';
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authService.getUserProfile(token: _authToken);

      if (response['success'] == true) {
        final profile = response['profile'] ?? {};
        setState(() {
          _profile = profile;
          _verificationTier = _resolveTierLabel(profile);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              response['message'] ?? 'Unable to fetch profile details.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error fetching account data.';
        _isLoading = false;
      });
    }
  }

  String _resolveTierLabel(Map<String, dynamic> profile) {
    final String kycStatus = (profile['kycStatus'] ?? '')
        .toString()
        .toLowerCase();
    final bool kycVerified = profile['kycVerified'] == true;

    // Check for a pending higher tier submission (Tier 3 pending admin review)
    // Backend may return pendingTier, targetTier, or kycPendingTier
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
          if (pendingNum >= 3) return 'Tier 3 (Pending Review)';
          if (pendingNum == 2) return 'Tier 2 (Pending Review)';
        } else if (kycStatus == 'verified') {
          if (pendingNum >= 3) return 'Tier 3 (Fully Verified)';
          if (pendingNum == 2) return 'Tier 2 (Fully Verified)';
        }
      }
    }

    // Resolve the user's current confirmed tier
    final dynamic rawTier =
        profile['kycTier'] ?? profile['tier'] ?? profile['verificationTier'];
    if (rawTier != null) {
      int? tierNum;
      if (rawTier is int) {
        tierNum = rawTier;
      } else {
        final match = RegExp(r'\d+').firstMatch(rawTier.toString());
        if (match != null) {
          tierNum = int.tryParse(match.group(0)!);
        }
      }

      if (tierNum != null) {
        if (tierNum >= 3) return 'Tier 3 (Fully Verified)';
        if (tierNum == 2 && kycStatus == 'pending') return 'Tier 3 (Pending Review)';
        if (tierNum == 2) return 'Tier 2 (Fully Verified)';
        if (tierNum == 1 && kycStatus == 'pending') return 'Tier 2 (Pending Review)';
        if (tierNum == 1) return 'Tier 1 (Basic Verified)';
        if (tierNum == 0 && kycStatus == 'pending') return 'Tier 1 (Pending Review)';
        return 'Tier 0 (Unverified)';
      }
      final String tierStr = rawTier.toString().trim();
      if (tierStr.isNotEmpty) return tierStr;
    }

    if (kycStatus == 'verified' || kycVerified) {
      return 'Tier 2 (Fully Verified)';
    } else if (kycStatus == 'pending') {
      return 'Tier 3 (Pending Review)';
    }
    return 'Tier 0 (Unverified)';
  }

  String _getInitials(String firstName, String lastName) {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = lastName.isNotEmpty ? lastName[0] : '';
    final combined = '$first$last'.toUpperCase();
    return combined.isNotEmpty ? combined : 'PF';
  }

  void _navigateToKyc() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            KycVerificationScreen(currentTier: _verificationTier),
      ),
    );

    if (result == true) {
      _loadProfileData();
    }
  }

  void _navigateEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EditProfileScreen(userProfile: _profile, token: _authToken),
      ),
    );

    // Refresh profile if returned updated user payload or true
    if (result != null) {
      _loadProfileData();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Account Overview',
          style: TextStyle(
            color: PayFlexColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: PayFlexColors.primary),
            onPressed: _navigateEditProfile,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: PayFlexColors.primary),
              )
            : _errorMessage != null
            ? _buildErrorView()
            : RefreshIndicator(
                onRefresh: _loadProfileData,
                color: PayFlexColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    children: [
                      // User Profile Header with Profile Image Support
                      _buildUserHeaderCard(),

                      const SizedBox(height: 20),

                      // Dynamic Verification Tier Badge
                      _buildFinancialTierCard(),

                      const SizedBox(height: 24),

                      // Personal Details List
                      _buildSectionHeader('PERSONAL DETAILS'),
                      const SizedBox(height: 10),
                      _buildMenuContainer([
                        _buildDataRow(
                          icon: Icons.person_outline_rounded,
                          label: 'Full Name',
                          value: _getFullName(),
                        ),
                        _buildDivider(),
                        _buildDataRow(
                          icon: Icons.email_outlined,
                          label: 'Email Address',
                          value: _profile['email'] ?? 'N/A',
                        ),
                        _buildDivider(),
                        _buildDataRow(
                          icon: Icons.phone_android_rounded,
                          label: 'Phone Number',
                          value: _profile['phone'] ?? 'N/A',
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // Security & Controls
                      _buildSectionHeader('SECURITY & AUTHENTICATION'),
                      const SizedBox(height: 10),
                      _buildMenuContainer([
                        _buildSwitchTile(
                          icon: Icons.fingerprint_rounded,
                          title: 'Biometric Login',
                          subtitle: 'Use Fingerprint / Face ID for access',
                          value: _biometricsEnabled,
                          onChanged: (val) =>
                              setState(() => _biometricsEnabled = val),
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          icon: Icons.phonelink_lock_rounded,
                          title: 'Two-Factor Authentication',
                          subtitle: 'Require OTP on new device login',
                          value: _twoFactorAuth,
                          onChanged: (val) =>
                              setState(() => _twoFactorAuth = val),
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // App Preferences & Info
                      _buildSectionHeader('APP PREFERENCES'),
                      const SizedBox(height: 10),
                      _buildMenuContainer([
                        _buildSwitchTile(
                          icon: Icons.notifications_active_outlined,
                          title: 'Push Notifications',
                          subtitle: 'Transaction & account updates',
                          value: _pushNotifications,
                          onChanged: (val) =>
                              setState(() => _pushNotifications = val),
                        ),
                        _buildDivider(),
                        _buildDataRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Member Since',
                          value: _formatDate(_profile['createdAt']),
                        ),
                      ]),

                      const SizedBox(height: 28),

                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () => _showLogoutDialog(context),
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: PayFlexColors.error,
                          ),
                          label: const Text(
                            'Log Out',
                            style: TextStyle(
                              color: PayFlexColors.error,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: PayFlexColors.error,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Text(
                        'PayFlex Core Engine v1.2.0',
                        style: TextStyle(
                          color: PayFlexColors.textSecondary,
                          fontSize: 12,
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

  String _getFullName() {
    final firstName = _profile['firstName'] ?? '';
    final otherName = _profile['otherName'] ?? '';
    final lastName = _profile['lastName'] ?? '';

    final nameParts = [
      firstName,
      otherName,
      lastName,
    ].where((part) => part.toString().trim().isNotEmpty).join(' ');

    return nameParts.isNotEmpty ? nameParts : 'PayFlex User';
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return 'N/A';
    try {
      final parsed = DateTime.parse(rawDate);
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (_) {
      return rawDate.split('T')[0];
    }
  }

  Widget _buildUserHeaderCard() {
    final firstName = _profile['firstName'] ?? '';
    final lastName = _profile['lastName'] ?? '';
    final profileImage = _profile['profileImage']?.toString() ?? '';
    final initials = _getInitials(firstName, lastName);

    return Column(
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
            backgroundImage: profileImage.isNotEmpty
                ? NetworkImage(profileImage)
                : null,
            child: profileImage.isEmpty
                ? Text(
                    initials,
                    style: const TextStyle(
                      color: PayFlexColors.primary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _getFullName(),
          style: const TextStyle(
            color: PayFlexColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialTierCard() {
    final kycStatus = (_profile['kycStatus'] ?? 'unsubmitted')
        .toString()
        .toLowerCase();
    final isKycVerified = _profile['kycVerified'] ?? false;

    // Determine if this is a Tier 3 pending review specifically
    final bool isTier3Pending = _verificationTier.contains('Tier 3') &&
        _verificationTier.contains('Pending');
    final bool isTier3Verified = _verificationTier.contains('Tier 3') &&
        _verificationTier.contains('Fully Verified');
    final bool isTier2Verified = _verificationTier.contains('Tier 2') &&
        _verificationTier.contains('Fully Verified');

    Color badgeBgColor;
    Color badgeTextColor;
    String badgeText;
    String statusSubtitle;
    bool showUpgradeButton = false;

    if (isTier3Verified) {
      badgeBgColor = PayFlexColors.primaryLight;
      badgeTextColor = PayFlexColors.primary;
      badgeText = 'Verified';
      statusSubtitle = 'All tier limits fully unlocked';
    } else if (isTier2Verified) {
      badgeBgColor = PayFlexColors.primaryLight;
      badgeTextColor = PayFlexColors.primary;
      badgeText = 'Verified (Tier 2)';
      statusSubtitle = 'Tap to upgrade to Tier 3 limits';
      showUpgradeButton = true;
    } else if (isTier3Pending) {
      badgeBgColor = Colors.orange.shade50;
      badgeTextColor = Colors.orange.shade800;
      badgeText = 'Pending Review';
      statusSubtitle = 'Awaiting admin approval for Tier 3';
    } else if (kycStatus == 'pending') {
      badgeBgColor = Colors.orange.shade50;
      badgeTextColor = Colors.orange.shade800;
      badgeText = 'Under Review';
      statusSubtitle = 'Verification processing...';
    } else if (kycStatus == 'failed') {
      badgeBgColor = Colors.red.shade50;
      badgeTextColor = PayFlexColors.error;
      badgeText = 'Failed';
      statusSubtitle = 'Verification rejected. Tap to retry.';
      showUpgradeButton = true;
    } else {
      badgeBgColor = Colors.amber.shade50;
      badgeTextColor = Colors.amber.shade800;
      badgeText = 'Unverified';
      statusSubtitle = 'Tap to complete identity verification';
      showUpgradeButton = true;
    }

    return InkWell(
      onTap: (!isTier3Verified && !isTier3Pending)
          ? _navigateToKyc
          : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PayFlexColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PayFlexColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PayFlexColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: PayFlexColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _verificationTier,
                    style: const TextStyle(
                      color: PayFlexColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    statusSubtitle,
                    style: TextStyle(
                      color: (kycStatus == 'failed')
                          ? PayFlexColors.error
                          : PayFlexColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (showUpgradeButton) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: PayFlexColors.textSecondary,
                    size: 20,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: PayFlexColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildMenuContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: PayFlexColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PayFlexColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDataRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: PayFlexColors.iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: PayFlexColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: PayFlexColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: PayFlexColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: PayFlexColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: PayFlexColors.iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: PayFlexColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: PayFlexColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: PayFlexColors.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      color: PayFlexColors.border,
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: PayFlexColors.error,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Failed to connect to backend',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PayFlexColors.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProfileData,
              style: ElevatedButton.styleFrom(
                backgroundColor: PayFlexColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Retry Connection',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PayFlexColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log Out',
          style: TextStyle(
            color: PayFlexColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of PayFlex?',
          style: TextStyle(color: PayFlexColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: PayFlexColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Log Out',
              style: TextStyle(
                color: PayFlexColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
