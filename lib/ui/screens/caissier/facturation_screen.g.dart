// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'facturation_screen.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

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
