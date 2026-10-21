import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:payflex/core/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Security Toggles
  bool _biometricsEnabled = true;
  bool _twoFactorEnabled = true;
  bool _hideBalance = false;

  // Notification Toggles
  bool _pushNotifications = true;
  bool _emailAlerts = true;
  bool _marketingEmails = false;

  void _showChangePinModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ChangePinBottomSheet(),
    );
  }

  void _showLogoutDialog() {
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
          'Are you sure you want to log out of your PayFlex account on this device?',
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle logout navigation or state reset
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
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
          'Settings & Security',
          style: TextStyle(
            color: PayFlexColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Section: Security & Authentication
            _buildSectionHeader('SECURITY & AUTHENTICATION'),
            _buildSettingsContainer([
              _buildSwitchTile(
                icon: Icons.fingerprint_rounded,
                title: 'Biometric Unlock',
                subtitle:
                    'Use Face ID or Fingerprint to authorize transactions',
                value: _biometricsEnabled,
                onChanged: (val) {
                  setState(() => _biometricsEnabled = val);
                },
              ),
              const Divider(height: 1, color: PayFlexColors.border),
              _buildActionTile(
                icon: Icons.lock_outline_rounded,
                title: 'Change Transaction PIN',
                subtitle: 'Update your 4-digit security PIN',
                onTap: _showChangePinModal,
              ),
              const Divider(height: 1, color: PayFlexColors.border),
              _buildSwitchTile(
                icon: Icons.shield_outlined,
                title: '2-Factor Authentication (2FA)',
                subtitle: 'Require SMS/Email OTP for new logins',
                value: _twoFactorEnabled,
                onChanged: (val) {
                  setState(() => _twoFactorEnabled = val);
                },
              ),
            ]),

            const SizedBox(height: 24),

            // Section: App Preferences
            _buildSectionHeader('PREFERENCES'),
            _buildSettingsContainer([
              _buildSwitchTile(
                icon: Icons.visibility_off_outlined,
                title: 'Hide Account Balance',
                subtitle: 'Mask wallet balance by default on startup',
                value: _hideBalance,
                onChanged: (val) {
                  setState(() => _hideBalance = val);
                },
              ),
              const Divider(height: 1, color: PayFlexColors.border),
              _buildSwitchTile(
                icon: Icons.notifications_none_rounded,
                title: 'Push Notifications',
                subtitle: 'Get real-time transaction alerts',
                value: _pushNotifications,
                onChanged: (val) {
                  setState(() => _pushNotifications = val);
                },
              ),
              const Divider(height: 1, color: PayFlexColors.border),
              _buildSwitchTile(
                icon: Icons.mark_email_read_outlined,
                title: 'Email Receipts',
                subtitle: 'Receive instant transaction statements via email',
                value: _emailAlerts,
                onChanged: (val) {
                  setState(() => _emailAlerts = val);
                },
              ),
            ]),

            const SizedBox(height: 24),

            // Section: Support & Legal
            _buildSectionHeader('SUPPORT & ABOUT'),
            _buildSettingsContainer([
              _buildActionTile(
                icon: Icons.headset_mic_outlined,
                title: 'Help & Support',
                subtitle: 'Contact PayFlex customer service 24/7',
                onTap: () {},
              ),
              const Divider(height: 1, color: PayFlexColors.border),
              _buildActionTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service & Privacy',
                subtitle: 'Read legal terms and data policies',
                onTap: () {},
              ),
            ]),

            const SizedBox(height: 32),

            // Danger Zone / Logout Button
            OutlinedButton.icon(
              onPressed: _showLogoutDialog,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              label: const Text(
                'Log Out',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),

            const SizedBox(height: 16),

            const Center(
              child: Text(
                'PayFlex v2.4.0 • Build 2026.09',
                style: TextStyle(
                  color: PayFlexColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: PayFlexColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingsContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: PayFlexColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PayFlexColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: PayFlexColors.iconBg,
        child: Icon(icon, color: PayFlexColors.textPrimary, size: 18),
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
          fontSize: 11,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        activeColor: PayFlexColors.primary,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: PayFlexColors.iconBg,
        child: Icon(icon, color: PayFlexColors.textPrimary, size: 18),
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
          fontSize: 11,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: PayFlexColors.textSecondary,
        size: 20,
      ),
    );
  }
}

class ChangePinBottomSheet extends StatefulWidget {
  const ChangePinBottomSheet({super.key});

  @override
  State<ChangePinBottomSheet> createState() => _ChangePinBottomSheetState();
}

class _ChangePinBottomSheetState extends State<ChangePinBottomSheet> {
  int _step = 1; // 1: Current PIN, 2: New PIN, 3: Confirm PIN
  final List<String> _currentPin = [];
  final List<String> _newPin = [];
  final List<String> _confirmPin = [];

  void _onKeyPress(String val) {
    setState(() {
      List<String> targetList = _step == 1
          ? _currentPin
          : _step == 2
          ? _newPin
          : _confirmPin;

      if (targetList.length < 4) {
        targetList.add(val);
      }

      if (targetList.length == 4) {
        _handleStepCompletion();
      }
    });
  }

  void _onDelete() {
    setState(() {
      List<String> targetList = _step == 1
          ? _currentPin
          : _step == 2
          ? _newPin
          : _confirmPin;

      if (targetList.isNotEmpty) {
        targetList.removeLast();
      }
    });
  }

  void _handleStepCompletion() {
    if (_step == 1) {
      // Simulate Current PIN verification
      Future.delayed(const Duration(milliseconds: 200), () {
        setState(() => _step = 2);
      });
    } else if (_step == 2) {
      Future.delayed(const Duration(milliseconds: 200), () {
        setState(() => _step = 3);
      });
    } else if (_step == 3) {
      if (_newPin.join() == _confirmPin.join()) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction PIN reset successfully!'),
            backgroundColor: PayFlexColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PINs do not match. Try again.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _confirmPin.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String titleText = _step == 1
        ? 'Enter Current PIN'
        : _step == 2
        ? 'Enter New PIN'
        : 'Confirm New PIN';

    List<String> activeList = _step == 1
        ? _currentPin
        : _step == 2
        ? _newPin
        : _confirmPin;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: PayFlexColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: PayFlexColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            titleText,
            style: const TextStyle(
              color: PayFlexColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your 4-digit security PIN to proceed',
            style: TextStyle(color: PayFlexColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // PIN Input Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < activeList.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled
                      ? PayFlexColors.primary
                      : PayFlexColors.border,
                  border: Border.all(
                    color: isFilled
                        ? PayFlexColors.primary
                        : PayFlexColors.border,
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 32),

          // Custom Numeric Keypad
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 12,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.6,
              crossAxisSpacing: 16,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              if (index == 9) return const SizedBox.shrink();
              if (index == 10) return _buildKeypadButton('0');
              if (index == 11) {
                return InkWell(
                  onTap: _onDelete,
                  borderRadius: BorderRadius.circular(16),
                  child: const Center(
                    child: Icon(
                      Icons.backspace_outlined,
                      color: PayFlexColors.textPrimary,
                      size: 20,
                    ),
                  ),
                );
              }
              return _buildKeypadButton('${index + 1}');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildKeypadButton(String number) {
    return InkWell(
      onTap: () => _onKeyPress(number),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: PayFlexColors.border,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PayFlexColors.border),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              color: PayFlexColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
