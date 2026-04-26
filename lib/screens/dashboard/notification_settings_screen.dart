import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final User? user;

  const NotificationSettingsScreen({super.key, this.user});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _pushNotifications = true;
  bool _sound = true;
  bool _vibration = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (widget.user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final result = await ApiService.getSettings(widget.user!.id);

    if (result['success'] == true && result['settings'] != null) {
      final settings = result['settings'];
      setState(() {
        _pushNotifications = settings['push_notifications'] ?? true;
        _sound = settings['sound_enabled'] ?? true;
        _vibration = settings['vibration_enabled'] ?? true;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (widget.user == null) return;

    await ApiService.updateSettings(
      userId: widget.user!.id,
      pushNotifications: _pushNotifications,
      soundEnabled: _sound,
      vibrationEnabled: _vibration,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'การตั้งค่าการแจ้งเตือน',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildToggleItem(
                    label: 'การแจ้งเตือนทั่วไป',
                    value: _pushNotifications,
                    onChanged: (val) {
                      setState(() => _pushNotifications = val);
                      _saveSettings();
                    },
                  ),
                  _buildToggleItem(
                    label: 'เสียง',
                    value: _sound,
                    onChanged: (val) {
                      setState(() => _sound = val);
                      _saveSettings();
                    },
                  ),
                  _buildToggleItem(
                    label: 'การสั่น',
                    value: _vibration,
                    onChanged: (val) {
                      setState(() => _vibration = val);
                      _saveSettings();
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildToggleItem({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F0F0)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textDark,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primaryBlue.withValues(alpha: 0.5),
            activeColor: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }
}
