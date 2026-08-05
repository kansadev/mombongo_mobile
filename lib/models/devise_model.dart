class Devise {
  final int idDevise;
  final String code;
  final String nom;
  final String? symbole;
  final String? description;
  final int idSite;
  final String tauxActuel;
  final DateTime? dateCreation;
  final DateTime? dateModification;
  final bool estActive;

  Devise({
    required this.idDevise,
    required this.code,
    required this.nom,
    this.symbole,
    this.description,
    required this.idSite,
    required this.tauxActuel,
    this.dateCreation,
    this.dateModification,
    required this.estActive,
  });

  factory Devise.fromJson(Map<String, dynamic> json) {
    // Gérer le cas où tauxActuel peut être un nombre ou une chaîne
    String tauxActuelValue = '0';
    final tauxActuelRaw = json['tauxActuel'];
    if (tauxActuelRaw is String) {
      tauxActuelValue = tauxActuelRaw;
    } else if (tauxActuelRaw is num) {
      tauxActuelValue = tauxActuelRaw.toString();
    }
    
    return Devise(
      idDevise: json['idDevise'] as int? ?? 0,
      code: json['code'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      symbole: json['symbole'] as String?,
      description: json['description'] as String?,
      idSite: json['idSite'] as int? ?? 0,
      tauxActuel: tauxActuelValue,
      dateCreation: json['dateCreation'] != null 
          ? DateTime.tryParse(json['dateCreation'] as String) 
          : null,
      dateModification: json['dateModification'] != null 
          ? DateTime.tryParse(json['dateModification'] as String) 
          : null,
      estActive: json['estActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'idDevise': idDevise,
    'code': code,
    'nom': nom,
    'symbole': symbole,
    'description': description,
    'idSite': idSite,
    'tauxActuel': tauxActuel,
    'dateCreation': dateCreation?.toIso8601String(),
    'dateModification': dateModification?.toIso8601String(),
    'estActive': estActive,
  };
}

class DeviseSiteResponse {
  final String site;
  final int totalDevises;
  final List<Devise> devises;

  DeviseSiteResponse({
    required this.site,
    required this.totalDevises,
    required this.devises,
  });

  factory DeviseSiteResponse.fromJson(Map<String, dynamic> json) {
    final devisesList = json['devises'] as List<dynamic>? ?? [];
    return DeviseSiteResponse(
      site: json['site'] as String? ?? '',
      totalDevises: json['totalDevises'] as int? ?? 0,
      devises: devisesList.map((d) => Devise.fromJson(d as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'site': site,
    'totalDevises': totalDevises,
    'devises': devises.map((d) => d.toJson()).toList(),
  };
}
