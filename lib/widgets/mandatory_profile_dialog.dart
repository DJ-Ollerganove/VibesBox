import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../helpers/security_helper.dart';
import '../services/countries_service.dart';
import '../services/user_service.dart';
import '../utils/ui_constants.dart';

/// Pflicht-Dialog für DJs: Real Name, Land, Geburtsdatum. Nicht wegklickbar.
/// Nach Speichern: hasCompletedProfile = true.
class MandatoryProfileDialog extends StatefulWidget {
  const MandatoryProfileDialog({super.key});

  @override
  State<MandatoryProfileDialog> createState() => _MandatoryProfileDialogState();
}

class _MandatoryProfileDialogState extends State<MandatoryProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _realNameController = TextEditingController();
  String? _selectedCountryCode;
  DateTime? _birthDate;
  List<CountryEntry> _countries = [];
  bool _loadingCountries = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    final list = await CountriesService.getCountriesOnce();
    if (mounted) {
      setState(() {
        _countries = list;
        _loadingCountries = false;
      });
    }
  }

  @override
  void dispose() {
    _realNameController.dispose();
    super.dispose();
  }

  bool get _isValid {
    final nameOk = _realNameController.text.trim().isNotEmpty;
    final countryOk =
        _selectedCountryCode != null && _selectedCountryCode!.isNotEmpty;
    final dateOk = _birthDate != null && _isBirthDateValid(_birthDate!);
    return nameOk && countryOk && dateOk;
  }

  bool _isBirthDateValid(DateTime date) {
    final now = DateTime.now();
    if (date.isAfter(now)) return false;
    final age = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      return age - 1 >= 10;
    }
    return age >= 10;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? now.subtract(const Duration(days: 365 * 15)),
      firstDate: DateTime(now.year - 120, 1, 1),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_isValid || _saving) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(
            {
              'realName': SecurityHelper.sanitize(
                _realNameController.text.trim(),
                maxLength: 80,
              ),
              'country': _selectedCountryCode,
              'birthDate': _birthDate != null
                  ? Timestamp.fromDate(_birthDate!)
                  : null,
              'hasCompletedProfile': true,
            }.map((k, v) => MapEntry(k, SecurityHelper.sanitizeDynamic(v))),
          );
      if (mounted) {
        UserService().forceRefresh();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.error_saving} $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.grey[900]!, Colors.black],
            ),
            border: Border.all(color: UIConstants.appOrange, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Profil vervollständigen',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Um VibesBox noch besser zu machen und für rein statistische Zwecke, benötigen wir noch diese Angaben von dir. Deine Daten werden vertraulich behandelt und nirgendwo weiter verwendet.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[300]),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _realNameController,
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        hintText: 'Vor- und Nachname',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: UIConstants.appOrange.withValues(alpha: 0.7),
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: UIConstants.appOrange,
                            width: 2,
                          ),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.words,
                      onChanged: (value) {
                        final safe = SecurityHelper.sanitize(
                          value,
                          maxLength: 80,
                          trimInput: false,
                        );
                        if (safe != value) {
                          _realNameController.value = _realNameController.value
                              .copyWith(
                                text: safe,
                                selection: TextSelection.collapsed(
                                  offset: safe.length,
                                ),
                              );
                        }
                        setState(() {});
                      },
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Bitte Namen angeben.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_loadingCountries)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        key: ValueKey<String?>(_selectedCountryCode),
                        initialValue: _selectedCountryCode,
                        isExpanded: true,
                        menuMaxHeight: 400,
                        itemHeight: 56,
                        dropdownColor: Colors.grey.shade800,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Land',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: UIConstants.appOrange.withValues(alpha: 0.7),
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: UIConstants.appOrange,
                              width: 2,
                            ),
                          ),
                        ),
                        items: _countries
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c.code,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    c.name,
                                    softWrap: true,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCountryCode = v),
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Bitte Land wählen.';
                          return null;
                        },
                      ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: UIConstants.appOrange.withValues(alpha: 0.8),
                        ),
                      ),
                      icon: const Icon(Icons.calendar_today, size: 20),
                      label: Text(
                        _birthDate == null
                            ? 'Geburtsdatum wählen'
                            : '${_birthDate!.day}.${_birthDate!.month}.${_birthDate!.year}',
                      ),
                    ),
                    if (_birthDate != null && !_isBirthDateValid(_birthDate!))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _birthDate!.isAfter(DateTime.now())
                              ? 'Datum darf nicht in der Zukunft liegen.'
                              : 'Du musst mindestens 10 Jahre alt sein.',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: UIConstants.appOrange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: UIConstants.appOrange),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: UIConstants.appOrange,
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Das Geburtsdatum kann später nicht mehr geändert werden!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (_isValid && !_saving) ? _save : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: UIConstants.appOrange,
                          foregroundColor: Colors.black,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(l10n.save),
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
