class CandidateResult {
  final String candidateId;
  final String candidateName;
  final int voteCount;
  final double percentage;

  CandidateResult({
    required this.candidateId,
    required this.candidateName,
    required this.voteCount,
    required this.percentage,
  });

  factory CandidateResult.fromJson(Map<String, dynamic> json) {
    return CandidateResult(
      candidateId: json['candidateId'] as String,
      candidateName: json['candidateName'] as String,
      voteCount: json['voteCount'] as int,
      percentage: (json['percentage'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'candidateId': candidateId,
    'candidateName': candidateName,
    'voteCount': voteCount,
    'percentage': percentage,
  };
}

class ElectionResults {
  final String electionId;
  final String electionTitle;
  final String? electionDescription;
  final DateTime electionStart;
  final DateTime electionEnd;
  final int totalVotes;
  final DateTime resultsGeneratedAt;
  final List<CandidateResult> candidateResults;
  final List<CandidateResult> winners;

  ElectionResults({
    required this.electionId,
    required this.electionTitle,
    this.electionDescription,
    required this.electionStart,
    required this.electionEnd,
    required this.totalVotes,
    required this.resultsGeneratedAt,
    required this.candidateResults,
    required this.winners,
  });

  factory ElectionResults.fromJson(Map<String, dynamic> json) {
    return ElectionResults(
      electionId: json['electionId'] as String,
      electionTitle: json['electionTitle'] as String,
      electionDescription: json['electionDescription'] as String?,
      electionStart: DateTime.parse(json['electionStart'] as String),
      electionEnd: DateTime.parse(json['electionEnd'] as String),
      totalVotes: json['totalVotes'] as int,
      resultsGeneratedAt: DateTime.parse(json['resultsGeneratedAt'] as String),
      candidateResults:
          (json['candidateResults'] as List<dynamic>)
              .map((e) => CandidateResult.fromJson(e as Map<String, dynamic>))
              .toList(),
      winners:
          (json['winners'] as List<dynamic>)
              .map((e) => CandidateResult.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'electionId': electionId,
    'electionTitle': electionTitle,
    'electionDescription': electionDescription,
    'electionStart': electionStart.toIso8601String(),
    'electionEnd': electionEnd.toIso8601String(),
    'totalVotes': totalVotes,
    'resultsGeneratedAt': resultsGeneratedAt.toIso8601String(),
    'candidateResults': candidateResults.map((e) => e.toJson()).toList(),
    'winners': winners.map((e) => e.toJson()).toList(),
  };
}
