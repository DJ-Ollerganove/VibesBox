import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class LoginCounterCard extends StatelessWidget {
  final int loginCount;
  final Widget Function(BuildContext context, Widget child) cardBuilder;

  const LoginCounterCard({
    super.key,
    required this.loginCount,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return cardBuilder(
      context,
      Row(
        children: [
          Icon(Icons.login, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.login_count_message(loginCount),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}


