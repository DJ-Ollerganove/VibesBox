import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha_action.dart';

import 'app_check_service.dart';

/// Token für Firebase Callable [sendAuthEmail] — Action muss mit RECAPTCHA_CONTACT_ACTION ('submit') im Backend übereinstimmen.
class RecaptchaEnterpriseActionService {
  RecaptchaEnterpriseActionService._();

  static Future<String> getSubmitActionToken() async {
    if (kIsWeb || !Platform.isAndroid && !Platform.isIOS) {
      throw StateError(
        'reCAPTCHA Enterprise (Auth-Mail): nur Android/iOS werden unterstützt.',
      );
    }
    final client = await Recaptcha.fetchClient(
      AppCheckService.recaptchaEnterpriseSiteKey,
    );
    final token = await client.execute(
      RecaptchaAction.custom('submit'),
      timeout: 15,
    );
    final t = token.trim();
    if (t.isEmpty) {
      throw StateError('reCAPTCHA Enterprise: leeres Token.');
    }
    return t;
  }
}
