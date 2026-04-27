import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../helpers/security_helper.dart';
import '../utils/formatting_utils.dart';
import '../utils/debug_log.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final TextEditingController _newTodoController = TextEditingController();
  bool _isLoading = false;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initializeFirstTodo();
    });
  }

  @override
  void dispose() {
    _newTodoController.dispose();
    super.dispose();
  }

  Future<void> _initializeFirstTodo() async {
    if (_hasInitialized) return;
    final l10n = AppLocalizations.of(context)!;

    try {
      // Prüfe ob bereits To-Dos existieren
      final todosSnapshot = await FirebaseFirestore.instance
          .collection('todos')
          .limit(1)
          .get();

      // Wenn keine To-Dos existieren, füge den ersten Punkt hinzu
      if (todosSnapshot.docs.isEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('todos')
              .add(
                {
                  'text': l10n.todo_default_first_item,
                  'completed': false,
                  'created_at': FieldValue.serverTimestamp(),
                  'created_by': user.uid,
                  'created_by_email': user.email ?? '',
                }.map((k, v) => MapEntry(k, SecurityHelper.sanitizeDynamic(v))),
              );
        }
      }
    } catch (e) {
      // Fehler beim Initialisieren ignorieren
      debugLog('Fehler beim Initialisieren des ersten To-Dos: $e');
    } finally {
      _hasInitialized = true;
    }
  }

  Future<void> _addTodo(String text) async {
    final safeText = SecurityHelper.sanitize(text.trim(), maxLength: 500);
    if (safeText.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('todos')
          .add(
            {
              'text': safeText,
              'completed': false,
              'created_at': FieldValue.serverTimestamp(),
              'created_by': user.uid,
              'created_by_email': user.email ?? '',
            }.map((k, v) => MapEntry(k, SecurityHelper.sanitizeDynamic(v))),
          );

      _newTodoController.clear();
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.snackbar_error_adding_todo} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleTodo(String docId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('todos')
          .doc(docId)
          .update(
            SecurityHelper.sanitizeMap({
              'completed': !currentStatus,
              'updated_at': FieldValue.serverTimestamp(),
            }),
          );
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.snackbar_error_updating_todo} $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTodo(String docId) async {
    final l = AppLocalizations.of(context)!;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.todo_delete_dialog_title),
        content: Text(l.todo_delete_dialog_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('todos')
            .doc(docId)
            .delete();
      } catch (e) {
        if (mounted) {
          final loc = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc.snackbar_error_deleting_todo} $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l.todoList)),
      body: Column(
        children: [
          // Eingabefeld für neues To-Do
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTodoController,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: l.todo_field_new_label,
                      border: const OutlineInputBorder(),
                      hintText: l.todo_field_new_hint,
                    ),
                    onSubmitted: (value) {
                      _addTodo(value);
                    },
                    onChanged: (value) {
                      final safe = SecurityHelper.sanitize(
                        value,
                        maxLength: 500,
                      );
                      if (safe != value) {
                        _newTodoController.value = _newTodoController.value
                            .copyWith(
                              text: safe,
                              selection: TextSelection.collapsed(
                                offset: safe.length,
                              ),
                            );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          _addTodo(_newTodoController.text);
                        },
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle),
                  tooltip: l.todo_add_tooltip,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Liste der To-Dos
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('todos')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                final loc = AppLocalizations.of(context)!;
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text(loc.todo_stream_error(snapshot.error!)));
                }

                final todos = snapshot.data?.docs ?? [];

                // Trenne erledigte und offene To-Dos
                final openTodos = todos.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['completed'] as bool? ?? false) == false;
                }).toList();

                final completedTodos = todos.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['completed'] as bool? ?? false) == true;
                }).toList();

                if (todos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loc.todo_empty_title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.todo_empty_subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    // Offene To-Dos
                    ...openTodos.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final text = data['text'] as String? ?? '';
                      final completed = data['completed'] as bool? ?? false;
                      final createdAt = data['created_at'] as Timestamp?;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Checkbox(
                            value: completed,
                            onChanged: (value) {
                              _toggleTodo(doc.id, completed);
                            },
                          ),
                          title: Text(
                            text,
                            style: TextStyle(
                              decoration: completed
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: completed ? Colors.grey[600] : null,
                            ),
                          ),
                          subtitle: createdAt != null
                              ? Text(
                                  '${loc.todo_label_created}: ${_formatDateTime(createdAt.toDate())}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                )
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red,
                            onPressed: () => _deleteTodo(doc.id),
                            tooltip: loc.delete,
                          ),
                        ),
                      );
                    }).toList(),

                    // Erledigte To-Dos unter einem Button
                    if (completedTodos.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ExpansionTile(
                        title: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              loc.todo_completed_section_title(completedTodos.length),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        initiallyExpanded: false,
                        children: completedTodos.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final text = data['text'] as String? ?? '';
                          final completed = data['completed'] as bool? ?? false;
                          final createdAt = data['created_at'] as Timestamp?;
                          final updatedAt = data['updated_at'] as Timestamp?;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            color: Colors.grey[100],
                            child: ListTile(
                              leading: Checkbox(
                                value: completed,
                                onChanged: (value) {
                                  _toggleTodo(doc.id, completed);
                                },
                              ),
                              title: Text(
                                text,
                                style: TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey[600],
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (createdAt != null)
                                    Text(
                                      '${loc.todo_label_created}: ${_formatDateTime(createdAt.toDate())}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  if (updatedAt != null)
                                    Text(
                                      '${loc.todo_label_completed}: ${_formatDateTime(updatedAt.toDate())}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: Colors.red,
                                onPressed: () => _deleteTodo(doc.id),
                                tooltip: loc.delete,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final localizations = AppLocalizations.of(context)!;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final timeString = FormattingUtils.formatTime(date, context);
    final at = localizations.party_time_at;
    return '$day.$month.$year $at $timeString';
  }
}
