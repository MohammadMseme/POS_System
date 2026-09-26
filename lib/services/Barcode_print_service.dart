import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product.dart';

class BarcodePrintService {
  BarcodePrintService._();

  static const String brand = 'FIKRA';

  // ---------------------------------------------------------------------
  // ⚠️ LABEL SIZE - MUST MATCH YOUR PHYSICAL LABEL STOCK AND THE LABEL
  // SIZE CONFIGURED IN THE PRINTER'S WINDOWS DRIVER, EXACTLY.
  //
  // If these numbers are taller/wider than the real label pitch the
  // printer is configured for (or than the actual label roll), the
  // printer's own feed/gap sensor will advance by ITS configured pitch
  // regardless of what height we request here - e.g. asking for a 50mm
  // page when the driver/roll is really 25mm means the printer feeds a
  // second, empty 25mm label to make up the "missing" half of our page.
  // That is the single most common cause of a printer that alternates
  // one printed label / one blank label, and it cannot be fixed from
  // Dart code - only by matching this value to your real hardware and/or
  // the label size set in the printer's Windows properties.
  //
  // The second most common cause of the exact same symptom is the
  // printer driver defaulting to double-sided (duplex) printing on
  // single-sided label stock - every physical label then becomes the
  // "front" of one logical page and the "back" of another, and the back
  // page is the blank one you're seeing. Check "Print on both sides" is
  // OFF in the printer's Windows properties; `printing`'s cross-platform
  // API has no duplex override to force this from here.
  // ---------------------------------------------------------------------
  static const double _labelWidthMm = 25;
  static const double _labelHeightMm = 50;

  static Future<bool> printProductLabels({
    required BuildContext context,
    required Product product,
    required int copies,
  }) async {
    if (copies <= 0) return false;

    final printers = await Printing.listPrinters();

    if (printers.isEmpty) {
      // FIX: this used to fall through to a catch-all and return
      // `false` - indistinguishable, to the caller, from the user
      // simply cancelling the print dialog. Throwing here instead lets
      // products_screen.dart's real error branch show this exact
      // message, rather than a misleading "تم إلغاء عملية الطباعة".
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

    // FIX: no more blanket try/catch here. Any real failure building the
    // PDF (e.g. a missing/corrupt font asset) or sending the job now
    // propagates to the caller as a genuine exception instead of being
    // silently swallowed and reported as a cancellation.
    final pdfData = await _buildLabelsPdf(
      productName: product.name,
      barcodeData: barcodeData,
      sellPrice: product.sellPrice,
      copies: copies,
    );

    return Printing.directPrintPdf(
      printer: targetPrinter,
      onLayout: (_) async => pdfData,
      name: 'Barcode - ${product.name} x$copies',
      // NOTE: `marginAll` removed here - it has no effect on the actual
      // printed content margin (that's controlled by the `pw.Page(margin:
      // EdgeInsets.zero)` below) and doesn't reach the OS's paper-size
      // negotiation either, so specifying it on this particular
      // PdfPageFormat was dead/misleading code.
      format: PdfPageFormat(
        _labelWidthMm * PdfPageFormat.mm,
        _labelHeightMm * PdfPageFormat.mm,
      ),
    );
  }

  static Future<Uint8List> _buildLabelsPdf({
    required String productName,
    required String barcodeData,
    required double sellPrice,
    required int copies,
  }) async {
    final doc = pw.Document();

    final fontData = await rootBundle.load(
      'assets/fonts/Tajawal-Regular.ttf',
    );

    final boldFontData = await rootBundle.load(
      'assets/fonts/Tajawal-Bold.ttf',
    );

    final ttf = pw.Font.ttf(fontData);
    final ttfBold = pw.Font.ttf(boldFontData);

    final labelPageFormat = PdfPageFormat(
      _labelWidthMm * PdfPageFormat.mm,
      _labelHeightMm * PdfPageFormat.mm,
      marginAll: 0,
    );

    for (int i = 0; i < copies; i++) {
      doc.addPage(
        pw.Page(
          pageFormat: labelPageFormat,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return _buildLabelContent(
              productName: productName,
              barcodeData: barcodeData,
              sellPrice: sellPrice,
              font: ttf,
              boldFont: ttfBold,
            );
          },
        ),
      );
    }

    return doc.save();
  }

  static pw.Widget _buildLabelContent({
    required String productName,
    required String barcodeData,
    required double sellPrice,
    required pw.Font font,
    required pw.Font boldFont,
  }) {
    return pw.Container(
      width: _labelWidthMm * PdfPageFormat.mm,
      height: _labelHeightMm * PdfPageFormat.mm,
      padding: const pw.EdgeInsets.only(
        top: 6,
        bottom: 2,
        left: 2,
        right: 2,
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            brand,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 5.5,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.1,
              color: PdfColors.blue900,
            ),
          ),

          pw.SizedBox(height: 2),

          pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data: barcodeData,
            width: 19 * PdfPageFormat.mm,
            height: 9 * PdfPageFormat.mm,
            drawText: false,
          ),

          // NEW: human-readable barcode text, right under the barcode
          // with its own small quiet-zone gap so it never touches the
          // bars. Forced LTR regardless of any surrounding context - a
          // barcode value is a plain numeric/alphanumeric code, never
          // Arabic prose, so it must NEVER go through the word-reversal
          // logic used for the product name below; reversing it would
          // make the printed digits wrong.
          pw.SizedBox(height: 1),

          pw.Directionality(
            textDirection: pw.TextDirection.ltr,
            child: pw.Text(
              barcodeData,
              textAlign: pw.TextAlign.center,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                font: font,
                fontSize: 6,
                color: PdfColors.grey700,
              ),
            ),
          ),

          pw.SizedBox(height: 2),

          // Product name - UNCHANGED from the verified, working version:
          // same RTL Directionality wrapper, same Tajawal font, same
          // sizing. Not touched, per instructions.
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Text(
              productName,
              textAlign: pw.TextAlign.center,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 7.5,
              ),
            ),
          ),

          pw.SizedBox(height: 2),

          // NEW: selling price - bold and a touch larger so it's the
          // second thing the eye catches after the product name, with
          // 2 decimal places and the shekel symbol to match the currency
          // formatting used everywhere else in the app.
          pw.Text(
            '${sellPrice.toStringAsFixed(2)} ',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ],
      ),
    );
  }
}