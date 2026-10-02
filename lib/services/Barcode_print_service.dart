import 'dart:typed_data';
import 'package:barcode/barcode.dart' as bc;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product.dart';

class BarcodePrintService {
  BarcodePrintService._();

  static const String brand = '     FIKRA';

  // ---------------------------------------------------------------------
  // LABEL SIZE - the real label stock: 49.0 mm wide x 24.0 mm long
  // (gap 2.0 mm, handled by the printer's gap sensor, NOT part of the
  // page). One PDF page == exactly one physical label.
  //
  // WHY YOU GOT "1 PRINTED + 1 BLANK" LABEL:
  //  1. The page used to be 25 mm wide x 50 mm long. Each page was
  //     therefore twice the label length (50 mm vs 24 mm + 2 mm gap), so
  //     the printer printed on the first label and fed a second, empty
  //     label to finish the page.
  //  2. Simply changing it to 49 x 24 is NOT enough with the `printing`
  //     plugin on Windows: when width > height it switches the job to
  //     LANDSCAPE and swaps the values, sending paper width 24 mm and
  //     paper LENGTH 49 mm to the driver - again about 2 labels per page.
  //     That is why `usePrinterSettings: true` is used below: the plugin
  //     then leaves the driver's own (calibrated 49 x 24) stock untouched.
  //
  // This is a PDF print job: no text, "\n" or form-feed (\f) characters
  // are ever sent to the printer, so stray line feeds were not the cause.
  // ---------------------------------------------------------------------
  static const double _labelWidthMm = 49.0;
  static const double _labelHeightMm = 24.0;

  /// Keep true. Only set to false if a particular driver ignores its own
  /// stock settings with it (then the plugin's landscape swap described
  /// above applies again).
  static const bool _useDriverPaperSettings = true;

  // Inner safety margins (inside the label) so nothing touches the die-
  // cut edge. Content is also hard-limited to the label box (see
  // _buildLabelContent), so it can never overflow into a second label.
  static const double _padHorizontalMm = 1.5;
  static const double _padVerticalMm = 1.0;

  static PdfPageFormat get _labelFormat => const PdfPageFormat(
        _labelWidthMm * PdfPageFormat.mm,
        _labelHeightMm * PdfPageFormat.mm,
        marginAll: 0,
      );

  static Future<bool> printProductLabels({
    required BuildContext context,
    required Product product,
    required int copies,
  }) async {
    if (copies <= 0) return false;

    final printers = await Printing.listPrinters();

    if (printers.isEmpty) {
      throw StateError(
        'لا توجد طابعة متصلة بالجهاز. الرجاء التأكد من توصيل الطابعة وتشغيلها.',
      );
    }

    final targetPrinter = printers.firstWhere(
      (printer) => printer.isDefault,
      orElse: () => printers.first,
    );

    final barcodeData = product.barcode.trim().isNotEmpty
        ? product.barcode.trim()
        : product.name.trim();

    // Exactly `copies` pages -> exactly `copies` labels. The PDF is
    // built once; the layout callback below always returns it unchanged,
    // whatever page size the driver reports.
    final pdfData = await _buildLabelsPdf(
      productName: product.name.trim(),
      barcodeData: barcodeData,
      sellPrice: product.sellPrice,
      copies: copies,
    );

    return Printing.directPrintPdf(
      printer: targetPrinter,
      onLayout: (_) async => pdfData,
      name: 'Barcode - ${product.name.trim()} x$copies',
      format: _labelFormat,
      // See the explanation at the top of this class: keeps the driver's
      // calibrated 49 x 24 mm stock instead of the plugin's swapped
      // landscape paper size, which made every page ~2 labels long.
      usePrinterSettings: _useDriverPaperSettings,
    );
  }

  static Future<Uint8List> _buildLabelsPdf({
    required String productName,
    required String barcodeData,
    required double sellPrice,
    required int copies,
  }) async {
    final doc = pw.Document();

    final fontData = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/Tajawal-Bold.ttf');

    final ttf = pw.Font.ttf(fontData);
    final ttfBold = pw.Font.ttf(boldFontData);

    final labelFormat = _labelFormat;

    for (int i = 0; i < copies; i++) {
      // pw.Page (not MultiPage): one page per label, never split or
      // continued onto an extra page.
      doc.addPage(
        pw.Page(
          pageFormat: labelFormat,
          margin: pw.EdgeInsets.zero,
          build: (context) => _buildLabelContent(
            productName: productName,
            barcodeData: barcodeData,
            sellPrice: sellPrice,
            font: ttf,
            boldFont: ttfBold,
          ),
        ),
      );
    }

    return doc.save();
  }

