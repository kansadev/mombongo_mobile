// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ligne_commande.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LigneCommandeAdapter extends TypeAdapter<LigneCommande> {
  @override
  final int typeId = 3;

  @override
  LigneCommande read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LigneCommande(
      id: fields[0] as int,
      idCommande: fields[1] as int,
      idStock: fields[2] as int,
      quantite: fields[3] as int,
      prixUnitaire: fields[4] as double,
      tva: fields[5] as double,
      remise: fields[6] as double,
      montantTotal: fields[7] as double,
    );
  }

  @override
  void write(BinaryWriter writer, LigneCommande obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.idCommande)
      ..writeByte(2)
      ..write(obj.idStock)
      ..writeByte(3)
      ..write(obj.quantite)
      ..writeByte(4)
      ..write(obj.prixUnitaire)
      ..writeByte(5)
      ..write(obj.tva)
      ..writeByte(6)
      ..write(obj.remise)
      ..writeByte(7)
      ..write(obj.montantTotal);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LigneCommandeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LigneCommande _$LigneCommandeFromJson(Map<String, dynamic> json) =>
    LigneCommande(
      id: (json['id'] as num).toInt(),
      idCommande: (json['idCommande'] as num).toInt(),
      idStock: (json['idStock'] as num).toInt(),
      quantite: (json['quantite'] as num).toInt(),
      prixUnitaire: (json['prixUnitaire'] as num).toDouble(),
      tva: (json['tva'] as num).toDouble(),
      remise: (json['remise'] as num).toDouble(),
      montantTotal: (json['montantTotal'] as num).toDouble(),
    );

Map<String, dynamic> _$LigneCommandeToJson(LigneCommande instance) =>
    <String, dynamic>{
      'id': instance.id,
      'idCommande': instance.idCommande,
      'idStock': instance.idStock,
      'quantite': instance.quantite,
      'prixUnitaire': instance.prixUnitaire,
      'tva': instance.tva,
      'remise': instance.remise,
      'montantTotal': instance.montantTotal,
    };
