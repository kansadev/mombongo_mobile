import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'utilisateur.g.dart';

@HiveType(typeId: 0)
@JsonSerializable()
class Utilisateur extends HiveObject {
  @HiveField(0)
  @JsonKey(defaultValue: '')
  final String idUtilisateur;

  @HiveField(1)
  @JsonKey(defaultValue: '')
  final String nomComplet;

  @HiveField(2)
  @JsonKey(defaultValue: '')
  final String sexe;

  @HiveField(3)
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime dateNonce;

  @HiveField(4)
  @JsonKey(defaultValue: '')
  final String numeroTelephone;

  @HiveField(5)
  final String? photo;

  @HiveField(6)
  @JsonKey(defaultValue: '')
  final String login;

  @HiveField(7)
  @JsonKey(defaultValue: '')
  final String role;

  @HiveField(8)
  @JsonKey(defaultValue: '')
  final String idSite;

  @HiveField(9)
  @JsonKey(defaultValue: '')
  final String nomSite;

  @HiveField(10)
  @JsonKey(defaultValue: '')
  final String contact;

  @HiveField(11)
  @JsonKey(defaultValue: '')
  final String adresseSite;

  @HiveField(12)
  @JsonKey(defaultValue: '')
  final String idSociete;

  @HiveField(13)
  @JsonKey(defaultValue: '')
  final String nomSociete;

  @HiveField(14)
  @JsonKey(defaultValue: false)
  final bool statut;

  @HiveField(15)
  @JsonKey(defaultValue: false)
  final bool isConnected;

  // Nouveaux champs pour la devise
  @HiveField(16)
  @JsonKey(defaultValue: '')
  final String codeDevise;

  @HiveField(17)
  @JsonKey(defaultValue: '')
  final String nomDevise;

  @HiveField(18)
  @JsonKey(defaultValue: '')
  final String symboleDevise;

  @HiveField(19)
  @JsonKey(defaultValue: '0')
  final String tauxActuel;

  Utilisateur({
    required this.idUtilisateur,
    required this.nomComplet,
    required this.sexe,
    required this.dateNonce,
    required this.numeroTelephone,
    this.photo,
    required this.login,
    required this.role,
    required this.idSite,
    required this.nomSite,
    required this.contact,
    required this.adresseSite,
    required this.idSociete,
    required this.nomSociete,
    required this.statut,
    required this.isConnected,
    required this.codeDevise,
    required this.nomDevise,
    required this.symboleDevise,
    required this.tauxActuel,
  });

  factory Utilisateur.fromJson(Map<String, dynamic> json) =>
      _$UtilisateurFromJson(json);

  Map<String, dynamic> toJson() => _$UtilisateurToJson(this);

  Utilisateur copyWith({
    String? idUtilisateur,
    String? nomComplet,
    String? sexe,
    DateTime? dateNonce,
    String? numeroTelephone,
    String? photo,
    String? login,
    String? role,
    String? idSite,
    String? nomSite,
    String? contact,
    String? adresseSite,
    String? idSociete,
    String? nomSociete,
    bool? statut,
    bool? isConnected,
    String? codeDevise,
    String? nomDevise,
    String? symboleDevise,
    String? tauxActuel,
  }) {
    return Utilisateur(
      idUtilisateur: idUtilisateur ?? this.idUtilisateur,
      nomComplet: nomComplet ?? this.nomComplet,
      sexe: sexe ?? this.sexe,
      dateNonce: dateNonce ?? this.dateNonce,
      numeroTelephone: numeroTelephone ?? this.numeroTelephone,
      photo: photo ?? this.photo,
      login: login ?? this.login,
      role: role ?? this.role,
      idSite: idSite ?? this.idSite,
      nomSite: nomSite ?? this.nomSite,
      contact: contact ?? this.contact,
      adresseSite: adresseSite ?? this.adresseSite,
      idSociete: idSociete ?? this.idSociete,
      nomSociete: nomSociete ?? this.nomSociete,
      statut: statut ?? this.statut,
      isConnected: isConnected ?? this.isConnected,
      codeDevise: codeDevise ?? this.codeDevise,
      nomDevise: nomDevise ?? this.nomDevise,
      symboleDevise: symboleDevise ?? this.symboleDevise,
      tauxActuel: tauxActuel ?? this.tauxActuel,
    );
  }

  bool get isAdministrateur {
    final r = role.toUpperCase().trim();
    return r == 'ADMINISTRATEUR' ||
        r == 'ADMINISTRATOR' ||
        r == 'ADMIN' ||
        r.contains('ADMIN');
  }

  // Helper methods for DateTime handling
  static DateTime _dateTimeFromJson(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static String _dateTimeToJson(DateTime dateTime) {
    return dateTime.toIso8601String();
  }

  @override
  String toString() => 'Utilisateur(login: $login, nomComplet: $nomComplet, role: $role)';
}
