import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'taux.g.dart';

@HiveType(typeId: 8)
@JsonSerializable()
class Taux extends HiveObject {
  @HiveField(0)
  final String codeDevise;

  @HiveField(1)
  final String nomDevise;

  @HiveField(2)
  final String symboleDevise;

  @HiveField(3)
  final String tauxActuel;

  @HiveField(4)
  final DateTime? dateMiseAJour;

  Taux({
    required this.codeDevise,
    required this.nomDevise,
    required this.symboleDevise,
    required this.tauxActuel,
    this.dateMiseAJour,
  });

  factory Taux.fromJson(Map<String, dynamic> json) => _$TauxFromJson(json);

  Map<String, dynamic> toJson() => _$TauxToJson(this);

  /// Crée un Taux à partir des données utilisateur
  factory Taux.fromUtilisateur({
    required String codeDevise,
    required String nomDevise,
    required String symboleDevise,
    required String tauxActuel,
  }) {
    return Taux(
      codeDevise: codeDevise,
      nomDevise: nomDevise,
      symboleDevise: symboleDevise,
      tauxActuel: tauxActuel,
      dateMiseAJour: DateTime.now(),
    );
  }

  /// Valeurs par défaut
  static Taux defaultTaux() {
    return Taux(
      codeDevise: 'USD',
      nomDevise: 'Dollar Américain',
      symboleDevise: '\$',
      tauxActuel: '1',
      dateMiseAJour: DateTime.now(),
    );
  }

  /// Formate le taux pour l'affichage
  String get tauxFormate => '$tauxActuel $codeDevise';

  /// Obtenir le symbole avec le taux
  String get symboleAvecTaux {
    if (codeDevise == 'USD') {
      return '\$$tauxActuel';
    }
    return '$tauxActuel $codeDevise';
  }

  @override
  String toString() => 'Taux(codeDevise: $codeDevise, tauxActuel: $tauxActuel)';
}
