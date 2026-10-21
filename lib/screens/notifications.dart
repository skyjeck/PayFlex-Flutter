import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Ensure this is imported
import 'package:payflex/api_call/notification_service.dart';
import 'package:payflex/core/theme.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String time;
  final String category;
  final IconData icon;
  final Color iconColor;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.category,
    required this.icon,
    required this.iconColor,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final String apiType = json['type'] ?? 'INFO';
    String category = 'Promos';
    IconData icon = Icons.notifications_rounded;
    Color iconColor = PayFlexColors.primary;

    if (apiType.contains('ALERT') || apiType.contains('TRANSACTION')) {
      category = 'Transactions';
      icon = Icons.receipt_long_rounded;
      iconColor = Colors.blueAccent;
    } else if (apiType.contains('SECURITY') || apiType.contains('LOGIN')) {
      category = 'Security';
      icon = Icons.security_rounded;
      iconColor = Colors.orangeAccent;
    } else if (apiType.contains('PROMO')) {
      category = 'Promos';
      icon = Icons.card_giftcard_rounded;
      iconColor = Colors.purpleAccent;
    }

    return NotificationModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? 'Notification',
      body: json['message'] ?? '',
      time: _formatDate(json['createdAt']),
      category: category,
      icon: icon,
      iconColor: iconColor,
      isRead: json['isRead'] ?? false,
    );
  }

  static String _formatDate(String? isoString) {
    if (isoString == null) return 'Just now';
    try {
      final date = DateTime.parse(isoString);
      final difference = DateTime.now().difference(date);
      if (difference.inDays > 1) return '${difference.inDays} days ago';
      if (difference.inHours > 0) return '${difference.inHours} hours ago';
      if (difference.inMinutes > 0) return '${difference.inMinutes} mins ago';
      return 'Just now';
    } catch (e) {
      return 'Recently';
    }
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  // Variables are declared here but not initialized asynchronously
  String _authToken = '';
  String _selectedCategory = 'All';
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // 1. Kick off the token fetch when the screen loads
    _initializeTokenAndFetch();
  }

  Future<void> _initializeTokenAndFetch() async {
    try {
      // 2. Safely await SharedPreferences inside an async method
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _authToken = prefs.getString('token') ?? '';
      });

      if (_authToken.isNotEmpty) {
        // 3. Once we have the token, fetch the notifications
        await _fetchNotifications();
      } else {
        setState(() {
          _errorMessage = 'User not authenticated. Please log in again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load session data.';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final data = await _notificationService.getNotifications(
        token: _authToken, // Using the real fetched token
        limit: 50,
      );

      final List<dynamic> rawNotifications =
          data['notifications'] ?? data['data'] ?? data;

      setState(() {
        _notifications = rawNotifications
            .map((json) => NotificationModel.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      for (var item in _notifications) {
        item.isRead = true;
      }
    });

    try {
      await _notificationService.markAllAsRead(
        token: _authToken,
      ); // Using the real fetched token

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _fetchNotifications();
    }
  }

  Future<void> _showNotificationDetail(NotificationModel notif) async {
    if (!notif.isRead) {
      setState(() {
        notif.isRead = true;
      });
      try {
        await _notificationService.markAsRead(
          token: _authToken, // Using the real fetched token
          notificationId: notif.id,
        );
      } catch (e) {
        debugPrint('Failed to mark read on server: $e');
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: const BoxDecoration(
          color: PayFlexColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: PayFlexColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: notif.iconColor.withOpacity(0.12),
                  child: Icon(notif.icon, color: notif.iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif.category.toUpperCase(),
                        style: TextStyle(
                          color: notif.iconColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notif.time,
                        style: const TextStyle(
                          color: PayFlexColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              notif.title,
              style: const TextStyle(
                color: PayFlexColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              notif.body,
              style: const TextStyle(
                color: PayFlexColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: PayFlexColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<NotificationModel> get _filteredNotifications {
    if (_selectedCategory == 'All') return _notifications;
    return _notifications
        .where((item) => item.category == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredNotifications;
    final hasUnread = _notifications.any((item) => !item.isRead);

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
          'Notifications',
          style: TextStyle(
            color: PayFlexColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (hasUnread && !_isLoading)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark as read',
                style: TextStyle(
                  color: PayFlexColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: ['All', 'Transactions', 'Security', 'Promos'].map((
                  cat,
                ) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Text(cat),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : PayFlexColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 12,
                      ),
                      backgroundColor: PayFlexColors.surface,
                      selectedColor: PayFlexColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? PayFlexColors.primary
                              : PayFlexColors.border,
                        ),
                      ),
                      showCheckmark: false,
                      onSelected: (val) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildMainContent(list)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(List<NotificationModel> list) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: PayFlexColors.primary),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: PayFlexColors.textPrimary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                    _initializeTokenAndFetch, // Changed to refetch the token just in case
                style: ElevatedButton.styleFrom(
                  backgroundColor: PayFlexColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (list.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 56,
              color: PayFlexColors.textSecondary,
            ),
            SizedBox(height: 12),
            Text(
              'No notifications here',
              style: TextStyle(
                color: PayFlexColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'You\'re all caught up for now!',
              style: TextStyle(
                color: PayFlexColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      color: PayFlexColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final notif = list[index];
          return _buildNotificationCard(notif);
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notif) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: notif.isRead
            ? PayFlexColors.surface
            : PayFlexColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notif.isRead
              ? PayFlexColors.border
              : PayFlexColors.primary.withOpacity(0.3),
        ),
      ),
      child: ListTile(
        onTap: () => _showNotificationDetail(notif),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: notif.iconColor.withOpacity(0.12),
              child: Icon(notif.icon, color: notif.iconColor, size: 18),
            ),
            if (!notif.isRead)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: PayFlexColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                notif.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: PayFlexColors.textPrimary,
                  fontSize: 14,
                  fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                ),
              ),
            ),
            Text(
              notif.time,
              style: const TextStyle(
                color: PayFlexColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            notif.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PayFlexColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}
