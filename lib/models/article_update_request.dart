class ArticleUpdateRequest {
  final int idStock;
  final int idSite;
  final int idArticle;
  final String libelle;
  final double tva;
  final bool perissable;
  final double remise;
  final bool withStock;
  final double quantiteInitial;
  final double prixAchat;
  final double prixVenteHT;
  final DateTime? dateExpiration;
  final int seuilAlerte;

  ArticleUpdateRequest( {
    required this.idStock,
    required this.idSite,
    required this.idArticle,
    required this.libelle,
    required this.tva,
    required this.perissable,
    required this.remise,
    required this.withStock,
    required this.quantiteInitial,
    required this.prixAchat,
    required this.prixVenteHT,
    this.dateExpiration,
    required this.seuilAlerte,
  });

  factory ArticleUpdateRequest.fromMap(Map<String, dynamic> map) {
    return ArticleUpdateRequest(
      idStock: int.tryParse(map['idStock']?.toString() ?? '') ?? 0,
      idSite: int.tryParse(map['idSite']?.toString() ?? '') ?? 0,
      idArticle: int.tryParse(map['idArticle']?.toString() ?? '') ?? 0,
      libelle: map['libelle']?.toString() ?? '',
      tva: double.tryParse(map['tva']?.toString() ?? '') ?? 0.0,
      perissable: map['perissable'] == true,
      remise: double.tryParse(map['remise']?.toString() ?? '') ?? 0.0,
      withStock: map['withStock'] == true,
      quantiteInitial: double.tryParse(map['quantiteInitial']?.toString() ?? '') ?? 0.0,
      prixAchat: double.tryParse(map['prixAchat']?.toString() ?? '') ?? 0.0,
      prixVenteHT: double.tryParse(map['prixVenteHT']?.toString() ?? '') ?? 0.0,
      dateExpiration: map['dateExpiration'] != null ? DateTime.parse(map['dateExpiration'].toString()) : null,
      seuilAlerte: int.tryParse(map['seuilAlerte']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idStock': idStock,
      'idSite': idSite,
      'idArticle': idArticle,
      'libelle': libelle, 
      'tva': tva,
      'perissable': perissable,
      'remise': remise,
      'withStock': withStock,
      'quantiteStock': quantiteInitial, //important n'est pas remplacer sans autorisation
      'quantiteInitial': quantiteInitial, //important n'est pas remplacer sans autorisation
      'prixAchat': prixAchat,
      'prixVentHT': prixVenteHT,  //important n'est pas remplacer sans autorisation
      'prixVenteHT': prixVenteHT, //important n'est pas remplacer sans autorisation
      'seuilAlerte': seuilAlerte,
      if (dateExpiration != null) 'dateExpiration': dateExpiration!.toIso8601String(),
    };
  }
}
