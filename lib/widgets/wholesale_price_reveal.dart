import 'package:flutter/material.dart';

/// Shows a selling price that, when tapped, reveals the product's
/// optional wholesale price (سعر الجملة) right next to / under it.
///
/// The wholesale price is a private reference for the seller (to help
/// decide a manual discount). It is hidden by default so customers
/// looking at the screen don't see it, and this widget never feeds it
/// into any calculation.
///
/// When [wholesalePrice] is null or <= 0 the price is rendered as plain,
/// non-tappable text - exactly like before this feature.
class WholesalePriceReveal extends StatefulWidget {
  /// The already-formatted selling price text, e.g. "25.00 ₪".
  final String priceText;
  final TextStyle? priceStyle;
  final double? wholesalePrice;

  /// Currency label appended to the revealed wholesale price.
  final String currency;

  /// true: the wholesale chip appears under the price (narrow cells).
  /// false: it appears to the side of the price (table rows).
  final bool vertical;

  final TextAlign textAlign;

  const WholesalePriceReveal({
    super.key,
    required this.priceText,
    required this.wholesalePrice,
    this.priceStyle,
    this.currency = '₪',
    this.vertical = false,
    this.textAlign = TextAlign.start,
  });

  @override
  State<WholesalePriceReveal> createState() => _WholesalePriceRevealState();
}

class _WholesalePriceRevealState extends State<WholesalePriceReveal> {
  bool _revealed = false;

  bool get _hasWholesale =>
      widget.wholesalePrice != null && widget.wholesalePrice! > 0;

  @override
  Widget build(BuildContext context) {
    final priceText = Text(
      widget.priceText,
      style: widget.priceStyle,
      textAlign: widget.textAlign,
    );

    if (!_hasWholesale) return priceText;

    final hint = Icon(
      _revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      size: 12,
      color: Colors.teal.shade400,
    );

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
      ),
      child: Text(
        'جملة: ${widget.wholesalePrice!.toStringAsFixed(2)} ${widget.currency}',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: Colors.teal.shade700,
        ),
      ),
    );

    // Vertical mode is used inside fixed-width cells, so the price may
    // shrink (Flexible). Horizontal mode is used where the parent may give
    // unbounded width (table cells, self-sized columns), so it must not
    // use flex children at all.
    final Widget content = widget.vertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: priceText),
                  const SizedBox(width: 3),
                  hint,
                ],
              ),
              if (_revealed) ...[const SizedBox(height: 3), chip],
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              priceText,
              const SizedBox(width: 3),
              hint,
              if (_revealed) ...[const SizedBox(width: 6), chip],
            ],
          );

    return Tooltip(
      message: _revealed ? 'إخفاء سعر الجملة' : 'اضغط لإظهار سعر الجملة',
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => _revealed = !_revealed),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: content,
        ),
      ),
    );
  }
}
