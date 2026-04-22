import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'stock.g.dart';

@HiveType(typeId: 5)
@JsonSerializable()
class Stock extends HiveObject {
  @HiveField(0)
  final int idArticle;

  @HiveField(1)
  final int idSite;

  @HiveField(2)
  final double quantiteStock;

  @HiveField(3)
  final double prixAchat;

  @HiveField(4)
  final double prixVentHT;

  @HiveField(5)
  final double seuilAlerte;

  @HiveField(6)
  final String? numeroLot;

  @HiveField(7)
  final DateTime? dateExpiration;

  @HiveField(8)
  final String? commentairePeremption;

  Stock({
    required this.idArticle,
    required this.idSite,
    required this.quantiteStock,
    required this.prixAchat,
    required this.prixVentHT,
    required this.seuilAlerte,
    this.numeroLot,
    this.dateExpiration,
    this.commentairePeremption,
  });

  factory Stock.fromJson(Map<String, dynamic> json) =>
      _$StockFromJson(json);

  Map<String, dynamic> toJson() => _$StockToJson(this);

  @override
  String toString() => 'Stock(idArticle: $idArticle, quantiteStock: $quantiteStock)';
}
