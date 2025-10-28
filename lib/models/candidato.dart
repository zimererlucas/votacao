class Candidato {
  final String id;
  final String? eleicaoId;
  final String nomeCompleto;
  final DateTime criadoEm;

  Candidato({
    required this.id,
    this.eleicaoId,
    required this.nomeCompleto,
    required this.criadoEm,
  });

  factory Candidato.fromJson(Map<String, dynamic> json) {
    return Candidato(
      id: json['id'] as String,
      eleicaoId: json['eleicao_id'] as String?,
      nomeCompleto: json['nome_completo'] as String,
      criadoEm: DateTime.parse(json['criado_em'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eleicao_id': eleicaoId,
      'nome_completo': nomeCompleto,
      'criado_em': criadoEm.toIso8601String(),
    };
  }
}
