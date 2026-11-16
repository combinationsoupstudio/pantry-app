import 'dart:io';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../data/household_store.dart';
import '../../data/open_food_facts.dart';
import '../../data/picture_cache.dart';
import '../../data/store_scope.dart';
import '../../models/models.dart';

/// One product's picture: the household's own photo first, then the product
/// picture (downloaded once, then read from the phone), else a plain tinted
/// square with the item's first letter, never a wrong picture.
class ProductPicture extends StatefulWidget {
  const ProductPicture({
    super.key,
    required this.name,
    this.photoPath,
    this.imageUrl,
    this.size = 44,
    this.dim = false,
    this.item,
  });

  /// The picture of a stock item. A scanned item with no picture yet has one
  /// looked up once, in the background.
  factory ProductPicture.of(StockItem item, {Key? key, double size = 44}) => ProductPicture(
    key: key,
    name: item.name,
    photoPath: item.photoPath,
    imageUrl: item.imageUrl,
    size: size,
    dim: item.isOut,
    item: item,
  );

  final String name;
  final String? photoPath;
  final String? imageUrl;
  final double size;

  /// Drawn faded (an item that has run out).
  final bool dim;
  final StockItem? item;

  @override
  State<ProductPicture> createState() => _ProductPictureState();
}

class _ProductPictureState extends State<ProductPicture> {
  Future<Uint8List?>? _bytes;
  String? _url;

  /// Items whose picture was already looked up this session.
  static final _triedBarcodes = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
    _backfill();
  }

  @override
  void didUpdateWidget(ProductPicture old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl) _load();
  }

  void _load() {
    _url = widget.imageUrl;
    _bytes = _url == null ? null : PictureCache.instance.bytesFor(_url!);
  }

  /// Items scanned before pictures existed (v0.4) get theirs by barcode.
  void _backfill() {
    final item = widget.item;
    final code = item?.barcode;
    if (item == null || code == null || item.imageUrl != null || !_triedBarcodes.add(code)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final HouseholdStore store = StoreScope.read(context);
      try {
        final info = await OpenFoodFacts.instance.lookup(code);
        final url = info?.imageUrl;
        if (url != null) await store.setPicture(item.id, url);
      } catch (_) {
        // No signal: tried again next time the app opens.
        _triedBarcodes.remove(code);
      }
    });
  }

  Widget _image(ImageProvider image) => Image(
    image: cacheWidthOf(image),
    width: widget.size,
    height: widget.size,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => _blank(context),
  );

  /// Decoded at about three times the drawn size: sharp, and small in memory.
  ImageProvider cacheWidthOf(ImageProvider image) => ResizeImage(image, width: (widget.size * 3).round());

  Widget _blank(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final letter = widget.name.trim().isEmpty ? '?' : widget.name.trim()[0].toUpperCase();
    return Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      color: scheme.secondaryContainer,
      child: Text(
        letter,
        style: TextStyle(fontSize: widget.size * 0.45, fontWeight: FontWeight.w800, color: scheme.onSecondaryContainer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget child;
    final own = widget.photoPath;
    if (own != null && File(own).existsSync()) {
      child = _image(FileImage(File(own)));
    } else if (_bytes != null) {
      child = FutureBuilder<Uint8List?>(
        future: _bytes,
        builder: (context, snap) => snap.data == null ? _blank(context) : _image(MemoryImage(snap.data!)),
      );
    } else {
      child = _blank(context);
    }
    if (widget.dim) {
      child = Opacity(
        opacity: 0.45,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.33, 0.33, 0.33, 0, 0, //
            0.33, 0.33, 0.33, 0, 0, //
            0.33, 0.33, 0.33, 0, 0, //
            0, 0, 0, 1, 0, //
          ]),
          child: child,
        ),
      );
    }
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(widget.size * 0.2),
        border: Border.all(color: scheme.outlineVariant, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// A pile of the same picture, one per item: 4 potatoes is four pictures,
/// fanned out, with "×4" on top. It grows as the amount goes up (up to five
/// shown; the badge always tells the true count).
class PicturePile extends StatelessWidget {
  const PicturePile({super.key, required this.picture, required this.count, this.size = 44, this.maxShown = 5});

  /// The room a full pile of [size] pictures takes, so rows line up however
  /// big each pile is.
  static double slotWidth(double size, {int maxShown = 5}) => size + (maxShown - 1) * size * 0.24 + 6;

  /// Builds one copy of the picture.
  final Widget Function() picture;
  final int count;
  final double size;
  final int maxShown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = count.clamp(1, maxShown);
    final step = size * 0.24;
    final width = size + (shown - 1) * step;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: width + 6,
      height: size + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown; i++)
            AnimatedPositioned(
              key: ValueKey('pile-copy-$i'),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              left: i * step,
              top: (shown - 1 - i) * 1.5,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.2),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(1, 1))],
                  ),
                  child: picture(),
                ),
              ),
            ),
          if (count > 1)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                key: const ValueKey('pile-count'),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '×$count',
                  style: TextStyle(color: scheme.onPrimary, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A stock item's pile: one picture per item or pack.
class ItemPile extends StatelessWidget {
  const ItemPile({super.key, required this.item, this.count, this.size = 44});
  final StockItem item;

  /// Draw this many instead of what is in stock (a shopping line).
  final int? count;
  final double size;

  @override
  Widget build(BuildContext context) => PicturePile(
    count: count ?? item.pileCount,
    size: size,
    picture: () => ProductPicture.of(item, size: size),
  );
}
