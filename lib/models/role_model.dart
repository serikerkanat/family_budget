enum UserRole {
  parent,
  child,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.parent:
        return 'Parent';
      case UserRole.child:
        return 'Child';
    }
  }

  String get value {
    switch (this) {
      case UserRole.parent:
        return 'parent';
      case UserRole.child:
        return 'child';
    }
  }

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'parent':
        return UserRole.parent;
      case 'child':
        return UserRole.child;
      case 'owner':
        return UserRole.parent; // Legacy support
      case 'member':
        return UserRole.child; // Legacy support
      default:
        return UserRole.child;
    }
  }
}
