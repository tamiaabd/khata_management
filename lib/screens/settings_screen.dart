import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../providers/settings_provider.dart';
import '../services/update_service.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const int _companyId = 1;
  final _updateService = UpdateService();

  static const List<String> _urduFonts = [
    'BombayBlackUnicode',
    'JameelNooriNastaleeq',
    'JameelNooriNastaleeqKasheeda',
  ];

  static const List<String> _englishFonts = [
    'Poppins',
    'Roboto',
    'Open Sans',
    'Inter',
    'Lato',
  ];

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final pad = LedgerLayout.viewportHorizontalPadding(
            constraints.maxWidth,
          );
          final maxContent = math.min(
            560.0,
            (constraints.maxWidth - 2 * pad).clamp(0.0, double.infinity),
          );
          final settings = context.watch<SettingsProvider>();

          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContent),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        children: [
                          Text(
                            'Company',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                          StreamBuilder<Company>(
                            stream:
                                (db.select(db.companies)
                                      ..where((t) => t.id.equals(_companyId)))
                                    .watchSingle(),
                            builder: (context, snap) {
                              final name = snap.data?.companyName ?? '';
                              return _CompanyNameCard(
                                name: name,
                                englishFont: settings.englishFont,
                                onSave: (newName) async {
                                  await (db.update(db.companies)
                                        ..where((t) => t.id.equals(_companyId)))
                                      .write(
                                        CompaniesCompanion(
                                          companyName: Value(newName),
                                          updatedAt: Value(DateTime.now()),
                                        ),
                                      );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Fonts',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                          _FontCard(
                            label: 'Urdu Font',
                            value: _urduFonts.contains(settings.urduFont)
                                ? settings.urduFont
                                : _urduFonts.first,
                            options: _urduFonts,
                            onChanged: settings.setUrduFont,
                          ),
                          const SizedBox(height: 12),
                          _FontCard(
                            label: 'English Font',
                            value: settings.englishFont,
                            options: _englishFonts,
                            onChanged: settings.setEnglishFont,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () =>
                                  _checkForUpdatesManually(context),
                              icon: const Icon(Icons.system_update_alt),
                              label: const Text('Check for Updates'),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.delete,
                                side: const BorderSide(color: AppColors.delete),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _confirmReset(context, db),
                              icon: const Icon(Icons.delete),
                              label: const Text('Reset All Data'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: math.max(16.0, pad + 8)),
                child: const Center(
                  child: Text(
                    'Created by Saari Technologies',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, AppDatabase db) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
          'This will permanently delete every row in the ledger. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.delete),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await db.ledgerDao.deleteAllEntriesForCompany(_companyId);
      await db.companyDao.touchCompanyUpdatedAt(_companyId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All ledger data has been reset.')),
        );
      }
    }
  }

  Future<void> _checkForUpdatesManually(BuildContext context) async {
    final info = await _updateService.checkForUpdate();
    if (!context.mounted) return;

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already have the latest version.')),
      );
      return;
    }

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update available'),
        content: Text(
          'Current: ${info.currentVersion}+${info.currentBuild}\nLatest: ${info.latestVersion}+${info.latestBuild}\n\nDo you want to download and install the latest version?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Update now'),
          ),
        ],
      ),
    );
    if (shouldUpdate != true || !context.mounted) return;
    final started = await _runUpdateWithProgress(info);
    if (!context.mounted || started) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not start update installer.')),
    );
  }

  Future<bool> _runUpdateWithProgress(UpdateInfo info) async {
    final progress = ValueNotifier<double>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Downloading update'),
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, value, _) {
              final percent = (value * 100).toStringAsFixed(0);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: value > 0 ? value : null),
                  const SizedBox(height: 12),
                  Text('Progress: $percent%'),
                ],
              );
            },
          ),
        ),
      ),
    );

    final started = await _updateService.downloadAndInstall(
      info,
      onProgress: (value) => progress.value = value,
    );
    if (!mounted) return started;
    Navigator.of(context, rootNavigator: true).pop();
    progress.dispose();
    return started;
  }
}

class _CompanyNameCard extends StatefulWidget {
  const _CompanyNameCard({
    required this.name,
    required this.englishFont,
    required this.onSave,
  });

  final String name;
  final String englishFont;
  final ValueChanged<String> onSave;

  @override
  State<_CompanyNameCard> createState() => _CompanyNameCardState();
}

class _CompanyNameCardState extends State<_CompanyNameCard> {
  late final TextEditingController _controller;
  bool _isEditing = false;

  TextStyle _englishStyle(
    BuildContext context, {
    required double fontSize,
    required FontWeight fontWeight,
    Color? color,
  }) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.textPrimary,
    );
    return GoogleFonts.getFont(widget.englishFont, textStyle: base);
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.name);
  }

  @override
  void didUpdateWidget(covariant _CompanyNameCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name && !_isEditing) {
      _controller.text = widget.name;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSave(text);
    }
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.gridLine),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: _isEditing
                  ? TextField(
                      controller: _controller,
                      autofocus: true,
                      style: _englishStyle(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Company name',
                        hintStyle: _englishStyle(
                          context,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _save(),
                    )
                  : Text(
                      widget.name.isEmpty ? 'Company name' : widget.name,
                      style: _englishStyle(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            _isEditing
                ? IconButton(
                    icon: const Icon(Icons.check, color: AppColors.primary),
                    onPressed: _save,
                  )
                : IconButton(
                    icon: const Icon(
                      Icons.edit,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _isEditing = true),
                  ),
          ],
        ),
      ),
    );
  }
}

class _FontCard extends StatelessWidget {
  const _FontCard({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.gridLine),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                borderRadius: BorderRadius.circular(8),
                focusColor: Colors.transparent,
                items: options.map((font) {
                  return DropdownMenuItem<String>(
                    value: font,
                    child: Text(font, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (font) {
                  if (font != null) {
                    onChanged(font);
                    FocusManager.instance.primaryFocus?.unfocus();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
