import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:translator/translator.dart';
import '../../services/announcement_languages_service.dart';
import '../../helpers/security_helper.dart';

/// Mappt App-Sprachcode auf Google-Translate-Code (z. B. zh -> zh-cn).
String _toGoogleTranslateCode(String code) {
  final c = code.toLowerCase();
  if (c == 'zh') return 'zh-cn';
  return c;
}

/// Admin-Karte: Globale Ankündigung (Betreff + Nachricht) in alle aktiven Sprachen übersetzen und in global_announcements speichern.
/// Optional: Bearbeitungsmodus mit [editAnnouncementId] und [initialSubject]/[initialMessage]; beim Speichern wird [updatedAt] gesetzt.
class GlobalAnnouncementCard extends StatefulWidget {
  final Widget Function(BuildContext context, Widget child) cardBuilder;

  /// Wenn gesetzt: Bearbeitungsmodus; Karte wird mit [initialSubject]/[initialMessage] gefüllt, Speichern aktualisiert das Dokument.
  final String? editAnnouncementId;
  final String? initialSubject;
  final String? initialMessage;

  /// Callback nach erfolgreichem Speichern im Bearbeitungsmodus (z. B. um Edit-State zu löschen).
  final VoidCallback? onEditFinished;

  const GlobalAnnouncementCard({
    super.key,
    required this.cardBuilder,
    this.editAnnouncementId,
    this.initialSubject,
    this.initialMessage,
    this.onEditFinished,
  });

  @override
  State<GlobalAnnouncementCard> createState() => _GlobalAnnouncementCardState();
}

class _GlobalAnnouncementCardState extends State<GlobalAnnouncementCard> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final GoogleTranslator _translator = GoogleTranslator();
  bool _sending = false;
  String _progress = '';
  int _progressCurrent = 0;
  int _progressTotal = 0;

  @override
  void initState() {
    super.initState();
    _applyInitialValuesIfEdit();
  }

  @override
  void didUpdateWidget(covariant GlobalAnnouncementCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editAnnouncementId != widget.editAnnouncementId ||
        oldWidget.initialSubject != widget.initialSubject ||
        oldWidget.initialMessage != widget.initialMessage) {
      _applyInitialValuesIfEdit();
    }
  }

  void _applyInitialValuesIfEdit() {
    if (widget.editAnnouncementId == null) return;
    _subjectController.text = widget.initialSubject ?? '';
    _messageController.text = widget.initialMessage ?? '';
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final subject = SecurityHelper.sanitize(
      _subjectController.text.trim(),
      maxLength: 120,
    );
    final message = SecurityHelper.sanitize(
      _messageController.text.trim(),
      maxLength: 500,
    );
    if (subject.isEmpty && message.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte Betreff oder Nachricht eingeben.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _sending = true;
      _progress = 'Lade Sprachen…';
      _progressCurrent = 0;
      _progressTotal = 0;
    });

    try {
      final languages = await AnnouncementLanguagesService.getActiveLanguages(
        ensureExists: true,
      );
      if (!mounted) return;
      if (languages.isEmpty) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine aktiven Sprachen in settings/languages.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final total = languages.length * 2;
      int done = 0;
      final translations = <String, Map<String, String>>{};

      for (final lang in languages) {
        final code = lang.code;
        if (code == 'de') {
          translations['de'] = {'subject': subject, 'message': message};
          done += 2;
          if (mounted)
            setState(() {
              _progressTotal = total;
              _progressCurrent = done;
              _progress = 'Deutsch (Original)';
            });
          continue;
        }

        final toCode = _toGoogleTranslateCode(code);
        try {
          if (mounted)
            setState(() {
              _progressTotal = total;
              _progressCurrent = done;
              _progress = 'Übersetze nach $code…';
            });

          String? subjectTr = subject.isEmpty ? '' : null;
          String? messageTr = message.isEmpty ? '' : null;

          if (subject.isNotEmpty) {
            final res = await _translator.translate(
              subject,
              from: 'de',
              to: toCode,
            );
            subjectTr = res.text;
            done++;
            if (mounted)
              setState(() {
                _progressCurrent = done;
                _progress = 'Übersetze nach $code… (Betreff)';
              });
          }
          if (message.isNotEmpty) {
            final res = await _translator.translate(
              message,
              from: 'de',
              to: toCode,
            );
            messageTr = res.text;
            done++;
            if (mounted)
              setState(() {
                _progressCurrent = done;
                _progress = 'Übersetze nach $code…';
              });
          }

          translations[code] = {
            'subject': subjectTr ?? '',
            'message': messageTr ?? '',
          };
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Übersetzung für $code fehlgeschlagen: $e'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          translations[code] = {'subject': subject, 'message': message};
          done += 2;
        }
      }

      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _sending = false);
        return;
      }

      setState(() {
        _progress = 'Speichere in global_announcements…';
      });

      final isEdit =
          widget.editAnnouncementId != null &&
          widget.editAnnouncementId!.isNotEmpty;
      if (isEdit) {
        await FirebaseFirestore.instance
            .collection('global_announcements')
            .doc(widget.editAnnouncementId)
            .update(
              SecurityHelper.sanitizeMap({
                'translations': translations,
                'updatedAt': FieldValue.serverTimestamp(),
              }),
            );
      } else {
        await FirebaseFirestore.instance
            .collection('global_announcements')
            .add(
              SecurityHelper.sanitizeMap({
                'translations': translations,
                'createdAt': FieldValue.serverTimestamp(),
                'createdBy': user.uid,
              }),
            );
      }

      if (!mounted) return;
      setState(() {
        _sending = false;
        _progress = '';
        _subjectController.clear();
        _messageController.clear();
      });
      if (isEdit) {
        widget.onEditFinished?.call();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit ? 'Ankündigung aktualisiert.' : 'Ankündigung gespeichert.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.cardBuilder(
      context,
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.orange, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1F2937),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  widget.editAnnouncementId != null
                      ? 'Ankündigung bearbeiten'
                      : 'Globale Ankündigung',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Betreff',
                hintText: 'Deutscher Ausgangstext',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange),
                ),
                labelStyle: TextStyle(color: Colors.white70),
                hintStyle: TextStyle(color: Colors.white38),
              ),
              style: const TextStyle(color: Colors.white),
              enabled: !_sending,
              onChanged: (value) {
                final safe = SecurityHelper.sanitize(value, maxLength: 120);
                if (safe != value) {
                  _subjectController.value = _subjectController.value.copyWith(
                    text: safe,
                    selection: TextSelection.collapsed(offset: safe.length),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Nachricht',
                hintText: 'Deutscher Ausgangstext',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange),
                ),
                labelStyle: TextStyle(color: Colors.white70),
                hintStyle: TextStyle(color: Colors.white38),
              ),
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              enabled: !_sending,
              onChanged: (value) {
                final safe = SecurityHelper.sanitize(value, maxLength: 500);
                if (safe != value) {
                  _messageController.value = _messageController.value.copyWith(
                    text: safe,
                    selection: TextSelection.collapsed(offset: safe.length),
                  );
                }
              },
            ),
            if (_sending) ...[
              const SizedBox(height: 12),
              Text(
                _progress,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (_progressTotal > 0) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: _progressCurrent / _progressTotal,
                  backgroundColor: Colors.grey.shade700,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.orange,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.send, size: 18),
              label: Text(
                _sending
                    ? 'Senden…'
                    : (widget.editAnnouncementId != null
                          ? 'Aktualisieren'
                          : 'Senden'),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.orange),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
