import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import '../utils/debug_log.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (e) {
      debugLog('BiometricService: Biometrie-Check Fehler: $e');
      return false;
    }
  }

  Future<bool> authenticateAdmin() async {
    try {
      final biometricAvailable = await isBiometricAvailable();
      if (!biometricAvailable) {
        debugLog(
          'BiometricService: Biometrie nicht verfuegbar',
        );
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: 'Admin-Bestätigung erforderlich',
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Admin-Check',
            signInHint: '',
          ),
          IOSAuthMessages(
            localizedFallbackTitle: '',
          ),
        ],
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugLog('BiometricService: Auth-Fehler: $e');
      return false;
    }
  }
}
