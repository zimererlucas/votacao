import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class UsuarioService {
  final SupabaseClient supabase = Supabase.instance.client;

  /// Adiciona um novo usuário via Edge Function segura
  Future<void> adicionarUsuario({
    required String email,
    required String senha,
    required String nome,
    String cargo = 'Eleitor',
  }) async {
    // 1️⃣ Obtém a sessão atual
    final session = supabase.auth.currentSession;
    final userLogado = session?.user;
    final token = session?.accessToken;

    if (userLogado == null || token == null) {
      throw Exception('Nenhum usuário logado ou sessão inválida.');
    }

    final userId = userLogado.id.trim();
    // 2️⃣ Valida se é um UUID
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    if (!uuidRegex.hasMatch(userId)) {
      throw Exception('ID do usuário logado inválido: $userId');
    }

    // 3️⃣ URL da Edge Function
    final url = Uri.parse(
      'https://kyfsvxkuihntaswvnmxl.supabase.co/functions/v1/criarUsuario',
    );

    // 4️⃣ Faz a requisição POST para a Edge Function
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // JWT do usuário logado
      },
      body: jsonEncode({
        'usuarioId': userId,
        'email': email.trim(),
        'senha': senha,
        'nome': nome.trim(),
        'cargo': cargo,
      }),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode != 200) {
      debugPrint('Erro na Edge Function: ${response.body}');
      throw Exception(body['error'] ?? 'Erro desconhecido');
    }
  }
}
