import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/song_recommendation.dart';
import '../../services/song_recommendation_service.dart';
import '../../services/song_recommendation_settings_service.dart';
import '../../utils/ui_constants.dart';
import '../song_recommendation_settings_card.dart';

/// Isoliertes Test-Overlay für Mix-Vorschläge nach Musikerkennung.
class RecommendationTestOverlay extends StatefulWidget {
  const RecommendationTestOverlay({
    super.key,
    required this.title,
    required this.artist,
  });

  final String title;
  final String artist;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String artist,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Schließen',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return RecommendationTestOverlay(title: title, artist: artist);
      },
    );
  }

  @override
  State<RecommendationTestOverlay> createState() =>
      _RecommendationTestOverlayState();
}

class _RecommendationTestOverlayState
    extends State<RecommendationTestOverlay> {
  bool _loading = true;
  List<SongRecommendation> _items = const <SongRecommendation>[];
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    SongRecommendationSettingsService.instance.notifier.addListener(
      _onSettingsChanged,
    );
    unawaited(_load());
  }

  @override
  void dispose() {
    SongRecommendationSettingsService.instance.notifier.removeListener(
      _onSettingsChanged,
    );
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    final settings =
        SongRecommendationSettingsService.instance.notifier.value;
    if (!settings.enabled) {
      Navigator.of(context).pop();
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    final id = ++_requestId;
    setState(() => _loading = true);
    final items = await SongRecommendationService.instance
        .suggestForRecognizedSong(
          title: widget.title,
          artist: widget.artist,
        );
    if (!mounted || id != _requestId) return;
    setState(() {
      _loading = false;
      _items = items;
    });
  }

  Future<void> _applySettings(SongRecommendationSettings next) async {
    final current = SongRecommendationSettingsService.instance.notifier.value;
    if (next == current) return;
    await SongRecommendationSettingsService.instance.save(next);
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        SongRecommendationSettingsService.instance.notifier.value;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                maxHeight: MediaQuery.sizeOf(context).height * 0.86,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: UIConstants.appOrange, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 4, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Song-Vorschläge für ${widget.title} – ${widget.artist}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Schließen',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: SongRecommendationQueryChips(
                        settings: settings,
                        onChanged: (next) => unawaited(_applySettings(next)),
                      ),
                    ),
                    if (_loading)
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: UIConstants.appOrange,
                        backgroundColor: Color(0xFF2A2A2A),
                      )
                    else
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: UIConstants.appOrange.withValues(alpha: 0.55),
                      ),
                    Flexible(
                      child: _loading && _items.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 48),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: UIConstants.appOrange,
                                ),
                              ),
                            )
                          : _items.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 28, 16, 32),
                                  child: Text(
                                    'Keine Vorschläge gefunden.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    12,
                                    16,
                                  ),
                                  itemCount: _items.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    return _RecommendationRow(
                                      index: index + 1,
                                      item: _items[index],
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendationRow extends StatelessWidget {
  const _RecommendationRow({required this.index, required this.item});

  final int index;
  final SongRecommendation item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: UIConstants.appOrange.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$index.',
              style: const TextStyle(
                color: UIConstants.appOrange,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  if (item.mixMetaLine.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.mixMetaLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFFCC80),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
