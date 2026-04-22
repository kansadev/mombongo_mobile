// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StockAdapter extends TypeAdapter<Stock> {
  @override
  final int typeId = 5;

  @override
  Stock read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Stock(
      idArticle: fields[0] as int,
      idSite: fields[1] as int,
      quantiteStock: fields[2] as double,
      prixAchat: fields[3] as double,
      prixVentHT: fields[4] as double,
      seuilAlerte: fields[5] as double,
      numeroLot: fields[6] as String?,
      dateExpiration: fields[7] as DateTime?,
      commentairePeremption: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Stock obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.idArticle)
      ..writeByte(1)
      ..write(obj.idSite)
      ..writeByte(2)
      ..write(obj.quantiteStock)
      ..writeByte(3)
      ..write(obj.prixAchat)
      ..writeByte(4)
      ..write(obj.prixVentHT)
      ..writeByte(5)
      ..write(obj.seuilAlerte)
      ..writeByte(6)
      ..write(obj.numeroLot)
      ..writeByte(7)
      ..write(obj.dateExpiration)
      ..writeByte(8)
      ..write(obj.commentairePeremption);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Stock _$StockFromJson(Map<String, dynamic> json) => Stock(
      idArticle: (json['idArticle'] as num).toInt(),
      idSite: (json['idSite'] as num).toInt(),
      quantiteStock: (json['quantiteStock'] as num).toDouble(),
      prixAchat: (json['prixAchat'] as num).toDouble(),
      prixVentHT: (json['prixVentHT'] as num).toDouble(),
      seuilAlerte: (json['seuilAlerte'] as num).toDouble(),
      numeroLot: json['numeroLot'] as String?,
      dateExpiration: json['dateExpiration'] == null
          ? null
          : DateTime.parse(json['dateExpiration'] as String),
      commentairePeremption: json['commentairePeremption'] as String?,
    );

Map<String, dynamic> _$StockToJson(Stock instance) => <String, dynamic>{
      'idArticle': instance.idArticle,
      'idSite': instance.idSite,
      'quantiteStock': instance.quantiteStock,
      'prixAchat': instance.prixAchat,
      'prixVentHT': instance.prixVentHT,
      'seuilAlerte': instance.seuilAlerte,
      'numeroLot': instance.numeroLot,
      'dateExpiration': instance.dateExpiration?.toIso8601String(),
      'commentairePeremption': instance.commentairePeremption,
    };
