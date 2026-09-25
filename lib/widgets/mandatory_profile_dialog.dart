import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import '../l10n/app_localizations.dart';
import '../helpers/security_helper.dart';
import '../services/countries_service.dart';
import '../services/dj_b2b_service.dart';
import '../services/user_service.dart';
import '../services/user_self_settings_service.dart';
import '../services/wishbox_suggestions_settings_service.dart';
import '../utils/firebase_error_message.dart';
import '../utils/ui_constants.dart';
import '../app_scaffold_messenger.dart';

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
  String? _saveError;

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

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final birth = _birthDate!;
      await UserSelfSettingsService.instance.write({
        'realName': SecurityHelper.sanitize(
          _realNameController.text.trim(),
          maxLength: 80,
        ),
        'country': _selectedCountryCode,
        'birthDate': Timestamp.fromDate(birth),
        'hasCompletedProfile': true,
        WishboxSuggestionsSettingsService.userField: true,
      });
      try {
        await WishboxSuggestionsSettingsService.guestLiveRef(uid).set(
          {
            WishboxSuggestionsSettingsService.userField: true,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (_) {
        // Wunschbox-Gast-Flag ist optional; Profil-Abschluss darf dadurch nicht scheitern.
      }
      unawaited(DjB2bService.instance.ensureCode());
      if (mounted) {
        UserService().forceRefresh();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        final detail = formatFirebaseErrorDetail(e);
        final message = '${l.error_saving} $detail';
        setState(() {
          _saving = false;
          _saveError = message;
        });
        showTopOverlayVibesSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
          tag: 'mandatory_profile_save',
          error: e,
        );
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
                      l10n.mandatory_profile_title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.mandatory_profile_intro,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[300]),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _realNameController,
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText: l10n.name,
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        hintText: l10n.mandatory_profile_name_hint,
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
                        if (v == null || v.trim().isEmpty) {
                          return l10n.mandatory_profile_name_required;
                        }
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
                          labelText: l10n.mandatory_profile_country_label,
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
                          if (v == null || v.isEmpty) {
                            return l10n.mandatory_profile_country_required;
                          }
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
                            ? l10n.mandatory_profile_pick_birthdate
                            : '${_birthDate!.day}.${_birthDate!.month}.${_birthDate!.year}',
                      ),
                    ),
                    if (_birthDate != null && !_isBirthDateValid(_birthDate!))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _birthDate!.isAfter(DateTime.now())
                              ? l10n.mandatory_profile_birthdate_future
                              : l10n.mandatory_profile_min_age,
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
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: UIConstants.appOrange,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.mandatory_profile_birthdate_immutable,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_saveError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Text(
                          _saveError!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
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