  // ---------------------------------------------------------------------
  // VISUAL DESIGN / BARCODE READABILITY (layout only - the page size and
  // printer settings above are untouched).
  // ---------------------------------------------------------------------

  /// Resolution of the label printer. 203 dpi is the standard for 49 mm
  /// thermal label printers. If yours is 300 dpi, change this to 300.
  static const double _printerDpi = 203;

  /// Size of one printer dot in mm (0.125 mm at 203 dpi).
  static const double _dotMm = 25.4 / _printerDpi;

  /// Minimum quiet zone (blank space) on each side of the barcode, in
  /// modules. The Code 128 standard requires at least 10.
  static const int _quietZoneModules = 10;

  /// Widest module used (3 dots = 0.375 mm). Narrower is chosen
  /// automatically for long codes so the barcode + quiet zones fit.
  static const int _maxDotsPerModule = 3;

  /// Snaps a length in mm to the nearest whole number of printer dots,
  /// so bar edges land exactly on the printer's dot grid.
  static double _snap(double mm) => (mm / _dotMm).round() * _dotMm;

  /// Number of Code 128 modules (narrowest bar units) for [data].
  /// Read from the barcode package itself: the narrowest bar or space it
  /// produces is exactly one module.
  static int _moduleCount(bc.Barcode barcode, String data) {
    const double probeWidth = 10000;
    double narrowest = probeWidth;
    for (final element in barcode.make(data, width: probeWidth, height: 10, drawText: false)) {
      if (element is bc.BarcodeBar && element.width > 0 && element.width < narrowest) {
        narrowest = element.width;
      }
    }
    return (probeWidth / narrowest).round();
  }

  /// Label layout for 49 x 24 mm:
  ///
  ///   +-----------------------------------------------+
  ///   |                 product name                  |
  ///   |      ||| |||| || ||| barcode ||| || ||||      |
  ///   |   quiet       1 2 3 4 5 6 7 8 9       quiet   |
  ///   |  FIKRA                           [ 12.50 ]    |
  ///   +-----------------------------------------------+
  ///
  /// Every element is placed at a fixed position (Stack/Positioned), so
  /// nothing can push the layout past 24 mm, and the barcode is never
  /// scaled after its size was chosen:
  ///  * each module is a WHOLE number of printer dots (2 dots = 0.25 mm
  ///    whenever the code fits), so all bars print crisp and even;
  ///  * at least 10 modules of white space on both sides (quiet zones);
  ///  * pure black only - colours/grey turn into fuzzy dot patterns on a
  ///    thermal printer and hurt readability.
  static pw.Widget _buildLabelContent({
    required String productName,
    required String barcodeData,
    required double sellPrice,
    required pw.Font font,
    required pw.Font boldFont,
  }) {
    const double mm = PdfPageFormat.mm;
    const double sideMm = _padHorizontalMm; // safe distance from the edges
    const double innerWidthMm = _labelWidthMm - 2 * sideMm;

    // ---------------- Barcode geometry ----------------
    final barcode = bc.Barcode.code128();
    if (!barcode.isValid(barcodeData)) {
      throw StateError(
        'لا يمكن طباعة باركود لهذا المنتج: الباركود "$barcodeData" يحتوي على أحرف غير مدعومة. '
        'استخدم أرقاماً أو حروفاً إنجليزية فقط.',
      );
    }
    final int modules = _moduleCount(barcode, barcodeData);

    // Widest whole-dot module that still fits WITH both quiet zones.
    int dotsPerModule = _maxDotsPerModule;
    while (dotsPerModule > 1 &&
        (modules + 2 * _quietZoneModules) * dotsPerModule * _dotMm > innerWidthMm) {
      dotsPerModule--;
    }
    final double moduleMm = dotsPerModule * _dotMm;
    final double barcodeWidthMm = modules * moduleMm;
    // Centered, with its left edge on the dot grid.
    final double barcodeLeftMm = _snap((_labelWidthMm - barcodeWidthMm) / 2);

    // ---------------- Vertical rhythm (mm) ----------------
    const double nameH = 3.6;
    const double gapNameBarcode = 0.7;
    final double barcodeH = _snap(8.6);
    const double gapBarcodeDigits = 0.4;
    const double digitsH = 2.4;
    const double gapDigitsFooter = 0.7;
    const double footerH = 4.0;

    final double contentH = nameH +
        gapNameBarcode +
        barcodeH +
        gapBarcodeDigits +
        digitsH +
        gapDigitsFooter +
        footerH;
    // Center the whole block vertically, never closer than the padding.
    double top = (_labelHeightMm - contentH) / 2;
    if (top < _padVerticalMm) top = _padVerticalMm;

    final double nameTop = top;
    final double barcodeTop = _snap(nameTop + nameH + gapNameBarcode);
    final double digitsTop = barcodeTop + barcodeH + gapBarcodeDigits;
    final double footerTop = digitsTop + digitsH + gapDigitsFooter;

    // Long product names get a slightly smaller font, then shrink to fit.
    final int nameLength = productName.length;
    final double nameFontSize = nameLength <= 18 ? 8.5 : (nameLength <= 28 ? 7.5 : 6.5);

    // A text row of fixed size: centered, shrunk (never enlarged) to fit.
    pw.Widget fitted(pw.Widget child, double widthMm, double heightMm,
        {pw.Alignment alignment = pw.Alignment.center}) {
      return pw.SizedBox(
        width: widthMm * mm,
        height: heightMm * mm,
        child: pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: alignment,
          child: child,
        ),
      );
    }

