import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/recipe_fetch.dart';
import '../../data/store_scope.dart';
import '../../logic/recipe_link.dart';
import '../../models/models.dart';

typedef RecipeFetcher = Future<RecipeDraft> Function(String link);

/// Add or edit a saved recipe. From a link: paste it, tap Read, check what
/// came back, save. Own recipe: type it in.
class RecipeEditorPage extends StatefulWidget {
  const RecipeEditorPage({super.key, this.existing, this.startFromLink = false, this.fetcher});

  /// More lines than any home recipe has: a pasted web page, not a list.
  static const maxIngredients = 40;
  final SavedRecipe? existing;
  final bool startFromLink;

  /// Reads a link; tests pass a fake.
  final RecipeFetcher? fetcher;

  @override
  State<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends State<RecipeEditorPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _link;
  late final TextEditingController _minutes;
  late final TextEditingController _ingredients;
  late final TextEditingController _method;
  late bool _linked;
  bool _reading = false;
  String? _readMessage;
  String? _printUrl;
  String? _lastReadLink;

  static const maxLineLength = 120;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _link = TextEditingController(text: e?.url ?? '');
    _minutes = TextEditingController(text: e?.minutes?.toString() ?? '');
    _ingredients = TextEditingController(text: e?.ingredients.join('\n') ?? '');
    _method = TextEditingController(text: e?.method ?? '');
    _linked = e?.isLinked ?? widget.startFromLink;
    _printUrl = e?.printUrl;
    if (widget.startFromLink && e == null) _pasteLinkFromClipboard();
  }

  Future<void> _pasteLinkFromClipboard() async {
    String text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
    } on Exception {
      return; // no clipboard access: the person pastes it themselves
    }
    if (mounted && _link.text.isEmpty && text.startsWith('http')) {
      setState(() => _link.text = text);
      await _read();
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _link, _minutes, _ingredients, _method]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Reads the link once it looks complete, so there is no button to find.
  void _onLinkChanged(String value) {
    final uri = Uri.tryParse(value.trim());
    final looksComplete = uri != null && uri.hasScheme && uri.host.contains('.') && uri.path.length > 1;
    if (looksComplete && value.trim() != _lastReadLink && !_reading) _read();
  }

  Future<void> _read() async {
    _lastReadLink = _link.text.trim();
    setState(() {
      _reading = true;
      _readMessage = null;
    });
    try {
      final draft = await (widget.fetcher ?? fetchRecipeFromLink)(_link.text);
      if (!mounted) return;
      setState(() {
        if (draft.name.isNotEmpty) _name.text = draft.name;
        if (draft.minutes != null) _minutes.text = '${draft.minutes}';
        if (draft.ingredients.isNotEmpty) _ingredients.text = draft.ingredients.join('\n');
        _printUrl = draft.printUrl;
        _readMessage = 'Read ${draft.ingredients.length} ingredients. Check them, then save.';
      });
    } on RecipeFetchException catch (e) {
      if (mounted) setState(() => _readMessage = '${e.message} You can type the details in.');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  List<String> get _ingredientLines =>
      _ingredients.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final store = StoreScope.read(context);
    final minutes = int.tryParse(_minutes.text.trim());
    final url = _linked ? _link.text.trim() : null;
    final e = widget.existing;
    if (e == null) {
      await store.addRecipe(
        name: _name.text,
        ingredients: _ingredientLines,
        url: url,
        printUrl: _printUrl,
        minutes: minutes,
        method: _method.text,
      );
    } else {
      await store.updateRecipe(
        e.copyWith(
          name: _name.text,
          url: url,
          clearUrl: url == null || url.isEmpty,
          printUrl: _printUrl,
          minutes: minutes,
          clearMinutes: minutes == null,
          ingredients: _ingredientLines,
          method: _method.text,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = widget.existing!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove ${e.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final navigator = Navigator.of(context);
    await StoreScope.read(context).removeRecipe(e.id);
    navigator.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? (_linked ? 'Recipe from a link' : 'My recipe') : 'Edit recipe'),
        actions: [
          if (widget.existing != null)
            IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_linked) ...[
              TextFormField(
                key: const ValueKey('field-link'),
                controller: _link,
                keyboardType: TextInputType.url,
                onChanged: _onLinkChanged,
                decoration: InputDecoration(
                  labelText: 'Link',
                  hintText: 'https://www.recipetineats.com/…',
                  suffixIcon: _reading
                      ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                      : TextButton(key: const ValueKey('read-link'), onPressed: _read, child: const Text('Read')),
                ),
                validator: (v) {
                  final uri = Uri.tryParse((v ?? '').trim());
                  return (uri == null || !uri.hasScheme || uri.host.isEmpty) ? 'Paste the recipe page link' : null;
                },
              ),
              if (_readMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_readMessage!, style: text.bodySmall),
                ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              key: const ValueKey('field-recipe-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('field-minutes'),
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Minutes (optional)'),
              validator: (v) => (v ?? '').trim().isEmpty || int.tryParse(v!.trim()) != null ? null : 'A whole number',
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('field-ingredients'),
              controller: _ingredients,
              minLines: 5,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Ingredients, one per line',
                helperText: 'Just the item, e.g. "chicken thighs". These are matched to your stock.',
                alignLabelWithHint: true,
              ),
              validator: (_) => ingredientProblem(_ingredientLines),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('field-method'),
              controller: _method,
              minLines: _linked ? 2 : 6,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: _linked ? 'Notes (optional)' : 'Method',
                helperText: _linked ? 'The method stays on the recipe page.' : null,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(key: const ValueKey('save-recipe'), onPressed: _save, child: const Text('Save recipe')),
          ],
        ),
      ),
    );
  }
}

/// Why a list of ingredient lines cannot be saved, or null if it can.
String? ingredientProblem(List<String> lines) {
  if (lines.isEmpty) return 'Add at least one ingredient';
  if (lines.length > RecipeEditorPage.maxIngredients) {
    return 'That is ${lines.length} lines, which looks like a whole web page. '
        'For a website recipe use From a link; otherwise one ingredient per line.';
  }
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].length > _RecipeEditorPageState.maxLineLength) {
      return 'Line ${i + 1} is very long. Put one ingredient on each line.';
    }
  }
  return null;
}
