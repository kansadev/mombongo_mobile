// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vente.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VenteAdapter extends TypeAdapter<Vente> {
  @override
  final int typeId = 4;

  @override
  Vente read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Vente(
      id: fields[0] as int,
      idClient: fields[1] as int,
      idUtilisateur: fields[2] as int,
      dateCommande: fields[3] as DateTime,
      statutCommande: fields[4] as String,
      montantTotal: fields[5] as double,
      reference: fields[6] as String,
      typeTransaction: fields[8] as int? ?? 0,
      lignesCommandes: (fields[7] as List).cast<LigneCommande>(),
    );
  }

  @override
  void write(BinaryWriter writer, Vente obj) {
    writer
      ..writeByte(9) // now 9 fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.idClient)
      ..writeByte(2)
      ..write(obj.idUtilisateur)
      ..writeByte(3)
      ..write(obj.dateCommande)
      ..writeByte(4)
      ..write(obj.statutCommande)
      ..writeByte(5)
      ..write(obj.montantTotal)
      ..writeByte(6)
      ..write(obj.reference)
      ..writeByte(8)
      ..write(obj.typeTransaction)
      ..writeByte(7)
      ..write(obj.lignesCommandes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VenteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Vente _$VenteFromJson(Map<String, dynamic> json) => Vente(
      id: (json['id'] as num).toInt(),
      idClient: (json['idClient'] as num).toInt(),
      idUtilisateur: (json['idUtilisateur'] as num).toInt(),
      dateCommande: DateTime.parse(json['dateCommande'] as String),
      statutCommande: json['statutCommande'] as String,
      montantTotal: (json['montantTotal'] as num).toDouble(),
      reference: json['reference'] as String,
      typeTransaction: json['typeTransaction'] as int? ?? 0,
      lignesCommandes: (json['lignesCommandes'] as List<dynamic>)
          .map((e) => LigneCommande.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$VenteToJson(Vente instance) => <String, dynamic>{
      'id': instance.id,
      'idClient': instance.idClient,
      'idUtilisateur': instance.idUtilisateur,
      'dateCommande': instance.dateCommande.toIso8601String(),
      'statutCommande': instance.statutCommande,
      'montantTotal': instance.montantTotal,
      'reference': instance.reference,
      'typeTransaction': instance.typeTransaction,
      'lignesCommandes': instance.lignesCommandes,
    };
