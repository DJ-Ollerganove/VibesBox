import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'main.dart' show incrementDeletedCount;
import '../utils/ui_constants.dart';
import '../l10n/app_localizations.dart';
import '../models/song_request.dart';
import '../services/history_pagination_service.dart';
import '../utils/string_utils.dart';

class GespieltPage extends StatefulWidget {
  final List<SongRequest> requests;
  
  const GespieltPage({super.key, required this.requests});

  @override
  State<GespieltPage> createState() => _GespieltPageState();
}

class _GespieltPageState extends State<GespieltPage> {
  int _currentPage = 1; // ✅ Paginierung: Aktuelle Seite
  final ScrollController _scrollController = ScrollController(); // ✅ Für Scrollen nach oben beim Seitenwechsel

  @override
  void dispose() {
    _scrollController.dispose(); // ✅ ScrollController aufräumen
    super.dispose();
  }

  /// Navigiert zur vorherigen Seite und scrollt nach oben
  void _goToPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
      // ✅ Scroll nach oben, damit DJ die neuen Titel sofort sieht
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  /// Navigiert zur nächsten Seite und scrollt nach oben
  void _goToNextPage(int totalPages) {
    if (_currentPage < totalPages) {
      setState(() {
        _currentPage++;
      });
      // ✅ Scroll nach oben, damit DJ die neuen Titel sofort sieht
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  /// Baut die Paginierungs-Buttons mit Grün/Schwarz Design (passend zu Gespielt-Songs)
  Widget _buildPaginationButtons(int currentPage, int totalPages, BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);

    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16), // ✅ Kompakter oberer Abstand, unterer Abstand bleibt für Footer
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: UIConstants.djChromePanelDecoration,
      child: Row(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Zurück-Button
          ElevatedButton.icon(
            onPressed: HistoryPaginationService.hasPreviousPage(currentPage)
                ? _goToPreviousPage
                : null,
            icon: Icon(
              isRtl ? Icons.arrow_forward : Icons.arrow_back,
              size: 18,
            ),
            label: Text(l.history_page_previous),
            style: ElevatedButton.styleFrom(
              backgroundColor: UIConstants.djShellPageBackground,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[900],
              disabledForegroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: const BorderSide(color: UIConstants.appOrange, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // Seitenanzeige
          Text(
            '${l.history_page} $currentPage / $totalPages',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
          // Vor-Button
          ElevatedButton.icon(
            onPressed: HistoryPaginationService.hasNextPage(currentPage, totalPages)
                ? () => _goToNextPage(totalPages)
                : null,
            icon: Icon(
              isRtl ? Icons.arrow_back : Icons.arrow_forward,
              size: 18,
            ),
            label: Text(l.history_page_next),
            style: ElevatedButton.styleFrom(
              backgroundColor: UIConstants.djShellPageBackground,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[900],
              disabledForegroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: const BorderSide(color: UIConstants.appOrange, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatShortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year.toString().substring(2)}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Filtere gespielte Wünsche und Duplikate heraus
    final playedWishes = widget.requests
        .where((request) => request.status == 'played' && request.isDuplicate != true)
        .toList();
    
    if (playedWishes.isEmpty) {
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
                // Überschrift
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).colorScheme.secondaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.played,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(AppLocalizations.of(context)!.no_played_wishes),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Sortiere nach playedAt oder createdAt (neueste zuerst)
    final sortedWishes = playedWishes.toList()
      ..sort((a, b) {
        final dateA = a.playedAt?.toDate() ?? a.recognizedAt?.toDate() ?? a.createdAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.playedAt?.toDate() ?? b.recognizedAt?.toDate() ?? b.createdAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA); // Neueste zuerst
      });
    
    // Gruppiere Wünsche nach Titel und Interpret
    final groupedResult = _groupWishes(sortedWishes);
    final allGroupedList = groupedResult['groups'] as List<Map<String, dynamic>>;
    final groupedFirstRequests = groupedResult['firstRequests'] as Map<String, SongRequest>;
    final groupedDocIds = groupedResult['docIds'] as Map<String, List<String>>;

    // ✅ Paginierung: Berechne Seiten
    final totalPages = HistoryPaginationService.calculateTotalPages(allGroupedList.length);
    
    // ✅ Stelle sicher, dass _currentPage automatisch korrigiert wird, wenn die Gesamtanzahl der Seiten sinkt
    if (_currentPage > totalPages && totalPages > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentPage = totalPages;
          });
        }
      });
    }
    
    // ✅ Hole paginierte Liste (10 Einträge pro Seite)
    final paginatedGroupedList = HistoryPaginationService.getItemsForPage(
      allGroupedList,
      _currentPage > 0 ? _currentPage : 1,
    );

    // ✅ Variable Logik für bottomPadding
    // ✅ Kompakteres bottomPadding für weniger Abstand zwischen Songs und Paginierungs-Buttons
    final bottomPadding = totalPages > 1 ? 8.0 : 200.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController, // ✅ ScrollController für Scrollen nach oben
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Überschrift
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.played,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              RepaintBoundary(
                // WICHTIG: RepaintBoundary isoliert die Liste komplett vom Rest der UI
                child: Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        top: 8.0,
                        bottom: bottomPadding,
                      ),
                      itemCount: paginatedGroupedList.length,
                      itemBuilder: (context, index) {
                        final groupEntry = paginatedGroupedList[index];
                        final groupKey = groupEntry['key'] as String;
                        final data = groupEntry['data'] as Map<String, dynamic>;
                        final docIds = groupedDocIds[groupKey]!;
                        final firstRequest = groupedFirstRequests[groupKey]!;
                        
                        // ✅ Berechne Nummer basierend auf Gesamtliste und aktueller Seite
                        final number = allGroupedList.length - (HistoryPaginationService.calculateStartIndex(_currentPage > 0 ? _currentPage : 1) + index);
                        
                        return Column(
                          children: [
                            _buildGroupedWishCard(
                              context,
                              data,
                              docIds,
                              firstRequest,
                              number,
                              key: ValueKey(groupKey), // WICHTIG: Stabilisiert die Liste
                            ),
                            if (index < paginatedGroupedList.length - 1) const Divider(height: 1),
                          ],
                        );
                      },
                    ),
                    // ✅ Paginierungs-Buttons (nur wenn mehr als 1 Seite) - GRÜN statt Orange/Blau
                    if (totalPages > 1) _buildPaginationButtons(_currentPage, totalPages, context),
                    // ✅ Leerblock am Ende, damit der letzte Eintrag vollständig oberhalb der Pegellinie scrollbar ist
                    SizedBox(height: totalPages > 1 ? UIConstants.kFooterPadding * 2 : 200),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Gruppiert Wünsche nach Titel und Interpret
  /// Gibt Map zurück mit: 'groups', 'firstRequests', 'docIds'
  Map<String, dynamic> _groupWishes(List<SongRequest> sortedWishes) {
    final Map<String, Map<String, dynamic>> groupedWishes = {};
    final Map<String, List<String>> groupedDocIds = {};
    final Map<String, SongRequest> groupedFirstRequests = {};
    
    for (final request in sortedWishes) {
      final title = request.displayTitle.trim().toLowerCase();
      final artist = (request.artist ?? '').trim().toLowerCase();
      final groupKey = '$title|$artist';
      
      if (!groupedWishes.containsKey(groupKey)) {
        // Erste Wunsch für diesen Song - erstelle Gruppeneintrag
        final requestedBy = request.requestedBy ?? [];
        final name = request.name ?? '';
        final namesToShow = requestedBy.isNotEmpty ? requestedBy : (name.isNotEmpty ? [name] : []);
        final greetings = request.greetings ?? [];
        final greeting = request.greeting ?? '';
        if (greeting.isNotEmpty && !greetings.any((g) => g['name'] == name && g['greeting'] == greeting)) {
          final newGreetings = List<Map<String, dynamic>>.from(greetings);
          newGreetings.add({'name': name, 'greeting': greeting});
          greetings.addAll(newGreetings);
        }
        
        // Hole played_at oder recognized_at (für Wartezeit-Berechnung)
        final playedAt = request.playedAt ?? request.recognizedAt;
        
        groupedWishes[groupKey] = {
          'title': request.displayTitle,
          'artist': request.artist ?? '',
          'duplicate_count': request.duplicateCount ?? 0,
          'requested_by': namesToShow,
          'greetings': greetings,
          'is_registered_users': request.isRegisteredUsers ?? {},
          'createdAt': request.createdAt,
          'played_at': playedAt,
          'recognized_at': request.recognizedAt,
          'auto_recognized': request.autoRecognized ?? false,
        };
        groupedDocIds[groupKey] = [request.id];
        groupedFirstRequests[groupKey] = request;
      } else {
        // Weitere Wunsch für diesen Song - füge Daten hinzu
        final group = groupedWishes[groupKey]!;
        final duplicateCount = request.duplicateCount ?? 0;
        final requestedBy = request.requestedBy ?? [];
        final name = request.name ?? '';
        final namesToShow = requestedBy.isNotEmpty ? requestedBy : (name.isNotEmpty ? [name] : []);
        final greetings = request.greetings ?? [];
        final greeting = request.greeting ?? '';
        if (greeting.isNotEmpty && !greetings.any((g) => g['name'] == name && g['greeting'] == greeting)) {
          final newGreetings = List<Map<String, dynamic>>.from(greetings);
          newGreetings.add({'name': name, 'greeting': greeting});
          greetings.addAll(newGreetings);
        }
        
        // Aggregiere Daten
        final existingRequestedBy = List<String>.from(group['requested_by'] as List);
        for (final n in namesToShow) {
          if (!existingRequestedBy.contains(n)) {
            existingRequestedBy.add(n);
          }
        }
        
        final existingGreetings = List<Map<String, dynamic>>.from(group['greetings'] as List);
        for (final g in greetings) {
          if (!existingGreetings.any((eg) => eg['name'] == g['name'] && eg['greeting'] == g['greeting'])) {
            existingGreetings.add(g);
          }
        }
        
        final existingIsRegisteredUsers = Map<String, bool>.from(group['is_registered_users'] as Map<String, dynamic>);
        final newIsRegisteredUsers = request.isRegisteredUsers ?? {};
        existingIsRegisteredUsers.addAll(newIsRegisteredUsers);
        
        // Aktualisiere Gruppeneintrag
        group['duplicate_count'] = (group['duplicate_count'] as int) + duplicateCount + 1; // +1 für aktuellen Wunsch
        group['requested_by'] = existingRequestedBy;
        group['greetings'] = existingGreetings;
        group['is_registered_users'] = existingIsRegisteredUsers;
        
        // Verwende das älteste createdAt
        final existingCreatedAt = group['createdAt'] as Timestamp?;
        final newCreatedAt = request.createdAt;
        if (newCreatedAt != null && (existingCreatedAt == null || newCreatedAt.toDate().isBefore(existingCreatedAt.toDate()))) {
          group['createdAt'] = newCreatedAt;
        }
        
        // Verwende das neueste played_at/recognized_at
        final existingPlayedAt = group['played_at'] as Timestamp?;
        final newPlayedAt = request.playedAt ?? request.recognizedAt;
        if (newPlayedAt != null) {
          if (existingPlayedAt == null || newPlayedAt.toDate().isAfter(existingPlayedAt.toDate())) {
            group['played_at'] = newPlayedAt;
          }
        }
        
        // Auto-Erkennung: Wenn mindestens einer auto_recognized hat, zeige Icon
        if (request.autoRecognized == true) {
          group['auto_recognized'] = true;
        }
        
        groupedDocIds[groupKey]!.add(request.id);
      }
    }
    
    // Konvertiere gruppierte Wünsche zurück in sortierte Liste
    final groupedList = groupedWishes.entries.map((entry) => {
      'key': entry.key,
      'data': entry.value,
    }).toList()
      ..sort((a, b) {
        final tsA = (a['data'] as Map<String, dynamic>)['played_at'] as Timestamp? ?? 
                   (a['data'] as Map<String, dynamic>)['createdAt'] as Timestamp?;
        final tsB = (b['data'] as Map<String, dynamic>)['played_at'] as Timestamp? ?? 
                   (b['data'] as Map<String, dynamic>)['createdAt'] as Timestamp?;
        final dateA = tsA?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = tsB?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
    
    return {
      'groups': groupedList,
      'firstRequests': groupedFirstRequests,
      'docIds': groupedDocIds,
    };
  }

  Widget _buildGroupedWishCard(
    BuildContext context,
    Map<String, dynamic> data,
    List<String> docIds,
    SongRequest firstRequest,
    int number,
    {Key? key}
  ) {
    final title = unescapeHtml((data['title'] ?? '') as String);
    final artist = unescapeHtml((data['artist'] ?? '') as String);
    final duplicateCount = (data['duplicate_count'] as int?) ?? 0;
    final requestedBy = List<String>.from((data['requested_by'] as List?) ?? []);
    final namesToShow = requestedBy;
    final isRegisteredUsers = Map<String, bool>.from((data['is_registered_users'] as Map<String, dynamic>?) ?? {});
    final greetings = List<Map<String, dynamic>>.from(
      (data['greetings'] as List?)?.map((g) => g as Map<String, dynamic>) ?? []
    );
    final tsCreated = data['createdAt'] as Timestamp?;
    final created = tsCreated?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
    final tsPlayed = data['played_at'] as Timestamp?;
    final played = tsPlayed?.toDate();
    final autoRecognized = data['auto_recognized'] as bool? ?? false;
    
    // Berechne Wartezeit in Minuten
    int? waitTimeMinutes;
    if (played != null && created != DateTime.fromMillisecondsSinceEpoch(0)) {
      final difference = played.difference(created);
      waitTimeMinutes = difference.inMinutes;
    }
    
    String displayText = '';
    if (title.isNotEmpty && artist.isNotEmpty) {
      displayText = '$title - $artist';
    } else if (title.isNotEmpty) {
      displayText = title;
    } else if (artist.isNotEmpty) {
      displayText = artist;
    }
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final totalWishes = duplicateCount + 1; // +1 für den ersten Wunsch
    
    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: () {},
        splashColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.amber.shade800
            : Colors.amber.shade200,
        highlightColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.amber.shade900.withValues(alpha: 0.3)
            : Colors.amber.shade100,
        child: ListTile(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hauptzeile: Auto-Match Icon + Titel - Interpret + Wunsch-Anzahl
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0, top: 2.0),
                    child: Text(
                      '$number.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Auto-Match Icon
                  if (autoRecognized)
                    Padding(
                      padding: const EdgeInsets.only(right: 6.0, top: 2.0),
                      child: Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: isDarkMode ? Colors.blue.shade400 : Colors.blue.shade600,
                      ),
                    ),
                  // Titel - Interpret mit automatischem Zeilenumbruch
                  Expanded(
                    child: Text(
                      displayText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  // Wunsch-Anzahl deutlich anzeigen
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Text(
                      '${totalWishes}x gewünscht',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Strukturiertes Zeit-Layout (2 separate Zeilen)
              Text(
                'Wunsch: ${_formatShortDate(created)} ${_formatTime(created)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
              if (played != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Gespielt: ${_formatShortDate(played)} ${_formatTime(played)}${waitTimeMinutes != null ? ' ($waitTimeMinutes Min.)' : ''}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              // Zeige alle Namen
              if (namesToShow.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    ...namesToShow.map((n) {
                      final isRegisteredUser = isRegisteredUsers[n] ?? 
                        (n.contains('@') && n.split('@').length == 2 && n.split('@')[1].contains('.'));
                      return Chip(
                        label: Text(
                          n,
                          style: TextStyle(
                            fontSize: 11,
                            color: isRegisteredUser ? Colors.green.shade700 : Colors.grey[700],
                            fontWeight: isRegisteredUser ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        backgroundColor: isRegisteredUser ? Colors.green.shade50 : Colors.grey.shade100,
                      );
                    }),
                  ],
                ),
              ],
              // Zeige alle Grüße (schwarze Schrift)
              if (greetings.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...greetings.map((g) {
                  final greetingName = g['name'] as String? ?? '';
                  final greetingText = g['greeting'] as String? ?? '';
                  if (greetingText.isEmpty) return const SizedBox.shrink();
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.favorite, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (greetingName.isNotEmpty && namesToShow.length > 1)
                                  Text(
                                    '$greetingName:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (greetingName.isNotEmpty && namesToShow.length > 1)
                                  const SizedBox(height: 2),
                                Text(
                                  greetingText,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.blue),
                tooltip: AppLocalizations.of(context)!.back_to_open,
                onPressed: () => _updateWishStatusGrouped(context, docIds, 'pending'),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: AppLocalizations.of(context)!.delete,
                onPressed: () => _confirmDeleteGrouped(context, docIds, displayText),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Aktualisiert Status für alle Wünsche in einer Gruppe
  Future<void> _updateWishStatusGrouped(BuildContext context, List<String> docIds, String status) async {
    final loc = AppLocalizations.of(context)!;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final docId in docIds) {
        final docRef = FirebaseFirestore.instance.collection('wishes').doc(docId);
        batch.update(docRef, {
          'status': status,
          'status_changed_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.snackbar_wishes_updated(docIds.length))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.snackbar_error_details(e)), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  /// Löscht alle Wünsche in einer Gruppe
  Future<void> _confirmDeleteGrouped(BuildContext context, List<String> docIds, String displayText) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.delete_permanently),
        content: Text(loc.played_group_delete_message(docIds.length, displayText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (final docId in docIds) {
          final docRef = FirebaseFirestore.instance.collection('wishes').doc(docId);
          batch.delete(docRef);
        }
        await batch.commit();
        await incrementDeletedCount();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.snackbar_wishes_deleted(docIds.length))),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.snackbar_error_details(e)), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}


