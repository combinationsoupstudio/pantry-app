import 'dart:io';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../data/picture_cache.dart';
import '../../models/models.dart';
import 'item_look.dart';

/// One product's picture: the household's own photo first, then the product
/// picture (downloaded once, then read from the phone), else an icon for what
/// it is on its family's colour (item_look.dart), never a wrong picture.
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

  /// The picture of a stock item. Items with none get one from the
  /// background PictureFinder.
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

  @override
  void initState() {
    super.initState();
    _load();
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
    final b = Theme.of(context).brightness;
    final look = lookFor(widget.name, locationId: widget.item?.locationId);
    return Container(
      key: const ValueKey('picture-icon'),
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      color: look.family.bg(b),
      child: Icon(look.icon, size: widget.size * 0.52, color: look.family.fg(b)),
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
        borderRadius: BorderRadius.circular(widget.size * 0.24),
        border: Border.all(color: scheme.outlineVariant, width: 1),
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
