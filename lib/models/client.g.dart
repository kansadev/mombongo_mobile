// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ClientAdapter extends TypeAdapter<Client> {
  @override
  final int typeId = 2;

  @override
  Client read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Client(
      id: fields[0] as int,
      nom: fields[1] as String,
      prenom: fields[2] as String,
      genre: fields[3] as String?,
      email: fields[4] as String?,
      telephone: fields[5] as String?,
      dateNaissance: fields[6] as DateTime?,
      pieceIdentite: fields[7] as String?,
      statut: fields[8] as bool,
      dateCreation: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Client obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nom)
      ..writeByte(2)
      ..write(obj.prenom)
      ..writeByte(3)
      ..write(obj.genre)
      ..writeByte(4)
      ..write(obj.email)
      ..writeByte(5)
      ..write(obj.telephone)
      ..writeByte(6)
      ..write(obj.dateNaissance)
      ..writeByte(7)
      ..write(obj.pieceIdentite)
      ..writeByte(8)
      ..write(obj.statut)
      ..writeByte(9)
      ..write(obj.dateCreation);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Client _$ClientFromJson(Map<String, dynamic> json) => Client(
      id: (json['id'] as num).toInt(),
      nom: json['nom'] as String,
      prenom: json['prenom'] as String,
      genre: json['genre'] as String?,
      email: json['email'] as String?,
      telephone: json['telephone'] as String?,
      dateNaissance: json['dateNaissance'] == null
          ? null
          : DateTime.parse(json['dateNaissance'] as String),
      pieceIdentite: json['pieceIdentite'] as String?,
      statut: json['statut'] as bool,
      dateCreation: DateTime.parse(json['dateCreation'] as String),
    );

Map<String, dynamic> _$ClientToJson(Client instance) => <String, dynamic>{
      'id': instance.id,
      'nom': instance.nom,
      'prenom': instance.prenom,
      'genre': instance.genre,
      'email': instance.email,
      'telephone': instance.telephone,
      'dateNaissance': instance.dateNaissance?.toIso8601String(),
      'pieceIdentite': instance.pieceIdentite,
      'statut': instance.statut,
      'dateCreation': instance.dateCreation.toIso8601String(),
    };
