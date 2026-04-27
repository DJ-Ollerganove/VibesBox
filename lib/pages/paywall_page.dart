import 'package:flutter/material.dart';

import '../features/subscription/paywall_view.dart';

/// Kanonische Paywall-Seite (RevenueCat). Wird über Route `/paywall` geöffnet.
class PaywallPage extends StatelessWidget {
  const PaywallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PaywallView();
  }
}


