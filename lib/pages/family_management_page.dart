import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/family_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

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
      print('Checking family status...');
      
      // Ensure user document exists
      await UserService.createUserDocument();
      
      final isInFamily = await FamilyService.isUserInFamily();
      print('User is in family: $isInFamily');
      
      setState(() => _isInFamily = isInFamily);
      
      if (isInFamily) {
        final family = await FamilyService.getCurrentFamily();
        print('Current family: $family');
        setState(() => _currentFamily = family);
        
        if (family != null) {
          final members = await FamilyService.getFamilyMembers(family['id']);
          print('Family members: $members');
          setState(() => _familyMembers = members);
        }
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
      final success = await FamilyService.joinFamily(_joinCodeController.text.trim());
      
      if (success) {
        _showSuccessSnackBar('Successfully joined the family!');
        _joinCodeController.clear();
        await _checkFamilyStatus();
      } else {
        _showErrorSnackBar('Invalid family code. Please check and try again.');
      }
    } catch (e) {
      _showErrorSnackBar('Error joining family: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveFamily() async {
    final confirmed = await _showConfirmDialog(
      'Leave Family',
      'Are you sure you want to leave this family? You will lose access to all shared data.',
    );
    
    if (!confirmed) return;

    setState(() => _isLoading = true);
    
    try {
      await FamilyService.leaveFamily();
      _showSuccessSnackBar('You have left the family');
      await _checkFamilyStatus();
    } catch (e) {
      _showErrorSnackBar('Error leaving family: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _copyFamilyCode() async {
    final code = _currentFamily?['code'];
    if (code == null) return;

    await Clipboard.setData(ClipboardData(text: code));
    _showSuccessSnackBar('Family code copied to clipboard!');
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

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
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
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _currentFamily == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isInFamily) {
      return _buildNotInFamilyView();
    }

    return _buildInFamilyView();
  }

  Widget _buildNotInFamilyView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Family'),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Create Family Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create New Family',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _familyNameController,
                      decoration: const InputDecoration(
                        labelText: 'Family Name',
                        hintText: 'e.g. Smith Family',
                        prefixIcon: Icon(Icons.family_restroom),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createFamily,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Create Family'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Join Family Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Join Existing Family',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _joinCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Family Code',
                        hintText: 'e.g. ABC-123-XYZ',
                        prefixIcon: Icon(Icons.code),
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _joinFamily,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Join Family'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInFamilyView() {
    if (_currentFamily == null) {
      return const Scaffold(
        body: Center(child: Text('Error loading family data')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentFamily!['name'] ?? 'My Family'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _isLoading ? null : _leaveFamily,
            tooltip: 'Leave Family',
          ),
        ],
      ),
      body: Padding(
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
                      ..._familyMembers.map((member) => ListTile(
                        leading: CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(member['email'] ?? 'Unknown'),
                        subtitle: Text(
                          member['role'] == 'owner' ? 'Family Owner' : 'Family Member',
                          style: TextStyle(
                            color: member['role'] == 'owner' 
                                ? Colors.green 
                                : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: member['id'] == FirebaseAuth.instance.currentUser?.uid
                            ? const Icon(Icons.star, color: Colors.amber)
                            : null,
                      )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
