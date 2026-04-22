import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'site.g.dart';

@HiveType(typeId: 7)
@JsonSerializable()
class Site extends HiveObject {
  @HiveField(0)
  final String idSite;

  @HiveField(1)
  final String nomSite;

  @HiveField(2)
  final String contact;

  @HiveField(3)
  final String? province;

  @HiveField(4)
  final String? ville;

  @HiveField(5)
  final String? commune;

  @HiveField(6)
  final String? quartier;

  @HiveField(7)
  final String? avenue;

  @HiveField(8)
  final String? numero;

  @HiveField(9)
  final DateTime dateCreation;

  @HiveField(10)
  final DateTime? dateLastModification;

  @HiveField(11)
  final bool statut;

  @HiveField(12)
  final String idSociete;

  Site({
    required this.idSite,
    required this.nomSite,
    required this.contact,
    this.province,
    this.ville,
    this.commune,
    this.quartier,
    this.avenue,
    this.numero,
    required this.dateCreation,
    required this.dateLastModification,
    required this.statut,
    required this.idSociete,
  });

  // Helper pour convertir int en String
  static String _toString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  factory Site.fromJson(Map<String, dynamic> json) {
    try {
      // Mapper manuellement pour gérer les types mixtes (int ou String)
      return Site(
        idSite: _toString(json['idSite']),
        nomSite: _toString(json['nomSite']),
        contact: _toString(json['contact']),
        province: _toString(json['province']),
        ville: _toString(json['ville']),
        commune: _toString(json['commune']),
        quartier: _toString(json['quartier']),
        avenue: _toString(json['avenue']),
        numero: _toString(json['numero']),
        dateCreation: json['dateCreation'] != null
            ? DateTime.parse(json['dateCreation'].toString())
            : DateTime.now(),
        dateLastModification: json['dateLastModification'] != null
            ? DateTime.tryParse(json['dateLastModification'].toString())
            : null,
        statut: json['statut'] is bool
            ? json['statut']
            : json['statut'] == 1 || json['statut'] == 'true',
        idSociete: _toString(json['idSociete']),
      );
    } catch (e) {
      print('Error parsing Site from JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => _$SiteToJson(this);

  @override
  String toString() => 'Site(idSite: $idSite, nomSite: $nomSite, statut: $statut)';
}