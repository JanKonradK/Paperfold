import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/opds_catalog.dart';
import 'package:paperfold/page/opds/opds_browse_page.dart';
import 'package:paperfold/page/opds/open_book_website.dart';
import 'package:paperfold/providers/opds.dart';
import 'package:paperfold/service/opds/online_book_sources.dart';
import 'package:paperfold/service/opds/opds.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/widgets/common/load_failure.dart';

/// Downloadable catalogs and external book services, with separate actions.
class OpdsCatalogsPage extends ConsumerWidget {
  const OpdsCatalogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = L10n.of(context);
    final AsyncValue<List<OpdsCatalog>> catalogs =
        ref.watch(opdsCatalogsProvider);
    final theme = Theme.of(context);
    final saved = catalogs.value ?? const <OpdsCatalog>[];
    final suggestions = OnlineBookSource.values.where(
        (source) => source.isCatalog && !saved.any(source.matchesCatalog));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.opdsFindBooksOnline)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text(l10n.onlineCatalogsHeading,
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(l10n.onlineCatalogsBody),
                const SizedBox(height: 12),
                for (final source in suggestions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(source.name),
                    subtitle: Text(_description(l10n, source)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _browse(context, source.catalog),
                  ),
                if (saved.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(l10n.onlineSavedCatalogs,
                      style: theme.textTheme.titleMedium),
                ],
                catalogs.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) => LoadFailure.inline(
                    onRetry: () =>
                        ref.read(opdsCatalogsProvider.notifier).refresh(),
                  ),
                  data: (data) => Column(children: [
                    for (final catalog in data)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        minTileHeight: 56,
                        leading: const Icon(Icons.local_library_outlined),
                        title: Text(catalog.name),
                        subtitle: Text(
                          catalog.url.host == 'standardebooks.org'
                              ? l10n.onlineStandardAccess
                              : catalog.needsPassword
                                  ? '${catalog.url.host} · ${l10n.opdsCatalogNeedsSignIn}'
                                  : catalog.url.host,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: l10n.opdsRemoveCatalog,
                          onPressed: () => _remove(context, ref, catalog),
                        ),
                        onTap: () => _browse(context, catalog),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: () => _addCatalog(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.opdsAddCatalog),
                  ),
                ),
                const SizedBox(height: 32),
                Text(l10n.onlineWebsitesHeading,
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(l10n.onlineWebsitesBody),
                const SizedBox(height: 12),
                for (final source in OnlineBookSource.values
                    .where((source) => !source.isCatalog))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.language),
                    title: Text(source.name),
                    subtitle: Text(_description(l10n, source)),
                    trailing: Tooltip(
                      message: l10n.onlineOpenWebsite,
                      child: const Icon(Icons.open_in_new),
                    ),
                    onTap: () => openBookWebsite(context, source.url),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _browse(BuildContext context, OpdsCatalog catalog) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => OpdsBrowsePage(catalog: catalog),
    ));
  }

  String _description(L10n l10n, OnlineBookSource source) => switch (source) {
        OnlineBookSource.gutenberg => l10n.onlineGutenbergDescription,
        OnlineBookSource.ebooksGratuits => l10n.onlineEbooksGratuitsDescription,
        OnlineBookSource.standardEbooks => l10n.onlineStandardDescription,
        OnlineBookSource.globalGrey => l10n.onlineGlobalGreyDescription,
        OnlineBookSource.openLibrary => l10n.onlineOpenLibraryDescription,
        OnlineBookSource.libby => l10n.onlineLibbyDescription,
      };

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    OpdsCatalog catalog,
  ) async {
    final L10n l10n = L10n.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.opdsRemoveCatalog),
        // The password goes with it. Say so before, not after.
        content: Text(l10n.opdsRemoveCatalogBody(catalog.name)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await ref.read(opdsCatalogsProvider.notifier).remove(catalog.id);
      } catch (_) {
        AnxLog.warning('Could not remove catalog');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.opdsCatalogRemoveFailed)),
          );
        }
      }
    }
  }

  Future<void> _addCatalog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CatalogDialog(onSave: (draft) async {
        await ref.read(opdsCatalogsProvider.notifier).add(
              name: draft.name,
              url: draft.url,
              authType: draft.password.isEmpty && draft.username.isEmpty
                  ? OpdsAuthType.none
                  : OpdsAuthType.basic,
              username: draft.username.isEmpty ? null : draft.username,
              password: draft.password,
            );
      }),
    );
  }
}

class _CatalogDraft {
  const _CatalogDraft({
    required this.name,
    required this.url,
    required this.username,
    required this.password,
  });

  final String name;
  final Uri url;
  final String username;
  final String password;
}

class _CatalogDialog extends StatefulWidget {
  const _CatalogDialog({required this.onSave});

  final Future<void> Function(_CatalogDraft) onSave;

  @override
  State<_CatalogDialog> createState() => _CatalogDialogState();
}

class _CatalogDialogState extends State<_CatalogDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _url = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool _failed = false;

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.onSave(_CatalogDraft(
        name: _name.text.trim(),
        url: _parseUrl(_url.text)!,
        username: _username.text.trim(),
        password: _password.text,
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      AnxLog.warning('Could not save catalog');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);

    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(l10n.opdsAddCatalog),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  enabled: !_saving,
                  controller: _name,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.opdsCatalogName),
                  validator: (String? value) =>
                      (value == null || value.trim().isEmpty)
                          ? l10n.commonInputCannotBeEmpty
                          : null,
                ),
                TextFormField(
                  enabled: !_saving,
                  controller: _url,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(labelText: l10n.opdsCatalogUrl),
                  validator: (String? value) =>
                      _parseUrl(value) == null ? l10n.opdsInvalidUrl : null,
                ),
                TextFormField(
                  enabled: !_saving,
                  controller: _username,
                  decoration:
                      InputDecoration(labelText: l10n.opdsCatalogUsername),
                ),
                TextFormField(
                  enabled: !_saving,
                  controller: _password,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l10n.opdsCatalogPassword,
                    suffixIcon: IconButton(
                      tooltip: _obscure
                          ? l10n.commonShowPassword
                          : l10n.commonHidePassword,
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: _saving
                          ? null
                          : () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(l10n.opdsCatalogSaveFailed),
                  ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }

  /// Null when the address is not one this application can fetch.
  ///
  /// A bare host is the usual mistake, and a scheme that is neither http nor
  /// https would send the reader's password somewhere unexpected.
  static Uri? _parseUrl(String? value) {
    final Uri? parsed = Uri.tryParse((value ?? '').trim());
    return parsed != null && isOpdsWebUri(parsed) ? parsed : null;
  }
}
