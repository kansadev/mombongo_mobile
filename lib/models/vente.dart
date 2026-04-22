import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'ligne_commande.dart';

part 'vente.g.dart';

@HiveType(typeId: 4)
@JsonSerializable()
class Vente extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final int idClient;

  @HiveField(2)
  final int idUtilisateur;

  @HiveField(3)
  final DateTime dateCommande;

  @HiveField(4)
  final String statutCommande;

  @HiveField(5)
  final double montantTotal;

  @HiveField(6)
  final String reference;

  // Added to align with API schema (/api/Vente/enregistrer)
  @HiveField(8)
  final int typeTransaction;

  @HiveField(7)
  final List<LigneCommande> lignesCommandes;

  Vente({
    required this.id,
    required this.idClient,
    required this.idUtilisateur,
    required this.dateCommande,
    required this.statutCommande,
    required this.montantTotal,
    required this.reference,
    this.typeTransaction = 0,
    required this.lignesCommandes,
  });

  factory Vente.fromJson(Map<String, dynamic> json) =>
      _$VenteFromJson(json);

  Map<String, dynamic> toJson() => _$VenteToJson(this);

  @override
  String toString() => 'Vente(id: $id, reference: $reference, montantTotal: $montantTotal)';
}