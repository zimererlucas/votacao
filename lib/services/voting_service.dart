import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/candidato.dart';
import '../models/eleicao.dart';
import '../models/election_results.dart';

class VotingService {
  final supabase = Supabase.instance.client;

  /// Checks if the user has voting rights for the given election
  Future<bool> hasVotingRights(String userId, String eleicaoId) async {
    final response =
        await supabase
            .from('direito_voto')
            .select('ja_recebeu_token')
            .eq('usuario_id', userId)
            .eq('eleicao_id', eleicaoId)
            .maybeSingle();

    return response != null && response['ja_recebeu_token'] == false;
  }

  /// End an election by setting its end date to now
  Future<void> endElection(String eleicaoId) async {
    await supabase
        .from('eleicoes')
        .update({'data_fim': DateTime.now().toIso8601String()})
        .eq('id', eleicaoId);
  }

  Future<void> updateElectionDates(
    String eleicaoId,
    DateTime start,
    DateTime end,
  ) async {
    await supabase
        .from('eleicoes')
        .update({
          'data_comeco': start.toIso8601String(),
          'data_fim': end.toIso8601String(),
        })
        .eq('id', eleicaoId);
  }

  Future<void> updateElectionDescription(
    String eleicaoId,
    String? description,
  ) async {
    await supabase
        .from('eleicoes')
        .update({'descricao': description})
        .eq('id', eleicaoId);
  }

  Future<List<Candidato>> getCandidatesForElection(String eleicaoId) async {
    final response = await supabase
        .from('candidatos')
        .select('*')
        .eq('eleicao_id', eleicaoId)
        .order('criado_em', ascending: true);

    return (response as List<dynamic>)
        .map((json) => Candidato.fromJson(json))
        .toList();
  }

  Future<void> addCandidate(String eleicaoId, String nomeCompleto) async {
    await supabase.from('candidatos').insert({
      'eleicao_id': eleicaoId,
      'nome_completo': nomeCompleto,
    });
  }

  Future<void> updateCandidate(String candidatoId, String nomeCompleto) async {
    await supabase
        .from('candidatos')
        .update({'nome_completo': nomeCompleto})
        .eq('id', candidatoId);
  }

  Future<void> deleteCandidate(String candidatoId) async {
    await supabase.from('candidatos').delete().eq('id', candidatoId);
  }

  Future<ElectionResults> getElectionResults(String eleicaoId) async {
    // Fetch election info
    final eleicaoResp =
        await supabase
            .from('eleicoes')
            .select('*')
            .eq('id', eleicaoId)
            .maybeSingle();

    if (eleicaoResp == null) {
      throw Exception('Eleição não encontrada');
    }
    final eleicao = Eleicao.fromJson(eleicaoResp);

    // Fetch candidates
    final candidatos = await getCandidatesForElection(eleicaoId);

    // Fetch votes
    final votosResp = await supabase
        .from('votos')
        .select('*')
        .eq('eleicao_id', eleicaoId);
    final votos = (votosResp as List<dynamic>);
    final totalVotes = votos.length;

    // Count votes per candidate
    final List<CandidateResult> candidateResults =
        candidatos.map((c) {
          final count = votos.where((v) => v['candidato_id'] == c.id).length;
          final percentage = totalVotes > 0 ? (count / totalVotes) * 100 : 0.0;
          return CandidateResult(
            candidateId: c.id,
            candidateName: c.nomeCompleto,
            voteCount: count,
            percentage: percentage,
          );
        }).toList();

    candidateResults.sort((a, b) => b.voteCount.compareTo(a.voteCount));

    final winners = <CandidateResult>[];
    if (candidateResults.isNotEmpty) {
      final topCount = candidateResults.first.voteCount;
      winners.addAll(candidateResults.where((c) => c.voteCount == topCount));
    }

    return ElectionResults(
      electionId: eleicao.id,
      electionTitle: eleicao.titulo,
      electionDescription: eleicao.descricao,
      electionStart: eleicao.dataComeco,
      electionEnd: eleicao.dataFim,
      totalVotes: totalVotes,
      resultsGeneratedAt: DateTime.now(),
      candidateResults: candidateResults,
      winners: winners,
    );
  }

  /// Requests a token for voting in the given election
  Future<String> pedirToken(String eleicaoId) async {
    final userId = supabase.auth.currentUser!.id;

    // Check if user has voting rights
    final hasRights = await hasVotingRights(userId, eleicaoId);
    if (!hasRights) {
      throw Exception(
        'Você não tem direito a voto nesta eleição ou já recebeu um token.',
      );
    }

    // Generate unique token
    final token = const Uuid().v4();

    // Insert token into database
    await supabase.from('tokens').insert({
      'eleicao_id': eleicaoId,
      'token': token,
      'usado': false,
    });

    // Update voting rights
    await supabase
        .from('direito_voto')
        .update({'ja_recebeu_token': true})
        .eq('usuario_id', userId)
        .eq('eleicao_id', eleicaoId);
    return token;
  }

  /// Casts an anonymous vote using the token
  Future<void> votar(String token, String eleicaoId, String candidatoId) async {
    // Verify token exists and is not used
    final tokenResponse =
        await supabase
            .from('tokens')
            .select('usado, eleicao_id')
            .eq('token', token)
            .single();

    if (tokenResponse['usado'] == true) {
      throw Exception('Este token já foi usado.');
    }

    if (tokenResponse['eleicao_id'] != eleicaoId) {
      throw Exception('Token inválido para esta eleição.');
    }

    // Insert vote anonymously
    await supabase.from('votos').insert({
      'eleicao_id': eleicaoId,
      'candidato_id': candidatoId,
      'token': token,
    });

    // Mark token as used (assuming database trigger handles this, but we can update manually if needed)
    // Note: In a real implementation, use database triggers for atomicity
  }
}
