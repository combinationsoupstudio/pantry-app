import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/household_store.dart';
import '../../data/open_food_facts.dart' show parsePackSize;
import '../../data/store_scope.dart';
import '../../logic/amounts.dart';
import '../../logic/receipt_parse.dart';
import '../../models/models.dart';
import '../theme.dart';

/// Scan a receipt: take a photo (or pick one), read its text on the phone
/// (Google ML Kit, nothing sent anywhere), then open the review page. A tall
/// image (a saved e-receipt) is read in overlapping sections at full size.
Future<void> scanReceipt(BuildContext context, {ImageSource source = ImageSource.camera}) async {
  final shot = await ImagePicker().pickImage(source: source, imageQuality: 95);
  if (shot == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('Reading the receipt…'), duration: Duration(seconds: 20)));
  final reader = TextRecognizer(script: TextRecognitionScript.latin);
  final temp = <File>[];
  try {
    final boxes = <TextBox>[];
    Future<void> read(String path, {double dy = 0, bool Function(double middle)? keep}) async {
      final found = await reader.processImage(InputImage.fromFilePath(path));
      for (final block in found.blocks) {
        for (final line in block.lines) {
          final r = line.boundingBox;
          final box = TextBox(line.text, left: r.left, top: r.top + dy, right: r.right, bottom: r.bottom + dy);
          if (keep == null || keep(box.middle)) boxes.add(box);
        }
      }
    }

    final bytes = await File(shot.path).readAsBytes();
    final image = await compute(img.decodeImage, bytes);
    final spans = image == null ? const [(0, 0)] : receiptSpans(image.width, image.height);
    if (image == null || spans.length == 1) {
      await read(shot.path);
    } else {
      final dir = await getTemporaryDirectory();
      for (var i = 0; i < spans.length; i++) {
        final (top, height) = spans[i];
        final part = img.copyCrop(image, x: 0, y: top, width: image.width, height: height);
        final f = File('${dir.path}/receipt-part-$i.jpg')..writeAsBytesSync(img.encodeJpg(part, quality: 92));
        temp.add(f);
        await read(f.path, dy: top.toDouble(), keep: (m) => keepInSpan(m, i, spans));
      }
    }

    final rows = rowsOf(boxes);
    final receipt = parseReceipt(rows);
    messenger.hideCurrentSnackBar();
    if (!context.mounted) return;
    if (receipt.lines.isEmpty) {
      await _whatItSaw(
        context,
        rows.isEmpty
            ? 'No text was found in the picture. Try a sharper photo, flat, in good light.'
            : 'Text was found but no lines with prices. This is what it read:',
        rows,
      );
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReceiptPage(receipt: receipt)));
  } catch (e) {
    messenger.hideCurrentSnackBar();
    if (context.mounted) await _whatItSaw(context, 'Could not read the receipt: $e', const []);
  } finally {
    await reader.close();
    for (final f in temp) {
      if (f.existsSync()) f.deleteSync();
    }
  }
}

/// Shows what went wrong, and the text read, with a Copy button so it can be
/// sent on and the reader tuned.
Future<void> _whatItSaw(BuildContext context, String message, List<String> rows) => showDialog<void>(
  context: context,
  builder: (c) => AlertDialog(
    title: const Text('Could not read that receipt'),
    content: SizedBox(
      width: double.maxFinite,
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(message, key: const ValueKey('receipt-problem')),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(rows.join('\n'), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Clipboard.setData(ClipboardData(text: '$message\n${rows.join('\n')}')),
        child: const Text('Copy'),
      ),
      FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
    ],
  ),
);

class _Line {
  _Line(this.name, this.total, this.quantity, this.unit, this.stock, this.packOf, this.size) {
    toStock = stock != null && stockAmount != null;
  }

  /// The pack size printed in the name ("600ML"), if any.
  final (double, String)? size;

  /// "12pk" on the receipt: how many each pack holds.
  final int? packOf;
  String name;
  double total;
  double quantity;
  final String unit;
  StockItem? stock;
  late bool toStock;
  bool keep = true;

  /// How many to add per pack bought: the pack count, for a counted item.
  double get perPack {
    final s = stock;
    if (s == null || packOf == null || s.isMeasured || isMeasureUnit(s.unit)) return 1;
    return packOf!.toDouble();
  }

  /// What goes into stock in the item's own unit, or null when the receipt
  /// line cannot be turned into it (1.25 kg of potatoes counted as items).
  double? get stockAmount {
    final s = stock;
    if (s == null) return null;
    if (isMeasureUnit(unit)) return convertUnits(quantity, unit, s.unit);
    final printed = size == null ? null : convertUnits(size!.$1, size!.$2, s.unit);
    if (s.isMeasured) return quantity * (printed ?? s.packSize);
    if (isMeasureUnit(s.unit)) return printed == null ? null : quantity * printed;
    return quantity * perPack;
  }

  /// What goes into stock, as the chip says it ("+12", "+600 ml").
  String get adds {
    final s = stock!;
    final a = stockAmount;
    if (a == null) return '(${formatMeasure(quantity, unit)} into ${s.unit.isEmpty ? 'a count' : s.unit}: add by hand)';
    final u = s.unit.isEmpty || s.unit == 'items' ? '' : s.unit;
    return '+${formatMeasure(double.parse(a.toStringAsFixed(3)), u)}';
  }
}

