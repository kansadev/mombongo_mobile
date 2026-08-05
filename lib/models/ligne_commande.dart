import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ligne_commande.g.dart';

@HiveType(typeId: 3)
@JsonSerializable()
class LigneCommande extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final int idCommande;

  @HiveField(2)
  final int idStock;

  @HiveField(3)
  final int quantite;

  @HiveField(4)
  final double prixUnitaire;

  @HiveField(5)
  final double tva;

  @HiveField(6)
  final double remise;

  @HiveField(7)
  final double montantTotal;

  LigneCommande({
    required this.id,
    required this.idCommande,
    required this.idStock,
    required this.quantite,
    required this.prixUnitaire,
    required this.tva,
    required this.remise,
    required this.montantTotal,
  });

  factory LigneCommande.fromJson(Map<String, dynamic> json) =>
      _$LigneCommandeFromJson(json);

  Map<String, dynamic> toJson() => _$LigneCommandeToJson(this);

  @override
  String toString() => 'LigneCommande(id: $id, quantite: $quantite, montantTotal: $montantTotal)';
}