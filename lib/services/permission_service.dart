import '../models/role_model.dart';
import 'user_service.dart';

class PermissionService {
  // Check if current user is a parent
  static Future<bool> isParent() async {
    final userData = await UserService.getCurrentUserData();
    if (userData == null) return false;
    
    final role = userData['role'] as String?;
    return role == 'parent' || role == 'owner';
  }

  // Check if current user is a child
  static Future<bool> isChild() async {
    final userData = await UserService.getCurrentUserData();
    if (userData == null) return false;
    
    final role = userData['role'] as String?;
    return role == 'child' || role == 'member';
  }

  // Get current user role
  static Future<UserRole> getCurrentUserRole() async {
    final userData = await UserService.getCurrentUserData();
    if (userData == null) return UserRole.child;
    
    final role = userData['role'] as String?;
    return UserRoleExtension.fromString(role ?? 'child');
  }

  // Permission checks
  static Future<bool> canAddTransactions() async {
    // Both parents and children can add transactions
    return true;
  }

  static Future<bool> canDeleteTransactions() async {
    // Only parents can delete transactions
    return await isParent();
  }

  static Future<bool> canEditTransactions() async {
    // Only parents can edit transactions
    return await isParent();
  }

  static Future<bool> canViewAnalytics() async {
    // Both can view analytics
    return true;
  }

  static Future<bool> canManageFamily() async {
    // Only parents can manage family (add/remove members, change roles)
    return await isParent();
  }

  static Future<bool> canViewAllTransactions() async {
    // Parents can see all, children can see all (family shared)
    return true;
  }

  static Future<bool> canChangeSettings() async {
    // Only parents can change app settings
    return await isParent();
  }

  static Future<bool> canViewForecast() async {
    // Both can view forecast
    return true;
  }

  static Future<bool> canManageCategories() async {
    // Only parents can manage categories
    return await isParent();
  }

  // Stream for current user role
  static Stream<UserRole> get currentUserRoleStream {
    return UserService.currentUserStream.map((userData) {
      if (userData == null) return UserRole.child;
      final role = userData['role'] as String?;
      return UserRoleExtension.fromString(role ?? 'child');
    });
  }
}