    final priceBox = pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 1.4 * mm, vertical: 0.2 * mm),
      decoration: pw.BoxDecoration(
        color: PdfColors.black,
        borderRadius: pw.BorderRadius.circular(0.8 * mm),
      ),
      child: pw.Text(
        sellPrice.toStringAsFixed(2),
        style: pw.TextStyle(
          font: boldFont,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );

    return pw.SizedBox(
      width: _labelWidthMm * mm,
      height: _labelHeightMm * mm,
      child: pw.ClipRect(
        child: pw.Stack(
          children: [
            // 1) Product name (Arabic -> RTL), bold, centered.
            pw.Positioned(
              left: sideMm * mm,
              top: nameTop * mm,
              child: fitted(
                pw.Directionality(
                  textDirection: pw.TextDirection.rtl,
                  child: pw.Text(
                    productName,
                    maxLines: 1,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: nameFontSize,
                      color: PdfColors.black,
                    ),
                  ),
                ),
                innerWidthMm,
                nameH,
              ),
            ),

            // 2) Barcode: exact whole-dot modules, never rescaled. The
            //    space left and right of it stays white (quiet zones).
            pw.Positioned(
              left: barcodeLeftMm * mm,
              top: barcodeTop * mm,
              child: pw.BarcodeWidget(
                barcode: barcode,
                data: barcodeData,
                width: barcodeWidthMm * mm,
                height: barcodeH * mm,
                drawText: false,
                color: PdfColors.black,
              ),
            ),

            // 3) Human-readable code under the barcode (always LTR).
            pw.Positioned(
              left: sideMm * mm,
              top: digitsTop * mm,
              child: fitted(
                pw.Directionality(
                  textDirection: pw.TextDirection.ltr,
                  child: pw.Text(
                    barcodeData,
                    maxLines: 1,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 6,
                      letterSpacing: 0.8,
                      color: PdfColors.black,
                    ),
                  ),
                ),
                innerWidthMm,
                digitsH,
              ),
            ),

            // 4) Footer: brand on the left, price badge on the right.
            pw.Positioned(
              left: sideMm * mm,
              top: footerTop * mm,
              child: fitted(
                pw.Text(
                  brand,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.6,
                    color: PdfColors.black,
                  ),
                ),
                innerWidthMm / 2,
                footerH,
                alignment: pw.Alignment.centerLeft,
              ),
            ),
            pw.Positioned(
              left: (sideMm + innerWidthMm / 2) * mm,
              top: footerTop * mm,
              child: fitted(
                priceBox,
                innerWidthMm / 2,
                footerH,
                alignment: pw.Alignment.centerRight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}