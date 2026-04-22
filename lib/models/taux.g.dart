// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'taux.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TauxAdapter extends TypeAdapter<Taux> {
  @override
  final int typeId = 8;

  @override
  Taux read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Taux(
      codeDevise: fields[0] as String,
      nomDevise: fields[1] as String,
      symboleDevise: fields[2] as String,
      tauxActuel: fields[3] as String,
      dateMiseAJour: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Taux obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.codeDevise)
      ..writeByte(1)
      ..write(obj.nomDevise)
      ..writeByte(2)
      ..write(obj.symboleDevise)
      ..writeByte(3)
      ..write(obj.tauxActuel)
      ..writeByte(4)
      ..write(obj.dateMiseAJour);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TauxAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Taux _$TauxFromJson(Map<String, dynamic> json) => Taux(
      codeDevise: json['codeDevise'] as String,
      nomDevise: json['nomDevise'] as String,
      symboleDevise: json['symboleDevise'] as String,
      tauxActuel: json['tauxActuel'] as String,
      dateMiseAJour: json['dateMiseAJour'] == null
          ? null
          : DateTime.parse(json['dateMiseAJour'] as String),
    );

Map<String, dynamic> _$TauxToJson(Taux instance) => <String, dynamic>{
      'codeDevise': instance.codeDevise,
      'nomDevise': instance.nomDevise,
      'symboleDevise': instance.symboleDevise,
      'tauxActuel': instance.tauxActuel,
      'dateMiseAJour': instance.dateMiseAJour?.toIso8601String(),
    };
