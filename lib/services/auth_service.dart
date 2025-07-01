import 'package:firebase_auth/firebase_auth.dart';
import 'local_storage_service.dart';

class AuthService {
  static Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    await LocalStorageService.clearSession();
  }
}
