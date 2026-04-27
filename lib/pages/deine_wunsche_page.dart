import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../helpers/security_helper.dart';
import '../services/party_session_service.dart';
import '../utils/string_utils.dart';
import '../utils/ui_constants.dart';

// Hilfsfunktion zum Anzeigen von Firebase-Fehlern mit klickbaren Links
Widget buildFirebaseErrorWidget(Object error) {
  final errorString = error.toString();

  // Suche nach Firebase-Console-Links (verschiedene Patterns)
  String? url;

  // Pattern 1: Standard Firebase Console Link
  final urlRegex1 = RegExp(
    r'https://console\.firebase\.google\.com/[^\s\)\]]+',
  );
  final match1 = urlRegex1.firstMatch(errorString);
  if (match1 != null) {
    url = match1.group(0);
  }

  // Pattern 2: Falls URL in Anführungszeichen steht
  if (url == null) {
    final urlRegex2 = RegExp(
      r'https://console\.firebase\.google\.com/[^\s\)\]]+',
    );
    final match2 = urlRegex2.firstMatch(errorString);
    if (match2 != null) {
      url = match2.group(0);
    }
  }

  // Pattern 3: Suche nach "https://" und nimm alles bis zum nächsten Leerzeichen oder Zeilenende
  if (url == null) {
    final urlRegex3 = RegExp(
      r'https://console\.firebase\.google\.com/[^\s\n]+',
    );
    final match3 = urlRegex3.firstMatch(errorString);
    if (match3 != null) {
      url = match3.group(0);
    }
  }

  if (url != null) {
    // Bereinige die URL (entferne mögliche abschließende Zeichen)
    final cleanUrl = url.replaceAll(RegExp(r'[\)\]\},;]+$'), '');

    return Builder(
      builder: (context) {
        final l = AppLocalizations.of(context)!;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.orange, size: 48),
                const SizedBox(height: 16),
                Text(
                  l.firebase_index_required_title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l.firebase_index_instruction,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: SelectableText(
                    cleanUrl,
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: cleanUrl));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l.url_copied_to_clipboard_snackbar),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: Text(l.url_copy),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final uri = Uri.parse(cleanUrl);
                      final launched = await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                      if (!launched && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l.url_launch_failed_snackbar),
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l.url_open_error_with_detail_snackbar('$e'),
                            ),
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l.open_in_browser),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l.firebase_index_browser_tip,
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Fallback: Normale Fehlermeldung mit vollständigem Text
  return Builder(
    builder: (context) {
      final l = AppLocalizations.of(context)!;
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                l.error_occurred_generic,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                errorString,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Deine Wünsche-Seite
class DeineWunschePage extends StatefulWidget {
  const DeineWunschePage({super.key});

  @override
  State<DeineWunschePage> createState() => _DeineWunschePageState();
}

class _DeineWunschePageState extends State<DeineWunschePage> {
  String? _partyId;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await PartySessionService.instance.loadFromPrefs();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      if (!mounted) return;
      setState(() {
        _partyId = PartySessionService.instance.partyId;
        _loaded = true;
      });
    } else {
      if (mounted) setState(() => _loaded = true);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized == 'played') return UIConstants.appGreen;
    if (normalized == 'rejected' || normalized == 'declined') {
      return UIConstants.appOrange;
    }
    return UIConstants.frameOffen;
  }

  String _statusText(BuildContext context, String status) {
    final l = AppLocalizations.of(context)!;
    final normalized = status.toLowerCase();
    if (normalized == 'played') return l.played;
    if (normalized == 'rejected' || normalized == 'declined') {
      return l.rejected;
    }
    return l.open;
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    final color = _statusColor(status);
    final text = _statusText(context, status);
    final normalized = status.toLowerCase();
    final icon = normalized == 'played'
        ? Icons.check_circle
        : (normalized == 'rejected' || normalized == 'declined')
        ? Icons.cancel
        : Icons.pending;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDeleteWish(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: UIConstants.colorGreyGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UIConstants.appOrange, width: 2),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.delete,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l.confirm_delete_permanently,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        foregroundColor: UIConstants.appOrange,
                      ),
                      child: Text(l.cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: UIConstants.appOrange,
                        foregroundColor: Colors.black,
                      ),
                      child: Text(l.delete),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result == true;
  }

  Future<void> _openEditWishDialog({
    required BuildContext context,
    required DocumentReference<Map<String, dynamic>> wishRef,
    required String initialGreeting,
  }) async {
    final l = AppLocalizations.of(context)!;
    final greetingController = TextEditingController(text: initialGreeting);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: UIConstants.colorGreyGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UIConstants.appOrange, width: 2),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.edit,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: greetingController,
                  onChanged: (value) {
                    final safe = SecurityHelper.sanitize(
                      value,
                      maxLength: 160,
                      trimInput: false,
                    );
                    if (safe != value) {
                      greetingController.value = greetingController.value
                          .copyWith(
                            text: safe,
                            selection: TextSelection.collapsed(
                              offset: safe.length,
                            ),
                          );
                    }
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: l.wish_greeting_label,
                    counterStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    labelStyle: const TextStyle(color: UIConstants.appOrange),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: UIConstants.appOrange,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: UIConstants.appOrange,
                        width: 2,
                      ),
                    ),
                  ),
                  maxLength: 160,
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: UIConstants.appOrange,
                      ),
                      child: Text(l.cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        final greeting = SecurityHelper.sanitize(
                          greetingController.text.trim(),
                          maxLength: 160,
                        );
                        Navigator.of(ctx).pop();
                        wishRef
                            .update(
                              SecurityHelper.sanitizeMap({
                                'greeting': greeting,
                                'updated_at': FieldValue.serverTimestamp(),
                              }),
                            )
                            .catchError((_) {});
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: UIConstants.appOrange,
                        foregroundColor: Colors.black,
                      ),
                      child: Text(l.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      greetingController.dispose();
    });
  }

  /// Kein rotes Error-Widget bei permission-denied (Regeln / Übergangsfälle).
  Widget _buildGuestWishesStreamError(BuildContext context, Object error) {
    final l = AppLocalizations.of(context)!;
    final isPermissionDenied =
        (error is FirebaseException &&
            (error.code == 'permission-denied' ||
                error.code == 'PERMISSION_DENIED')) ||
        error.toString().toLowerCase().contains('permission-denied');
    if (isPermissionDenied) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: Colors.amber.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              l.guestWishesPermissionHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }
    return buildFirebaseErrorWidget(error);
  }

  String _extractGreeting(Map<String, dynamic> data) {
    String _fromDynamic(dynamic value) {
      if (value == null) return '';
      if (value is String) {
        final s = value.trim();
        if (s.isEmpty || s.toLowerCase() == 'null') return '';
        // Bereinige Fälle wie "{greeting: Hallo}" aus toString()-Darstellungen.
        final mapLike = RegExp(r'^\{.*\}$');
        if (mapLike.hasMatch(s) && s.contains('greeting')) {
          final m = RegExp(r'greeting\s*:\s*([^,}]+)').firstMatch(s);
          if (m != null) return unescapeHtml(m.group(1)?.trim() ?? '');
        }
        return unescapeHtml(s);
      }
      if (value is Map) {
        return _fromDynamic(
          value['greeting'] ?? value['message'] ?? value['text'],
        );
      }
      if (value is List) {
        for (final e in value) {
          final candidate = _fromDynamic(e);
          if (candidate.isNotEmpty) return candidate;
        }
      }
      return '';
    }

    final direct = _fromDynamic(
      data['greeting'] ?? data['message'] ?? data['wish_greeting'],
    );
    if (direct.isNotEmpty) return direct;
    return _fromDynamic(data['greetings']);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.please_log_in,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.your_wishes_login_required_body,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_loaded) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    // Firestore-Regeln verlangen party_id in der Query – ohne Party keine Wunsch-Liste
    final partyId = _partyId;
    if (partyId == null || partyId.isEmpty || partyId == 'manual') {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DeineWuenscheHeader(
                  title: l10n.yourWishes,
                ),
                const SizedBox(height: 32),
                Icon(Icons.celebration, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  l10n.history_no_party_info,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DeineWuenscheHeader(
                title: l10n.yourWishes,
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  // Nur party_id + user_id: Firestore-Regeln erlauben Lesen nur für eigene
                  // Dokumente (isWishOwnerByData). party_id + name liefert ggf. fremde
                  // Einträge gleichen Namens → gesamte Query permission-denied.
                  stream: FirebaseFirestore.instance
                      .collection('wishes')
                      .where('party_id', isEqualTo: partyId)
                      .where('user_id', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _buildGuestWishesStreamError(
                        context,
                        snapshot.error!,
                      );
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(l10n.no_wishes_yet),
                      );
                    }
                    // Filtere Duplikate heraus - zeige nur Original-Wünsche
                    final originalDocs = docs.where((doc) {
                      final data = doc.data();
                      return data['is_duplicate'] != true;
                    }).toList();

                    if (originalDocs.isEmpty) {
                      return Center(
                        child: Text(l10n.no_open_wishes),
                      );
                    }

                    // Sortiere clientseitig nach createdAt (älteste zuerst)
                    final sortedDocs = originalDocs.toList()
                      ..sort((a, b) {
                        final tsA = a.data()['createdAt'];
                        final tsB = b.data()['createdAt'];
                        final dateA = tsA is Timestamp
                            ? tsA.toDate()
                            : DateTime.fromMillisecondsSinceEpoch(0);
                        final dateB = tsB is Timestamp
                            ? tsB.toDate()
                            : DateTime.fromMillisecondsSinceEpoch(0);
                        return dateB.compareTo(dateA); // Neueste zuerst
                      });
                    return ListView.separated(
                      shrinkWrap: false,
                      physics: const ClampingScrollPhysics(),
                      itemCount: sortedDocs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final doc = sortedDocs[index];
                        final data = doc.data();
                        // Rückwärtskompatibilität: alte Wünsche haben 'song' statt 'title'
                        final title = unescapeHtml(
                          (data['title'] ?? data['song'] ?? '').toString(),
                        );
                        final artist = unescapeHtml(
                          (data['artist'] ?? '').toString(),
                        );
                        final greeting = _extractGreeting(data);
                        final status = (data['status'] ?? 'pending') as String;
                        final ts = data['createdAt'];
                        final created = ts is Timestamp
                            ? ts.toDate()
                            : DateTime.fromMillisecondsSinceEpoch(0);

                        // Titel/Interpret anzeigen
                        String displayText = '';
                        if (title.isNotEmpty && artist.isNotEmpty) {
                          displayText = '$title - $artist';
                        } else if (title.isNotEmpty) {
                          displayText = title;
                        } else if (artist.isNotEmpty) {
                          displayText = artist;
                        }

                        // Nummerierung: sortedDocs.length - index (neueste = 1)
                        final number = sortedDocs.length - index;

                        return _GuestWishCardCell(
                          number: number,
                          displayText: displayText,
                          createdText: _formatDate(created),
                          greeting: greeting,
                          status: status,
                          borderColor: _statusColor(status),
                          statusBadge: _buildStatusBadge(context, status),
                          onDelete: () async {
                            final shouldDelete = await _confirmDeleteWish(
                              context,
                            );
                            if (!shouldDelete) return;
                            try {
                              await doc.reference.delete();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.wish_deleted,
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${l10n.error_deleting}: $e',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          onEdit: () => _openEditWishDialog(
                            context: context,
                            wishRef: doc.reference,
                            initialGreeting: greeting,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestWishCardCell extends StatelessWidget {
  const _GuestWishCardCell({
    required this.number,
    required this.displayText,
    required this.createdText,
    required this.greeting,
    required this.status,
    required this.borderColor,
    required this.statusBadge,
    this.onEdit,
    this.onDelete,
  });

  final int number;
  final String displayText;
  final String createdText;
  final String greeting;
  final String status;
  final Color borderColor;
  final Widget statusBadge;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final isOpen = normalized == 'pending';
    final showDelete = isOpen;
    final showEdit = isOpen && greeting.trim().isNotEmpty;
    final titleColor = isOpen ? Colors.white : Colors.white70;
    final secondaryTextColor = isOpen
        ? Colors.white.withValues(alpha: 0.78)
        : Colors.white70;
    final greetingColor = isOpen ? Colors.white : Colors.white70;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: UIConstants.colorGreyGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2.5),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.amber.shade800.withValues(alpha: 0.22),
            highlightColor: Colors.amber.shade900.withValues(alpha: 0.18),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8, top: 2),
                        child: Text(
                          '$number.',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          displayText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    createdText,
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  if (greeting.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: UIConstants.frameOffen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: UIConstants.frameOffen.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.favorite,
                            size: 16,
                            color: UIConstants.frameOffen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              greeting,
                              style: TextStyle(
                                fontSize: 13,
                                color: greetingColor,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(
                        fit: FlexFit.tight,
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: statusBadge,
                        ),
                      ),
                      if (showDelete) ...[
                        const SizedBox(width: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showEdit)
                              IconButton(
                                onPressed: onEdit,
                                iconSize: 18,
                                splashRadius: 18,
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                tooltip: AppLocalizations.of(context)!.edit,
                                style: IconButton.styleFrom(
                                  foregroundColor: UIConstants.appOrange,
                                ),
                                icon: const Icon(Icons.edit),
                              ),
                            IconButton(
                              onPressed: onDelete,
                              iconSize: 18,
                              splashRadius: 18,
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              tooltip: AppLocalizations.of(context)!.delete,
                              style: IconButton.styleFrom(
                                foregroundColor: UIConstants.appRed,
                              ),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Einheitlicher Seitenheader – identisches Styling zu Kontakt / Social Media / Über.
class _DeineWuenscheHeader extends StatelessWidget {
  const _DeineWuenscheHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: UIConstants.appBarBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Icon(Icons.music_note, size: 32, color: UIConstants.appBarIconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: UIConstants.appBarForegroundColor,
              ),
              textAlign: isRtl ? TextAlign.right : null,
            ),
          ),
        ],
      ),
    );
  }
}
