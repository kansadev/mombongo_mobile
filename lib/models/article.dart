import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'article.g.dart';

@HiveType(typeId: 1)
@JsonSerializable()
class Article extends HiveObject {
  @HiveField(0)
  final int idArticle;

  @HiveField(1)
  final String libelle;

  @HiveField(2)
  final String? codeBarreQR;

  @HiveField(3)
  final double tva;

  @HiveField(4)
  final double remise;

  @HiveField(5)
  final bool statut;

  @HiveField(6)
  final bool perissable;

  @HiveField(7)
  final bool withStock;

  @HiveField(8)
  final int idSociete;

  @HiveField(9)
  final DateTime dateCreation;

  @HiveField(10)
  final DateTime dateLastModification;

  Article({
    required this.idArticle,
    required this.libelle,
    this.codeBarreQR,
    required this.tva,
    required this.remise,
    required this.statut,
    required this.perissable,
    required this.withStock,
    required this.idSociete,
    required this.dateCreation,
    required this.dateLastModification,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    try {
      return Article(
        idArticle: int.parse(json['idArticle'].toString()),
        libelle: json['libelle'] as String,
        codeBarreQR: json['codeBarreQR'] as String?,
        tva: _parseDouble(json['tva']),
        remise: _parseDouble(json['remise']),
        statut: json['statut'] as bool,
        perissable: json['perissable'] as bool,
        withStock: json['withStock'] as bool,
        idSociete: int.parse(json['idSociete'].toString()),
        dateCreation: _parseDate(json['dateCreation']),
        dateLastModification: json['dateLastModification'] != null 
            ? _parseDate(json['dateLastModification'])
            : DateTime.now(),
      );
    } catch (e) {
      print('Error parsing Article from JSON: $e');
      print('JSON data: $json');
      print('dateCreation type: ${json['dateCreation'].runtimeType}');
      print('dateLastModification type: ${json['dateLastModification']?.runtimeType}');
      rethrow;
    }
  }
  
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.isEmpty || value == 'null') return 0.0;
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() => _$ArticleToJson(this);

  static DateTime _parseDate(dynamic dateValue) {
    try {
      if (dateValue == null) return DateTime.now();
      
      if (dateValue is String) {
        return DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        return dateValue;
      } else if (dateValue is int) {
        // Handle timestamp
        return DateTime.fromMillisecondsSinceEpoch(dateValue);
      } else if (dateValue is List) {
        // This handles the specific error case mentioned
        throw Exception('Unexpected List type for date field: $dateValue');
      } else {
        throw Exception('Unsupported date type: ${dateValue.runtimeType}');
      }
    } catch (e) {
      print('Error parsing date value: $dateValue (type: ${dateValue?.runtimeType})');
      print('Error: $e');
      return DateTime.now();
    }
  }

  @override
  String toString() => 'Article(idArticle: $idArticle, libelle: $libelle, idSociete: $idSociete)';
}