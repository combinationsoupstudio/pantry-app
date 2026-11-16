import 'package:material_ui/material_ui.dart';

import 'common.dart';

import '../../data/open_food_facts.dart';
import 'pictures.dart';

/// "Find picture": searches Australian products on Open Food Facts by name
/// and shows them with their pictures and pack sizes, so the right one (the
/// 2 kg bag, not the 5 kg) can be picked. Returns the product picked.
Future<ProductInfo?> showPictureSearch(BuildContext context, {String initial = ''}) =>
    showModalBottomSheet<ProductInfo>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.9, child: _PictureSearch(initial: initial)),
    );

class _PictureSearch extends StatefulWidget {
  const _PictureSearch({required this.initial});
  final String initial;

  @override
  State<_PictureSearch> createState() => _PictureSearchState();
}

class _PictureSearchState extends State<_PictureSearch> {
  late final _query = TextEditingController(text: widget.initial);
  List<ProductInfo>? _results;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial.trim().length >= 2) _search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final found = await OpenFoodFacts.instance.search(q);
      if (!mounted) return;
      setState(() {
        _results = rankByName(q, found);
        if (found.isEmpty) _message = 'Nothing found in Australia for "$q". Try fewer words, or take a photo.';
      });
    } on LookupFailed catch (e) {
      if (mounted) setState(() => _message = '$e. Try again when you have signal.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final results = _results ?? const <ProductInfo>[];
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, sheetBottom(context, extra: 0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Find a picture', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('Pick the one that matches your pack and size.', style: text.bodyMedium),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('picture-query'),
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Product',
              hintText: 'e.g. washed potatoes',
              suffixIcon: IconButton(tooltip: 'Search', icon: const Icon(Icons.search), onPressed: _search),
            ),
          ),
          const SizedBox(height: 12),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_message!, style: text.bodyMedium),
            ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.62,
              ),
              itemCount: results.length,
              itemBuilder: (context, i) {
                final p = results[i];
                return Card(
                  key: ValueKey('picture-result-$i'),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(p),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: ProductPicture(name: p.displayName, imageUrl: p.imageUrl, size: 88),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p.displayName,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          if (p.quantityText.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p.quantityText,
                                style: text.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Pictures: Open Food Facts, CC BY-SA 3.0',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
