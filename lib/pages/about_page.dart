import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../l10n/app_localizations.dart';
import '../utils/role_helper.dart';
import '../utils/ui_constants.dart';
import '../constants/app_assets.dart';
import '../widgets/legal_page_scope.dart';
import '../widgets/heartbeat_pulse_dot.dart';

// Über VibesBox Seite mit rollenspezifischen Inhalten
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  bool _isDjOrAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final isAdminUser = isAdmin(user);
      final isDj = await isDJOrLocation(user);
      if (mounted) {
        setState(() {
          _isDjOrAdmin = isAdminUser || isDj;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isDjOrAdmin = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    
    // RTL-Logik für Titel: In RTL steht VibesBox links, das Wort 'Über' rechts
    final appName = l.appName;
    final aboutTitle = isRtl 
        ? '$appName ${l.about_word}'
        : '${l.about_word} $appName';

    // Design-Farben
    const cardColor = Color(0xFF1E1E1E);
    const textColor = Colors.white;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: UIConstants.appOrange));
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Titel (Schwarz/Weiß, gleiche Position wie History)
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
                  Icons.info_outline,
                  size: 32,
                  color: UIConstants.appBarIconColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    aboutTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: UIConstants.appBarForegroundColor,
                        ),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  ),
                ),
                HeartbeatPulseDot(
                  padding: EdgeInsetsDirectional.only(
                    start: isRtl ? 0 : 8,
                    end: isRtl ? 8 : 0,
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
                mainAxisSize: MainAxisSize.min,
                children: [
          // VibesBox Logo prominent oben
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: UIConstants.appOrange,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/icon/vibesbox-logo.png',
                    height: 100,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        AppAssets.placeholder(height: 100),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final info = snapshot.data!;
                      final versionText = 'v${info.version.split('+').first.trim()}';
                      return Text(
                        versionText,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Rollenspezifischer Text mit RTL-Fix
                  Builder(builder: (context) {
                    final aboutText = _isDjOrAdmin
                        ? (l.aboutTextDj)
                        : (l.aboutTextGuest);
                    
                    return Directionality(
                      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                      child: Text(
                        aboutText,
                        style: const TextStyle(
                          color: textColor,
                          fontSize: 16,
                          height: 1.6,
                        ),
                        textAlign: isRtl ? TextAlign.right : TextAlign.center,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Links zu Impressum und DSGVO
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: UIConstants.appOrange,
                width: 1.5,
              ),
            ),
            child: Directionality(
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.description, color: textColor),
                    title: Text(
                      l.imprint,
                      style: const TextStyle(color: textColor),
                    ),
                    trailing: Transform.flip(
                      flipX: isRtl,
                      child: const Icon(Icons.arrow_forward_ios, size: 16, color: textColor),
                    ),
                    onTap: () => LegalPageScope.of(context)?.showImpressum(),
                  ),
                  const Divider(height: 1, color: Colors.grey),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip, color: textColor),
                    title: Text(
                      l.privacyPolicy,
                      style: const TextStyle(color: textColor),
                    ),
                    trailing: Transform.flip(
                      flipX: isRtl,
                      child: const Icon(Icons.arrow_forward_ios, size: 16, color: textColor),
                    ),
                    onTap: () => LegalPageScope.of(context)?.showDsgvo(),
                  ),
                  const Divider(height: 1, color: Colors.grey),
                  ListTile(
                    leading: const Icon(Icons.gavel, color: textColor),
                    title: Text(
                      l.agb,
                      style: const TextStyle(color: textColor),
                    ),
                    trailing: Transform.flip(
                      flipX: isRtl,
                      child: const Icon(Icons.arrow_forward_ios, size: 16, color: textColor),
                    ),
                    onTap: () => LegalPageScope.of(context)?.showAgb(),
                  ),
                ],
              ),
            ),
          ),

          // Footer-Padding am Ende (einheitlich für alle DJ-Seiten)
          const SizedBox(height: UIConstants.kFooterPadding * 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
