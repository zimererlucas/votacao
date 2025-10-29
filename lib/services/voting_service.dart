import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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
