import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/opds_catalog.dart';
import 'package:paperfold/page/opds/opds_browse_page.dart';
import 'package:paperfold/providers/opds.dart';
import 'package:paperfold/widgets/ornament.dart';

/// The catalogs the reader can browse.
///
/// Standard Ebooks and Project Gutenberg are already here on a new install.
/// plan.md Section 9.4: the weak first run and OPDS are the same feature, so a
/// new shelf is never empty.
class OpdsCatalogsPage extends ConsumerWidget {
  const OpdsCatalogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = L10n.of(context);
    final AsyncValue<List<OpdsCatalog>> catalogs =
        ref.watch(opdsCatalogsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.opdsCatalogs)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCatalog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.opdsAddCatalog),
      ),
      body: catalogs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) =>
            Center(child: Text(l10n.opdsErrorNetwork)),
        data: (List<OpdsCatalog> data) {
          if (data.isEmpty) {
            return _Empty(message: l10n.opdsCatalogsEmpty);
          }
          return ListView.builder(
            padding: EdgeInsets.only(
              bottom: 96 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            itemCount: data.length,
            itemBuilder: (BuildContext context, int index) {
              final OpdsCatalog catalog = data[index];
              return ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.local_library_outlined),
                title: Text(catalog.name),
                subtitle: Text(
                  catalog.needsPassword
                      ? '${catalog.url.host} · ${l10n.opdsCatalogNeedsSignIn}'
                      : catalog.url.host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.opdsRemoveCatalog,
                  onPressed: () => _remove(context, ref, catalog),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        OpdsBrowsePage(catalog: catalog),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

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
    if (confirmed ?? false) {
      await ref.read(opdsCatalogsProvider.notifier).remove(catalog.id);
    }
  }

  Future<void> _addCatalog(BuildContext context, WidgetRef ref) async {
    final _CatalogDraft? draft = await showDialog<_CatalogDraft>(
      context: context,
      builder: (BuildContext context) => const _CatalogDialog(),
    );
    if (draft == null) {
      return;
    }
    await ref.read(opdsCatalogsProvider.notifier).add(
          name: draft.name,
          url: draft.url,
          authType: draft.password.isEmpty && draft.username.isEmpty
              ? OpdsAuthType.none
              : OpdsAuthType.basic,
          username: draft.username.isEmpty ? null : draft.username,
          password: draft.password,
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
  const _CatalogDialog();

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

    return AlertDialog(
      title: Text(l10n.opdsAddCatalog),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.opdsCatalogName),
                validator: (String? value) =>
                    (value == null || value.trim().isEmpty)
                        ? l10n.commonInputCannotBeEmpty
                        : null,
              ),
              TextFormField(
                controller: _url,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: l10n.opdsCatalogUrl),
                validator: (String? value) =>
                    _parseUrl(value) == null ? l10n.opdsInvalidUrl : null,
              ),
              TextFormField(
                controller: _username,
                decoration:
                    InputDecoration(labelText: l10n.opdsCatalogUsername),
              ),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: l10n.opdsCatalogPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () {
            if (!(_form.currentState?.validate() ?? false)) {
              return;
            }
            Navigator.of(context).pop(
              _CatalogDraft(
                name: _name.text.trim(),
                url: _parseUrl(_url.text)!,
                username: _username.text.trim(),
                password: _password.text,
              ),
            );
          },
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }

  /// Null when the address is not one this application can fetch.
  ///
  /// A bare host is the usual mistake, and a scheme that is neither http nor
  /// https would send the reader's password somewhere unexpected.
  static Uri? _parseUrl(String? value) {
    final Uri? parsed = Uri.tryParse((value ?? '').trim());
    if (parsed == null || !parsed.hasAuthority) {
      return null;
    }
    if (parsed.scheme != 'http' && parsed.scheme != 'https') {
      return null;
    }
    return parsed;
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Ornament(
            ornament: PaperfoldOrnament.circularWreath,
            width: 112,
            height: 112,
          ),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
