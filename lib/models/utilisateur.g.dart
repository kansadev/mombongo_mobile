// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'utilisateur.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UtilisateurAdapter extends TypeAdapter<Utilisateur> {
  @override
  final int typeId = 0;

  @override
  Utilisateur read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Utilisateur(
      idUtilisateur: fields[0] as String,
      nomComplet: fields[1] as String,
      sexe: fields[2] as String,
      dateNonce: fields[3] as DateTime,
      numeroTelephone: fields[4] as String,
      photo: fields[5] as String?,
      login: fields[6] as String,
      role: fields[7] as String,
      idSite: fields[8] as String,
      nomSite: fields[9] as String,
      contact: fields[10] as String,
      adresseSite: fields[11] as String,
      idSociete: fields[12] as String,
      nomSociete: fields[13] as String,
      statut: fields[14] as bool,
      isConnected: fields[15] as bool,
      codeDevise: fields[16] as String,
      nomDevise: fields[17] as String,
      symboleDevise: fields[18] as String,
      tauxActuel: fields[19] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Utilisateur obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.idUtilisateur)
      ..writeByte(1)
      ..write(obj.nomComplet)
      ..writeByte(2)
      ..write(obj.sexe)
      ..writeByte(3)
      ..write(obj.dateNonce)
      ..writeByte(4)
      ..write(obj.numeroTelephone)
      ..writeByte(5)
      ..write(obj.photo)
      ..writeByte(6)
      ..write(obj.login)
      ..writeByte(7)
      ..write(obj.role)
      ..writeByte(8)
      ..write(obj.idSite)
      ..writeByte(9)
      ..write(obj.nomSite)
      ..writeByte(10)
      ..write(obj.contact)
      ..writeByte(11)
      ..write(obj.adresseSite)
      ..writeByte(12)
      ..write(obj.idSociete)
      ..writeByte(13)
      ..write(obj.nomSociete)
      ..writeByte(14)
      ..write(obj.statut)
      ..writeByte(15)
      ..write(obj.isConnected)
      ..writeByte(16)
      ..write(obj.codeDevise)
      ..writeByte(17)
      ..write(obj.nomDevise)
      ..writeByte(18)
      ..write(obj.symboleDevise)
      ..writeByte(19)
      ..write(obj.tauxActuel);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UtilisateurAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Utilisateur _$UtilisateurFromJson(Map<String, dynamic> json) => Utilisateur(
      idUtilisateur: json['idUtilisateur'] as String? ?? '',
      nomComplet: json['nomComplet'] as String? ?? '',
      sexe: json['sexe'] as String? ?? '',
      dateNonce: Utilisateur._dateTimeFromJson(json['dateNonce']),
      numeroTelephone: json['numeroTelephone'] as String? ?? '',
      photo: json['photo'] as String?,
      login: json['login'] as String? ?? '',
      role: json['role'] as String? ?? '',
      idSite: json['idSite'] as String? ?? '',
      nomSite: json['nomSite'] as String? ?? '',
      contact: json['contact'] as String? ?? '',
      adresseSite: json['adresseSite'] as String? ?? '',
      idSociete: json['idSociete'] as String? ?? '',
      nomSociete: json['nomSociete'] as String? ?? '',
      statut: json['statut'] as bool? ?? false,
      isConnected: json['isConnected'] as bool? ?? false,
      codeDevise: json['codeDevise'] as String? ?? '',
      nomDevise: json['nomDevise'] as String? ?? '',
      symboleDevise: json['symboleDevise'] as String? ?? '',
      tauxActuel: json['tauxActuel'] as String? ?? '0',
    );

Map<String, dynamic> _$UtilisateurToJson(Utilisateur instance) =>
    <String, dynamic>{
      'idUtilisateur': instance.idUtilisateur,
      'nomComplet': instance.nomComplet,
      'sexe': instance.sexe,
      'dateNonce': Utilisateur._dateTimeToJson(instance.dateNonce),
      'numeroTelephone': instance.numeroTelephone,
      'photo': instance.photo,
      'login': instance.login,
      'role': instance.role,
      'idSite': instance.idSite,
      'nomSite': instance.nomSite,
      'contact': instance.contact,
      'adresseSite': instance.adresseSite,
      'idSociete': instance.idSociete,
      'nomSociete': instance.nomSociete,
      'statut': instance.statut,
      'isConnected': instance.isConnected,
      'codeDevise': instance.codeDevise,
      'nomDevise': instance.nomDevise,
      'symboleDevise': instance.symboleDevise,
      'tauxActuel': instance.tauxActuel,
    };
