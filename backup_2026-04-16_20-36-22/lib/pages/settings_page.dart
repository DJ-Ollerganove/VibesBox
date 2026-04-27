import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_localizations.dart';
import '../widgets/audio_settings_card.dart';
import '../widgets/custom_page_header.dart';
import '../services/pro_feature_guard.dart';
import '../services/translation_settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showGreetingTranslations = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final enabled = await TranslationSettingsService.isTranslationEnabled();
      if (mounted) {
        setState(() {
          _showGreetingTranslations = enabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(bool value) async {
    try {
      await TranslationSettingsService.setTranslationEnabled(value);
      if (mounted) setState(() => _showGreetingTranslations = value);
    } catch (e) {
      // Fehlerhandling
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(locale);
    final user = FirebaseAuth.instance.currentUser;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(child: CircularProgressIndicator(color: Colors.orange)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomPageHeader(
                icon: Icons.settings,
                title: l.settings_title,
              ),
              const SizedBox(height: 24),
              // Zelle 1: Audio/Mikrofon
              if (user != null)
                FutureBuilder<bool>(
                  future: ProFeatureGuard.canUseMusicRecognition(user: user),
                  builder: (context, snapshot) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange, width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: AudioSettingsCard(
                          canUsePremium: snapshot.data ?? false,
                          cardBuilder: (context, child) => child,
                        ),
                      ),
                    );
                  },
                ),

              // Zelle 2: Translator
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: isRtl
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.translation_settings_title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l.translation_settings_description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        value: _showGreetingTranslations,
                        activeThumbColor: Colors.orange,
                        onChanged: _saveSetting,
                        controlAffinity: isRtl
                            ? ListTileControlAffinity.leading
                            : ListTileControlAffinity.trailing,
                      ),
                    ],
                  ),
                ),
              ),

              // Schwarzer Leerraum am Ende (verhindert Ankleben an Navigation)
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
