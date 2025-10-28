class Eleicao {
  final String id;
  final String titulo;
  final String? descricao;
  final DateTime dataComeco;
  final DateTime dataFim;
  final DateTime criadoEm;

  Eleicao({
    required this.id,
    required this.titulo,
    this.descricao,
    required this.dataComeco,
    required this.dataFim,
    required this.criadoEm,
  });

  factory Eleicao.fromJson(Map<String, dynamic> json) {
    return Eleicao(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      descricao: json['descricao'] as String?,
      dataComeco: DateTime.parse(json['data_comeco'] as String),
      dataFim: DateTime.parse(json['data_fim'] as String),
      criadoEm: DateTime.parse(json['criado_em'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'descricao': descricao,
      'data_comeco': dataComeco.toIso8601String(),
      'data_fim': dataFim.toIso8601String(),
      'criado_em': criadoEm.toIso8601String(),
    };
  }
}
