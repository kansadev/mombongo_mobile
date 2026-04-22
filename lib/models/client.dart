import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'client.g.dart';

@HiveType(typeId: 2)
@JsonSerializable()
class Client extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String nom;

  @HiveField(2)
  final String prenom;

  @HiveField(3)
  final String? genre;

  @HiveField(4)
  final String? email;

  @HiveField(5)
  final String? telephone;

  @HiveField(6)
  final DateTime? dateNaissance;

  @HiveField(7)
  final String? pieceIdentite;

  @HiveField(8)
  final bool statut;

  @HiveField(9)
  final DateTime dateCreation;

  Client({
    required this.id,
    required this.nom,
    required this.prenom,
    this.genre,
    this.email,
    this.telephone,
    this.dateNaissance,
    this.pieceIdentite,
    required this.statut,
    required this.dateCreation,
  }) {
    print('=== CONSTRUCTEUR CLIENT ===');
    print('Client créé avec:');
    print('  - id: $id');
    print('  - nom: $nom');
    print('  - prenom: $prenom');
    print('  - genre: $genre');
    print('  - email: $email');
    print('  - telephone: $telephone');
    print('  - dateNaissance: $dateNaissance');
    print('  - pieceIdentite: $pieceIdentite');
    print('  - statut: $statut');
    print('  - dateCreation: $dateCreation');
    print('===========================');
  }

  factory Client.fromJson(Map<String, dynamic> json) {
    print('=== CLIENT.fromJson ===');
    print('JSON reçu: $json');
    print('Valeurs individuelles:');
    print('  - id: ${json['id']} (${json['id']?.runtimeType})');
    print('  - nom: ${json['nom']} (${json['nom']?.runtimeType})');
    print('  - prenom: ${json['prenom']} (${json['prenom']?.runtimeType})');
    print('  - genre: ${json['genre']} (${json['genre']?.runtimeType})');
    print('  - email: ${json['email']} (${json['email']?.runtimeType})');
    print('  - telephone: ${json['telephone']} (${json['telephone']?.runtimeType})');
    print('  - dateNaissance: ${json['dateNaissance']} (${json['dateNaissance']?.runtimeType})');
    print('  - pieceIdentite: ${json['pieceIdentite']} (${json['pieceIdentite']?.runtimeType})');
    print('  - statut: ${json['statut']} (${json['statut']?.runtimeType})');
    print('  - dateCreation: ${json['dateCreation']} (${json['dateCreation']?.runtimeType})');
    
    try {
      final client = _$ClientFromJson(json);
      print('Client créé avec succès: ${client.toString()}');
      print('======================');
      return client;
    } catch (e, stackTrace) {
      print('=== ERREUR CLIENT.fromJson ===');
      print('Erreur: $e');
      print('Stack trace: $stackTrace');
      print('==============================');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => _$ClientToJson(this);

  @override
  String toString() => 'Client(id: $id, nom: $nom, prenom: $prenom)';
}