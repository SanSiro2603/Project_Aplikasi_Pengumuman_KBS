import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAccess {
  static bool isAdmin() {
    final user = Supabase.instance.client.auth.currentUser;
    final appRole = user?.appMetadata['role']?.toString().toLowerCase();
    final userRole = user?.userMetadata?['role']?.toString().toLowerCase();
    return appRole == 'admin' || userRole == 'admin';
  }
}
