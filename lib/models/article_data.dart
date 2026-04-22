import 'package:hive/hive.dart';

@HiveType(typeId: 21)
class ArticleData {
  @HiveField(0)
  final int idStock;

  @HiveField(1)
  final int idArticle;

  @HiveField(2)
  final String libelle;

  @HiveField(3)
  final int quantiteStock;

  @HiveField(4)
  final double prixAchat;

  @HiveField(5)
  final double prixVentHT;

  @HiveField(6)
  final double prixVentTTC;

  @HiveField(7)
  final int seuilAlerte;

  @HiveField(8)
  final double tva;

  @HiveField(9)
  final String codeBarreQR;

  @HiveField(10)
  final double remise;

  @HiveField(11)
  final int idSite;

  @HiveField(12)
  final String nomSite;

  @HiveField(13)
  final int idSociete;

  @HiveField(14)
  final bool withStock;

  ArticleData({
    required this.idStock,
    required this.idArticle,
    required this.libelle,
    required this.quantiteStock,
    required this.prixAchat,
    required this.prixVentHT,
    required this.prixVentTTC,
    required this.seuilAlerte,
    required this.tva,
    required this.codeBarreQR,
    required this.remise,
    required this.idSite,
    required this.nomSite,
    required this.idSociete,
    required this.withStock,
  });

  factory ArticleData.fromJson(Map<String, dynamic> json) {
    return ArticleData(
      idStock: _parseInt(json['idStock'], 0),
      idArticle: _parseInt(json['idArticle'], 0),
      libelle: json['libelle'] ?? 'N/A',
      quantiteStock: _parseInt(json['quantiteStock'], 0),
      prixAchat: _parseFloat(json['prixAchat'], 0),
      prixVentHT: _parseFloat(json['prixVentHT'], 0),
      prixVentTTC: _parseFloat(json['prixVentTTC'], 0),
      seuilAlerte: _parseInt(json['seuilAlerte'], 0),
      tva: _parseFloat(json['tva'], 0),
      codeBarreQR: json['codeBarreQR'] ?? 'N/A',
      remise: _parseFloat(json['remise'], 0),
      idSite: _parseInt(json['idSite'], 0),
      nomSite: json['nomSite'] ?? 'N/A',
      idSociete: _parseInt(json['idSociete'], 0),
      withStock: json['withStock'] ?? true,
    );
  }

  static int _parseInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) {
      try {
        return int.parse(value);
      } catch (_) {
        try {
          return double.parse(value).round();
        } catch (_) {
          return defaultValue;
        }
      }
    }
    if (value is double) return value.round();
    return defaultValue;
  }

  static double _parseFloat(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return defaultValue;
      }
    }
    return defaultValue;
  }
}

class ArticleDataAdapter extends TypeAdapter<ArticleData> {
  @override
  final int typeId = 21;

  @override
  ArticleData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ArticleData(
      idStock: fields[0] as int,
      idArticle: fields[1] as int,
      libelle: fields[2] as String,
      quantiteStock: fields[3] as int,
      prixAchat: fields[4] as double,
      prixVentHT: fields[5] as double,
      prixVentTTC: fields[6] as double,
      seuilAlerte: fields[7] as int,
      tva: fields[8] as double,
      codeBarreQR: fields[9] as String,
      remise: fields[10] as double,
      idSite: fields[11] as int,
      nomSite: fields[12] as String,
      idSociete: fields[13] as int,
      withStock: fields[14] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ArticleData obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.idStock)
      ..writeByte(1)
      ..write(obj.idArticle)
      ..writeByte(2)
      ..write(obj.libelle)
      ..writeByte(3)
      ..write(obj.quantiteStock)
      ..writeByte(4)
      ..write(obj.prixAchat)
      ..writeByte(5)
      ..write(obj.prixVentHT)
      ..writeByte(6)
      ..write(obj.prixVentTTC)
      ..writeByte(7)
      ..write(obj.seuilAlerte)
      ..writeByte(8)
      ..write(obj.tva)
      ..writeByte(9)
      ..write(obj.codeBarreQR)
      ..writeByte(10)
      ..write(obj.remise)
      ..writeByte(11)
      ..write(obj.idSite)
      ..writeByte(12)
      ..write(obj.nomSite)
      ..writeByte(13)
      ..write(obj.idSociete)
      ..writeByte(14)
      ..write(obj.withStock);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArticleDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