/// Check what was read before it is saved: shop, date, each line (its name,
/// how many, the price, which stock item it is, and whether it goes into
/// stock), and whether the lines add up to the receipt's total.
class ReceiptPage extends StatefulWidget {
  const ReceiptPage({super.key, required this.receipt});
  final Receipt receipt;

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  late Store _store = widget.receipt.store;
  late DateTime _date = widget.receipt.date ?? DateTime.now();
  List<_Line>? _lines;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lines ??= [
      for (final l in widget.receipt.lines)
        _Line(
          tidyName(l.name),
          l.total,
          l.quantity,
          l.unit,
          matchStock(l.name, StoreScope.read(context).items),
          packCount(l.name),
          parsePackSize(l.name),
        ),
    ];
  }

  Future<void> _edit(_Line l) async {
    final name = TextEditingController(text: l.name);
    final price = TextEditingController(text: l.total.toStringAsFixed(2));
    final qty = TextEditingController(text: formatQty(l.quantity));
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Fix this line'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'How many', suffixText: l.unit),
            ),
            TextField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price', prefixText: r'$'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Done')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      l.name = name.text.trim().isEmpty ? l.name : name.text.trim();
      l.total = double.tryParse(price.text.replaceAll(',', '.')) ?? l.total;
      l.quantity = double.tryParse(qty.text.replaceAll(',', '.')) ?? l.quantity;
    });
  }

  Future<void> _pickStock(_Line l) async {
    final items = [...StoreScope.read(context).items]..sort((a, b) => a.name.compareTo(b.name));
    final picked = await showModalBottomSheet<StockItem?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => FractionallySizedBox(
        heightFactor: 0.8,
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Not in stock (price only)'),
              onTap: () => Navigator.pop(c, null),
            ),
            for (final i in items) ListTile(title: Text(i.name), onTap: () => Navigator.pop(c, i)),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      l.stock = picked;
      l.toStock = picked != null && l.stockAmount != null;
    });
  }

  Future<void> _save() async {
    final store = StoreScope.read(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final kept = _lines!.where((l) => l.keep).toList();
    final now = DateTime.now();
    final n = await store.recordReceipt(
      store: _store,
      at: DateTime(_date.year, _date.month, _date.day, now.hour, now.minute),
      lines: [
        for (final l in kept)
          ReceiptEntry(
            name: l.name,
            total: l.total,
            quantity: l.quantity,
            unit: l.unit,
            stockItemId: l.stock?.id,
            toStock: l.toStock,
            perPack: l.perPack,
            stockAmount: l.stockAmount,
          ),
      ],
    );
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text('Receipt saved: ${kept.length} prices, $n into stock')));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    final lines = _lines!;
    final sum = lines.where((l) => l.keep).fold(0.0, (a, l) => a + l.total);
    final said = widget.receipt.total;
    final addsUp = said != null && (sum - said).abs() < 0.06;

    return Scaffold(
      appBar: AppBar(title: const Text('Check the receipt')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<Store>(
                  isExpanded: true,
                  initialValue: _store,
                  decoration: const InputDecoration(labelText: 'Shop'),
                  items: [for (final s in Store.values) DropdownMenuItem(value: s, child: Text(s.label))],
                  onChanged: (v) => setState(() => _store = v ?? _store),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text('${_date.day}/${_date.month}/${_date.year}'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('receipt-check'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: addsUp ? status.okContainer : status.lowContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              said == null
                  ? 'Lines add to \$${sum.toStringAsFixed(2)}. The total could not be read: check against the receipt.'
                  : addsUp
                  ? 'Lines add to \$${sum.toStringAsFixed(2)}: matches the receipt total.'
                  : 'Lines add to \$${sum.toStringAsFixed(2)}; the receipt says \$${said.toStringAsFixed(2)}. '
                        'A line may be missed or misread: tap one to fix it.',
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: status.onContainer),
            ),
          ),
          const SizedBox(height: 8),
          for (final (k, l) in lines.indexed)
            Card(
              key: ValueKey('receipt-line-$k'),
              child: Opacity(
                opacity: l.keep ? 1 : 0.45,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(value: l.keep, onChanged: (v) => setState(() => l.keep = v ?? true)),
                          Expanded(
                            child: InkWell(
                              onTap: () => _edit(l),
                              child: Text(l.name, style: text.titleSmall),
                            ),
                          ),
                          Text(
                            '${l.quantity == 1 && l.unit.isEmpty ? '' : '${formatQty(l.quantity)}${l.unit} · '}\$${l.total.toStringAsFixed(2)}',
                            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ActionChip(
                              key: ValueKey('receipt-stock-$k'),
                              avatar: Icon(l.stock == null ? Icons.link_off : Icons.inventory_2_outlined, size: 18),
                              label: Text(l.stock?.name ?? 'Not in stock'),
                              onPressed: () => _pickStock(l),
                            ),
                            if (l.stock != null)
                              FilterChip(
                                key: ValueKey('receipt-tostock-$k'),
                                label: Text('Add to stock ${l.adds}'),
                                selected: l.toStock,
                                onSelected: l.stockAmount == null ? null : (v) => setState(() => l.toStock = v),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Untick a line to leave it out. Prices go into price memory and this week\'s spend.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            key: const ValueKey('receipt-save'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _save,
            icon: const Icon(Icons.receipt_long),
            label: Text('Save receipt (\$${sum.toStringAsFixed(2)})'),
          ),
        ),
      ),
    );
  }
}
