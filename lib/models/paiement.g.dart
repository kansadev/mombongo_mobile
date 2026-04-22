// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paiement.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PaiementAdapter extends TypeAdapter<Paiement> {
  @override
  final int typeId = 6;

  @override
  Paiement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Paiement(
      id: fields[0] as int,
      idCommande: fields[1] as int,
      datePaiement: fields[2] as DateTime,
      modePaiement: fields[3] as String,
      montant: fields[4] as double,
      referencePaiement: fields[5] as String,
      statutPaiement: fields[6] as String,
      libellePaiement: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Paiement obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.idCommande)
      ..writeByte(2)
      ..write(obj.datePaiement)
      ..writeByte(3)
      ..write(obj.modePaiement)
      ..writeByte(4)
      ..write(obj.montant)
      ..writeByte(5)
      ..write(obj.referencePaiement)
      ..writeByte(6)
      ..write(obj.statutPaiement)
      ..writeByte(7)
      ..write(obj.libellePaiement);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaiementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Paiement _$PaiementFromJson(Map<String, dynamic> json) => Paiement(
      id: (json['id'] as num).toInt(),
      idCommande: (json['idCommande'] as num).toInt(),
      datePaiement: DateTime.parse(json['datePaiement'] as String),
      modePaiement: json['modePaiement'] as String,
      montant: (json['montant'] as num).toDouble(),
      referencePaiement: json['referencePaiement'] as String,
      statutPaiement: json['statutPaiement'] as String,
      libellePaiement: json['libellePaiement'] as String,
    );

Map<String, dynamic> _$PaiementToJson(Paiement instance) => <String, dynamic>{
      'id': instance.id,
      'idCommande': instance.idCommande,
      'datePaiement': instance.datePaiement.toIso8601String(),
      'modePaiement': instance.modePaiement,
      'montant': instance.montant,
      'referencePaiement': instance.referencePaiement,
      'statutPaiement': instance.statutPaiement,
      'libellePaiement': instance.libellePaiement,
    };
