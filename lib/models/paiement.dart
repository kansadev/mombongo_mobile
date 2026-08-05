import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'paiement.g.dart';

@HiveType(typeId: 6)
@JsonSerializable()
class Paiement extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final int idCommande;

  @HiveField(2)
  final DateTime datePaiement;

  @HiveField(3)
  final String modePaiement;

  @HiveField(4)
  final double montant;

  @HiveField(5)
  final String referencePaiement;

  @HiveField(6)
  final String statutPaiement;

  @HiveField(7)
  final String libellePaiement;

  Paiement({
    required this.id,
    required this.idCommande,
    required this.datePaiement,
    required this.modePaiement,
    required this.montant,
    required this.referencePaiement,
    required this.statutPaiement,
    required this.libellePaiement,
  });

  factory Paiement.fromJson(Map<String, dynamic> json) =>
      _$PaiementFromJson(json);

  Map<String, dynamic> toJson() => _$PaiementToJson(this);

  @override
  String toString() => 'Paiement(id: $id, montant: $montant, statut: $statutPaiement)';
}