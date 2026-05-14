import 'package:flutter/material.dart';
import '../services/notification_permission_service.dart';
import '../services/notification_listener_service.dart';
import '../services/bank_notification_parser.dart';
import '../services/user_service.dart';
import 'notification_debug_page.dart';
import '../l10n/app_localizations.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _isTrackingEnabled = false;
  bool _canManage = false;
  NotificationTrackingSettings? _settings;
  List<String> _selectedBanks = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final hasPermission = await NotificationPermissionService.hasNotificationPermission();
      final canManage = await NotificationPermissionService.canManageNotificationSettings();
      final isEnabled = await NotificationPermissionService.isNotificationTrackingEnabled();
      final settings = await NotificationPermissionService.getNotificationSettings();

      setState(() {
        _hasPermission = hasPermission;
        _canManage = canManage;
        _isTrackingEnabled = isEnabled;
        _settings = settings;
        _selectedBanks = settings?.enabledBanks ?? BankNotificationParser.getSupportedBanks();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tx('errorLoadingSettings', {'error': e}))),
        );
      }
    }
  }

  Future<void> _requestPermission() async {
    await NotificationPermissionService.requestNotificationPermission();
    // Wait a bit and check permission again
    await Future.delayed(const Duration(seconds: 2));
    await _loadData();
  }

  Future<void> _toggleTracking(bool value) async {
    if (!_canManage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('onlyParentsNotifications'))),
      );
      return;
    }

    try {
      if (value) {
        await NotificationPermissionService.enableNotificationTracking();
      } else {
        await NotificationPermissionService.disableNotificationTracking();
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateBanks(List<String> banks) async {
    if (!_canManage) return;

    try {
      await NotificationPermissionService.updateEnabledBanks(banks);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating banks: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('notificationSettings')),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationDebugPage()),
              );
            },
            tooltip: context.t('debugParser'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildPermissionSection(),
                const SizedBox(height: 24),
                _buildTrackingSection(),
                const SizedBox(height: 24),
                _buildBanksSection(),
                const SizedBox(height: 24),
                _buildInfoSection(),
              ],
            ),
    );
  }

  Widget _buildPermissionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _hasPermission ? Icons.check_circle : Icons.error,
                  color: _hasPermission ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  context.t('notificationPermission'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _hasPermission
                  ? context.t('permissionGranted')
                  : context.t('permissionRequired'),
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (!_hasPermission)
              ElevatedButton.icon(
                onPressed: _requestPermission,
                icon: const Icon(Icons.settings),
                label: Text(context.t('grantPermission')),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('automaticTracking'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _canManage
                  ? context.t('autoImportNotifications')
                  : context.t('parentsOnlySetting'),
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(context.t('enableAutomaticTracking')),
              subtitle: Text(
                _isTrackingEnabled
                    ? context.t('trackingEnabled')
                    : context.t('trackingDisabled'),
              ),
              value: _isTrackingEnabled,
              onChanged: _hasPermission && _canManage ? _toggleTracking : null,
            ),
            if (_settings?.lastSync != null) ...[
              const SizedBox(height: 8),
              Text(
                context.tx('lastSync', {'date': _formatDate(_settings!.lastSync!)}),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBanksSection() {
    final supportedBanks = BankNotificationParser.getSupportedBanks();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  context.t('supportedBanks'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_canManage)
                  TextButton(
                    onPressed: () => _showBankSelectionDialog(supportedBanks),
                    child: Text(context.t('edit')),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _canManage
                  ? context.t('selectBanksDesc')
                  : context.t('contactParentBanks'),
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: supportedBanks.map((bank) {
                final isSelected = _selectedBanks.contains(bank);
                return Chip(
                  label: Text(bank),
                  avatar: isSelected ? const Icon(Icons.check, size: 16) : null,
                  backgroundColor: isSelected ? Colors.green[100] : Colors.grey[200],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('howItWorks'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoStep(
              Icons.notifications_active,
              context.t('grantPermissionStep'),
              context.t('grantPermissionStepDesc'),
            ),
            const SizedBox(height: 12),
            _buildInfoStep(
              Icons.credit_card,
              context.t('bankNotifications'),
              context.t('bankNotificationsDesc'),
            ),
            const SizedBox(height: 12),
            _buildInfoStep(
              Icons.auto_awesome,
              context.t('autoImport'),
              context.t('autoImportDesc'),
            ),
            const SizedBox(height: 12),
            _buildInfoStep(
              Icons.category,
              context.t('smartCategorization'),
              context.t('smartCategorizationDesc'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoStep(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: Theme.of(context).primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                description,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showBankSelectionDialog(List<String> banks) {
    final tempSelected = List<String>.from(_selectedBanks);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.t('selectBanks')),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: banks.length,
              itemBuilder: (context, index) {
                final bank = banks[index];
                return CheckboxListTile(
                  title: Text(bank),
                  value: tempSelected.contains(bank),
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        tempSelected.add(bank);
                      } else {
                        tempSelected.remove(bank);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                _updateBanks(tempSelected);
                Navigator.pop(context);
              },
              child: Text(context.t('save')),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return context.t('justNow');
    } else if (difference.inHours < 1) {
      return context.tx('minutesAgo', {'count': difference.inMinutes});
    } else if (difference.inDays < 1) {
      return context.tx('hoursAgo', {'count': difference.inHours});
    } else if (difference.inDays < 7) {
      return context.tx('daysAgo', {'count': difference.inDays});
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
