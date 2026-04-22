// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'site.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SiteAdapter extends TypeAdapter<Site> {
  @override
  final int typeId = 7;

  @override
  Site read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Site(
      idSite: fields[0] as String,
      nomSite: fields[1] as String,
      contact: fields[2] as String,
      province: fields[3] as String?,
      ville: fields[4] as String?,
      commune: fields[5] as String?,
      quartier: fields[6] as String?,
      avenue: fields[7] as String?,
      numero: fields[8] as String?,
      dateCreation: fields[9] as DateTime,
      dateLastModification: fields[10] as DateTime?,
      statut: fields[11] as bool,
      idSociete: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Site obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.idSite)
      ..writeByte(1)
      ..write(obj.nomSite)
      ..writeByte(2)
      ..write(obj.contact)
      ..writeByte(3)
      ..write(obj.province)
      ..writeByte(4)
      ..write(obj.ville)
      ..writeByte(5)
      ..write(obj.commune)
      ..writeByte(6)
      ..write(obj.quartier)
      ..writeByte(7)
      ..write(obj.avenue)
      ..writeByte(8)
      ..write(obj.numero)
      ..writeByte(9)
      ..write(obj.dateCreation)
      ..writeByte(10)
      ..write(obj.dateLastModification)
      ..writeByte(11)
      ..write(obj.statut)
      ..writeByte(12)
      ..write(obj.idSociete);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SiteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Site _$SiteFromJson(Map<String, dynamic> json) => Site(
      idSite: json['idSite'] as String,
      nomSite: json['nomSite'] as String,
      contact: json['contact'] as String,
      province: json['province'] as String?,
      ville: json['ville'] as String?,
      commune: json['commune'] as String?,
      quartier: json['quartier'] as String?,
      avenue: json['avenue'] as String?,
      numero: json['numero'] as String?,
      dateCreation: DateTime.parse(json['dateCreation'] as String),
      dateLastModification: json['dateLastModification'] == null
          ? null
          : DateTime.parse(json['dateLastModification'] as String),
      statut: json['statut'] as bool,
      idSociete: json['idSociete'] as String,
    );

Map<String, dynamic> _$SiteToJson(Site instance) => <String, dynamic>{
      'idSite': instance.idSite,
      'nomSite': instance.nomSite,
      'contact': instance.contact,
      'province': instance.province,
      'ville': instance.ville,
      'commune': instance.commune,
      'quartier': instance.quartier,
      'avenue': instance.avenue,
      'numero': instance.numero,
      'dateCreation': instance.dateCreation.toIso8601String(),
      'dateLastModification': instance.dateLastModification?.toIso8601String(),
      'statut': instance.statut,
      'idSociete': instance.idSociete,
    };
