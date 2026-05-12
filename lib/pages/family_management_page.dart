import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/family_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/permission_service.dart';
import '../models/role_model.dart';

class FamilyManagementPage extends StatefulWidget {
  const FamilyManagementPage({super.key});

  @override
  State<FamilyManagementPage> createState() => _FamilyManagementPageState();
}

class _FamilyManagementPageState extends State<FamilyManagementPage> {
  bool _isLoading = false;
  bool _isInFamily = false;
  Map<String, dynamic>? _currentFamily;
  List<Map<String, dynamic>> _familyMembers = [];
  UserRole? _selectedRole;
  
  final _familyNameController = TextEditingController();
  final _joinCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkFamilyStatus();
  }

  @override
  void dispose() {
    _familyNameController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _checkFamilyStatus() async {
    setState(() => _isLoading = true);
    
    try {
      print('=== Checking family status ===');
      
      // Ensure user document exists
      await UserService.createUserDocument();
      
      // Get current user data first
      final currentUserData = await UserService.getCurrentUserData();
      print('Current user data: $currentUserData');
      
      final isInFamily = await FamilyService.isUserInFamily();
      print('User is in family: $isInFamily');
      
      setState(() => _isInFamily = isInFamily);
      
      if (isInFamily) {
        final family = await FamilyService.getCurrentFamily();
        print('Current family: $family');
        setState(() => _currentFamily = family);
        
        if (family != null) {
          // Защита от гонки состояний - проверяем что familyId не null
          final familyId = family['id'];
          if (familyId == null || familyId.toString().isEmpty) {
            print('Остановка: familyId всё еще пустой, ждем обновления...');
            setState(() => _familyMembers = []);
            return;
          }
          
          print('Getting family members for family ID: $familyId');
          final members = await FamilyService.getFamilyMembers(familyId);
          print('Family members retrieved: $members');
          print('Number of members: ${members.length}');
          
          setState(() => _familyMembers = members);
          
          // Debug each member
          for (final member in members) {
            print('Member: ${member['id']} - ${member['email'] ?? 'No email'} - Role: ${member['role'] ?? 'No role'}');
          }
        } else {
          print('Family is null, cannot get members');
          setState(() => _familyMembers = []);
        }
      } else {
        print('User is not in any family');
        setState(() {
          _currentFamily = null;
          _familyMembers = [];
        });
      }
    } catch (e) {
      print('Error checking family status: $e');
      _showErrorSnackBar('Error checking family status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createFamily() async {
    if (_familyNameController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a family name');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      print('Creating family with name: ${_familyNameController.text.trim()}');
      final familyCode = await FamilyService.createFamily(_familyNameController.text.trim());
      print('Family created with code: $familyCode');
      
      _showSuccessSnackBar(
        'Family created successfully!\nYour family code: $familyCode\nShare this code with family members.'
      );
      
      _familyNameController.clear();
      
      // Даем время на обновление данных в Firebase
      await Future.delayed(const Duration(milliseconds: 500));
      await _checkFamilyStatus();
    } catch (e) {
      print('Error creating family: $e');
      _showErrorSnackBar('Error creating family: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinFamily() async {
    if (_joinCodeController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a family code');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final success = await FamilyService.joinFamily(
        _joinCodeController.text.trim(),
        role: _selectedRole ?? UserRole.child,
      );
      
      if (success) {
        _showSuccessSnackBar('Joined family successfully!');
        _joinCodeController.clear();
        
        // Даем время на обновление данных в Firebase
        await Future.delayed(const Duration(milliseconds: 500));
        await _checkFamilyStatus();
      } else {
        _showErrorSnackBar('Invalid family code or family not found');
      }
    } catch (e) {
      print('Error joining family: $e');
      _showErrorSnackBar('Error joining family: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  
  Future<void> _copyFamilyCode() async {
    final code = _currentFamily?['code'] ?? '';
    if (code.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: code));
      _showSuccessSnackBar('Family code copied to clipboard!');
    }
  }

  Future<void> _changeMemberRole(String userId, String currentRole) async {
    final newRole = currentRole == 'parent' ? UserRole.child : UserRole.parent;
    
    try {
      await FamilyService.updateMemberRole(userId, newRole);
      _showSuccessSnackBar('Role updated successfully');
      await _checkFamilyStatus();
    } catch (e) {
      print('Error updating role: $e');
      _showErrorSnackBar('Only parents can change member roles');
    }
  }

  Future<void> _removeMember(String userId, String memberEmail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove $memberEmail from the family?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FamilyService.removeMember(userId);
        _showSuccessSnackBar('Member removed successfully');
        await _checkFamilyStatus();
      } catch (e) {
        print('Error removing member: $e');
        _showErrorSnackBar('Only parents can remove members');
      }
    }
  }

  void _showCreateFamilyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Family'),
        content: TextField(
          controller: _familyNameController,
          decoration: const InputDecoration(
            labelText: 'Family Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createFamily();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinFamilyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Family'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _joinCodeController,
              decoration: const InputDecoration(
                labelText: 'Family Code',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<UserRole>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Your Role',
                border: OutlineInputBorder(),
              ),
              items: UserRole.values.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role.toString().split('.').last),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRole = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _joinFamily();
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Management'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _checkFamilyStatus,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _isLoading ? null : () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Leave Family'),
                  content: const Text('Are you sure you want to leave this family?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Leave'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                setState(() => _isLoading = true);
                
                try {
                  await FamilyService.leaveFamily();
                  _showSuccessSnackBar('You have left the family');
                  await _checkFamilyStatus();
                } catch (e) {
                  print('Error leaving family: $e');
                  _showErrorSnackBar('Error leaving family: $e');
                } finally {
                  setState(() => _isLoading = false);
                }
              }
            },
            tooltip: 'Leave Family',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isInFamily
              ? _buildInFamilyView()
              : _buildNotInFamilyView(),
    );
  }

  Widget _buildNotInFamilyView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.family_restroom, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'You are not in a family',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a new family or join an existing one',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _showCreateFamilyDialog(),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create Family'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _showJoinFamilyDialog(),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Join Family'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInFamilyView() {
    if (_currentFamily == null) {
      return const Center(child: Text('Error loading family data'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Family Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Family Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      IconButton(
                        onPressed: _copyFamilyCode,
                        icon: const Icon(Icons.copy),
                        tooltip: 'Copy Family Code',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      _currentFamily!['code'] ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Share this code with family members to invite them.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Debug info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Debug Info:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                Text('Family ID: ${_currentFamily?['id'] ?? 'None'}'),
                Text('Members count: ${_familyMembers.length}'),
                if (_familyMembers.isNotEmpty)
                  Text('First member: ${_familyMembers.first['email'] ?? 'No email'}'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Family Members Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Family Members',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_familyMembers.isEmpty)
                    const Text('No members found')
                  else
                    FutureBuilder<bool>(
                      future: PermissionService.canManageFamily(),
                      builder: (context, snapshot) {
                        final canManage = snapshot.data ?? false;
                        
                        return Column(
                          children: _familyMembers.map((member) {
                            final isCurrentUser = member['id'] == FirebaseAuth.instance.currentUser?.uid;
                            final role = member['role'] as String? ?? 'child';
                            final isParent = role == 'parent' || role == 'owner';
                            
                            return ListTile(
                              leading: CircleAvatar(
                                child: Icon(isParent ? Icons.admin_panel_settings : Icons.person),
                                backgroundColor: isParent ? Colors.amber[100] : Colors.grey[200],
                              ),
                              title: Text(member['email'] ?? member['displayName'] ?? 'Unknown'),
                              subtitle: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isParent 
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isParent ? 'Parent' : 'Child',
                                      style: TextStyle(
                                        color: isParent ? Colors.green : Colors.blue,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (isCurrentUser) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.star, size: 14, color: Colors.amber),
                                  ],
                                ],
                              ),
                              trailing: canManage && !isCurrentUser
                                  ? PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (value) async {
                                        if (value == 'change_role') {
                                          await _changeMemberRole(member['id'], role ?? '');
                                        } else if (value == 'remove') {
                                          await _removeMember(member['id'], member['email'] ?? 'Unknown');
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'change_role',
                                          child: Row(
                                            children: [
                                              Icon(Icons.swap_horiz),
                                              SizedBox(width: 8),
                                              Text('Change Role'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'remove',
                                          child: Row(
                                            children: [
                                              Icon(Icons.person_remove, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Remove', style: TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : isCurrentUser
                                    ? const Icon(Icons.star, color: Colors.amber)
                                    : null,
                            );
                          }).toList(),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
