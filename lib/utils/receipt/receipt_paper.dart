import 'package:mombongo/services/database_service.dart';
import 'package:pdf/pdf.dart';

/// Largeurs de rouleau thermique supportées par l'application.
enum ReceiptPaperSize { mm58, mm80 }

/// Dimensions de la page PDF générée pour une largeur de rouleau.
///
/// IMPORTANT : ces valeurs ne correspondent PAS à la largeur physique du
/// papier. Le service d'impression Android redimensionne la page PDF pour la
/// faire tenir dans la zone imprimable du rouleau. Les valeurs 58 mm
/// (page 70 mm, marges 8 mm) ont été calibrées sur le terrain : texte lisible
/// et rien n'est coupé. Le profil 80 mm reprend le même calibrage, agrandi
/// dans le rapport 80/58. Pour ajuster après un test d'impression, il suffit
/// de modifier les constantes ci-dessous.
class ReceiptPaperSpec {
  const ReceiptPaperSpec({
    required this.pageWidthMm,
    required this.marginMm,
    required this.qtyColumnWidth,
    required this.amountColumnWidth,
    required this.scale,
  });

  /// Largeur de la page PDF (mm).
  final double pageWidthMm;

  /// Marge appliquée sur les 4 côtés (mm).
  final double marginMm;

  /// Largeur de la colonne « Qté » du tableau des articles (points PDF).
  final double qtyColumnWidth;

  /// Largeur de la colonne montant du tableau des articles (points PDF).
  final double amountColumnWidth;

  /// Facteur d'agrandissement par rapport au calibrage 58 mm
  /// (utilisé pour la hauteur du logo).
  final double scale;

  /// Format de page pour une hauteur donnée (mm).
  PdfPageFormat pageFormat(double heightMm) {
    return PdfPageFormat(
      pageWidthMm * PdfPageFormat.mm,
      heightMm * PdfPageFormat.mm,
      marginLeft: marginMm * PdfPageFormat.mm,
      marginRight: marginMm * PdfPageFormat.mm,
      marginTop: marginMm * PdfPageFormat.mm,
      marginBottom: marginMm * PdfPageFormat.mm,
    );
  }
}

/// Calibrage 58 mm : valeurs historiques de Mombongo, à ne pas changer.
const ReceiptPaperSpec _spec58 = ReceiptPaperSpec(
  pageWidthMm: 70,
  marginMm: 8,
  qtyColumnWidth: 20,
  amountColumnWidth: 35,
  scale: 1.0,
);

/// Calibrage 80 mm : calibrage 58 mm agrandi d'environ 80/58 (×1,38).
const ReceiptPaperSpec _spec80 = ReceiptPaperSpec(
  pageWidthMm: 96,
  marginMm: 11,
  qtyColumnWidth: 26,
  amountColumnWidth: 48,
  scale: 1.38,
);

extension ReceiptPaperSizeX on ReceiptPaperSize {
  /// Libellé affiché à l'utilisateur.
  String get label => this == ReceiptPaperSize.mm80 ? '80 mm' : '58 mm';

  /// Dimensions PDF associées.
  ReceiptPaperSpec get spec =>
      this == ReceiptPaperSize.mm80 ? _spec80 : _spec58;
}

/// Lecture / écriture de la largeur de papier préférée (stockage Hive).
class ReceiptPaperPreference {
  ReceiptPaperPreference._();

  static const String prefKey = 'pref_receipt_paper_size';

  /// Par défaut : 58 mm (comportement historique de l'application).
  static const ReceiptPaperSize defaultSize = ReceiptPaperSize.mm58;

  static ReceiptPaperSize read(DatabaseService databaseService) {
    try {
      final saved = databaseService.get<String>(prefKey);
      return saved == '80' ? ReceiptPaperSize.mm80 : defaultSize;
    } catch (_) {
      return defaultSize;
    }
  }

  static Future<void> save(
    DatabaseService databaseService,
    ReceiptPaperSize size,
  ) {
    return databaseService.save<String>(
      prefKey,
      size == ReceiptPaperSize.mm80 ? '80' : '58',
    );
  }
}
