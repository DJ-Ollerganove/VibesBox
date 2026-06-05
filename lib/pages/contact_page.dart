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
  late final Future<({bool hasSession, bool isPro, String? djName})> _sessionFuture;
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

  /// Liefert Session-Infos für Gast-Kontakt (inkl. DJ-Name für Hinweistext bei Pro-Party).
  Future<({bool hasSession, bool isPro, String? djName})> _loadSessionAndDjPlan() async {
    try {
      await PartySessionService.instance.loadFromPrefs();
      final svc = PartySessionService.instance;
      if (!svc.hasSession) {
        return (hasSession: false, isPro: false, djName: null);
      }
      final rawName = svc.djName?.trim();
      final djName = (rawName != null && rawName.isNotEmpty) ? rawName : null;
      return (hasSession: true, isPro: svc.isPro, djName: djName);
    } catch (_) {
      return (hasSession: false, isPro: false, djName: null);
    }
  }

  List<InlineSpan> _djRecipientHintSpans(
    String template,
    String djName,
    TextStyle base,
    TextStyle nameStyle,
  ) {
    if (!template.contains('{djName}')) {
      return [TextSpan(text: template, style: base)];
    }
    final parts = template.split('{djName}');
    final out = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        out.add(TextSpan(text: parts[i], style: base));
      }
      if (i < parts.length - 1) {
        out.add(TextSpan(text: djName, style: nameStyle));
      }
    }
    return out;
  }

  Widget _buildDjRecipientHint(
    BuildContext context,
    AppLocalizations l,
    String djName,
    bool isRtl,
  ) {
    final template = l.contactDjRecipientHintTemplate;
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          height: 1.45,
          color: const Color(0xFFE5F0FF).withValues(alpha: 0.95),
        ) ??
        const TextStyle(
          fontSize: 13,
          height: 1.45,
          color: Color(0xFFE5F0FF),
        );
    final nameStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E325A).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF93C5FF).withValues(alpha: 0.25),
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: _djRecipientHintSpans(template, djName, baseStyle, nameStyle),
        ),
        textAlign: isRtl ? TextAlign.right : TextAlign.start,
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      ),
    );
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
                    FutureBuilder<({bool hasSession, bool isPro, String? djName})>(
                      future: _sessionFuture,
                      builder: (context, snapshot) {
                        final data = snapshot.data;
                        final hasSession = data?.hasSession == true;
                        final isPro = data?.isPro == true;
                        final djName = data?.djName;
                        final isVibesboxSupportMode = !hasSession;
                        final showLockedContact = hasSession && !isPro;
                        final showDjRecipientHint =
                            hasSession && isPro && (djName != null && djName.isNotEmpty);

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
                            else ...[
                              if (showDjRecipientHint)
                                _buildDjRecipientHint(
                                  context,
                                  localizations,
                                  djName,
                                  isRtl,
                                ),
                              ContactForm(
                                formKey: _formKey,
                                enabled: true,
                                isVibesboxSupportMode: isVibesboxSupportMode,
                              ),
                            ],
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


