import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/navigation_service.dart';
import '../services/party_session_service.dart';
import '../utils/ui_constants.dart';
import 'wishes_page.dart' show ContactForm, ContactFormState;

class ContactPage extends StatefulWidget {
  final GlobalKey<ContactFormState>? contactFormKey;

  /// Gast-Shell: Index des Kontakt-Tabs im [IndexedStack] – bei Tab-Wechsel hierher
  /// wird das Formular wie beim Drawer zurückgesetzt (keine „Session“-Reste).
  final int? contactTabIndex;

  const ContactPage({super.key, this.contactFormKey, this.contactTabIndex});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  late final GlobalKey<ContactFormState> _formKey;
  late final Future<({bool hasSession, bool isPro})> _sessionFuture;
  VoidCallback? _tabNavListener;
  int _lastNavIndexSeen = -999999;

  @override
  void initState() {
    super.initState();
    _formKey = widget.contactFormKey ?? GlobalKey<ContactFormState>();
    _sessionFuture = _loadSessionAndDjPlan();
    final ct = widget.contactTabIndex;
    if (ct != null) {
      _lastNavIndexSeen = NavigationService().currentTabIndex.value;
      _tabNavListener = () {
        final idx = NavigationService().currentTabIndex.value;
        if (idx == ct && _lastNavIndexSeen != ct) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _formKey.currentState?.resetSuccessMessage();
          });
        }
        _lastNavIndexSeen = idx;
      };
      NavigationService().currentTabIndex.addListener(_tabNavListener!);
    }
  }

  @override
  void dispose() {
    if (_tabNavListener != null) {
      NavigationService().currentTabIndex.removeListener(_tabNavListener!);
    }
    super.dispose();
  }

  /// Liefert Session-Infos für Gast-Kontakt.
  Future<({bool hasSession, bool isPro})> _loadSessionAndDjPlan() async {
    try {
      await PartySessionService.instance.loadFromPrefs();
      final svc = PartySessionService.instance;
      if (!svc.hasSession) {
        return (hasSession: false, isPro: false);
      }
      return (hasSession: true, isPro: svc.isPro);
    } catch (_) {
      return (hasSession: false, isPro: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Überschrift (Schwarz/Weiß, gleiche Position wie History)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: UIConstants.appBarBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.contact_mail,
                    size: 32,
                    color: UIConstants.appBarIconColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localizations.contact,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: UIConstants.appBarForegroundColor,
                          ),
                      textAlign: isRtl ? TextAlign.right : null,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.stretch,
                  children: [
                    FutureBuilder<({bool hasSession, bool isPro})>(
                      future: _sessionFuture,
                      builder: (context, snapshot) {
                        final data = snapshot.data;
                        final hasSession = data?.hasSession == true;
                        final isPro = data?.isPro == true;
                        final isVibesboxSupportMode = !hasSession;
                        final showLockedContact = hasSession && !isPro;

                        return Column(
                          crossAxisAlignment: isRtl
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.stretch,
                          children: [
                            if (isVibesboxSupportMode)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: UIConstants.appOrange,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  localizations.contact_info_vibesbox,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                  textAlign:
                                      isRtl ? TextAlign.right : TextAlign.start,
                                  textDirection: (isRtl ||
                                          RegExp(r'[\u0600-\u06FF]').hasMatch(
                                              localizations.contact_info_vibesbox))
                                      ? TextDirection.rtl
                                      : TextDirection.ltr,
                                ),
                              ),
                            if (showLockedContact)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: UIConstants.colorGreyGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: UIConstants.appOrange,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  localizations.contact_free_mode_info,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.white70),
                                  textAlign:
                                      isRtl ? TextAlign.right : TextAlign.start,
                                ),
                              )
                            else
                              ContactForm(
                                formKey: _formKey,
                                enabled: true,
                                isVibesboxSupportMode: isVibesboxSupportMode,
                              ),
                          ],
                        );
                      },
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
}


