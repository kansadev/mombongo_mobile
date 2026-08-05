// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'article.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ArticleAdapter extends TypeAdapter<Article> {
  @override
  final int typeId = 1;

  @override
  Article read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Article(
      idArticle: fields[0] as int,
      libelle: fields[1] as String,
      codeBarreQR: fields[2] as String?,
      tva: fields[3] as double,
      remise: fields[4] as double,
      statut: fields[5] as bool,
      perissable: fields[6] as bool,
      withStock: fields[7] as bool,
      idSociete: fields[8] as int,
      dateCreation: fields[9] as DateTime,
      dateLastModification: fields[10] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Article obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.idArticle)
      ..writeByte(1)
      ..write(obj.libelle)
      ..writeByte(2)
      ..write(obj.codeBarreQR)
      ..writeByte(3)
      ..write(obj.tva)
      ..writeByte(4)
      ..write(obj.remise)
      ..writeByte(5)
      ..write(obj.statut)
      ..writeByte(6)
      ..write(obj.perissable)
      ..writeByte(7)
      ..write(obj.withStock)
      ..writeByte(8)
      ..write(obj.idSociete)
      ..writeByte(9)
      ..write(obj.dateCreation)
      ..writeByte(10)
      ..write(obj.dateLastModification);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArticleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Article _$ArticleFromJson(Map<String, dynamic> json) => Article(
      idArticle: (json['idArticle'] as num).toInt(),
      libelle: json['libelle'] as String,
      codeBarreQR: json['codeBarreQR'] as String?,
      tva: (json['tva'] as num).toDouble(),
      remise: (json['remise'] as num).toDouble(),
      statut: json['statut'] as bool,
      perissable: json['perissable'] as bool,
      withStock: json['withStock'] as bool,
      idSociete: (json['idSociete'] as num).toInt(),
      dateCreation: DateTime.parse(json['dateCreation'] as String),
      dateLastModification:
          DateTime.parse(json['dateLastModification'] as String),
    );

Map<String, dynamic> _$ArticleToJson(Article instance) => <String, dynamic>{
      'idArticle': instance.idArticle,
      'libelle': instance.libelle,
      'codeBarreQR': instance.codeBarreQR,
      'tva': instance.tva,
      'remise': instance.remise,
      'statut': instance.statut,
      'perissable': instance.perissable,
      'withStock': instance.withStock,
      'idSociete': instance.idSociete,
      'dateCreation': instance.dateCreation.toIso8601String(),
      'dateLastModification': instance.dateLastModification.toIso8601String(),
    };
