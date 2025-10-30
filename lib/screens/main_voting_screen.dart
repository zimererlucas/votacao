import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/eleicao.dart';
import '../models/candidato.dart';
import '../services/voting_service.dart';
import 'user_registration_screen.dart';
import 'election_creation_screen.dart';
import 'election_management_screen.dart';
import 'nfc_config_screen.dart';

class MainVotingScreen extends StatefulWidget {
  final String userRole;

  const MainVotingScreen({super.key, required this.userRole});

  @override
  State<MainVotingScreen> createState() => _MainVotingScreenState();
}

class _MainVotingScreenState extends State<MainVotingScreen> {
  String? _selectedCandidatoId;
  Future<Eleicao?>? _eleicaoFuture;
  Future<List<Candidato>>? _candidatosFuture;
  Timer? _timer;
  Duration _timeRemaining = Duration.zero;
  final VotingService _votingService = VotingService();
  String? _token;
  bool _hasToken = false;

  @override
  void initState() {
    super.initState();
    _eleicaoFuture = _fetchEleicaoAtiva();
    _checkToken();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(DateTime endTime) {
    _timer?.cancel();
    _updateTimeRemaining(endTime);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimeRemaining(endTime);
    });
  }

  void _updateTimeRemaining(DateTime endTime) {
    final now = DateTime.now();
    final remaining = endTime.difference(now);
    if (remaining.isNegative) {
      setState(() {
        _timeRemaining = Duration.zero;
      });
      _timer?.cancel();
    } else {
      setState(() {
        _timeRemaining = remaining;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<Eleicao?> _fetchEleicaoAtiva() async {
    final now = DateTime.now();
    final response = await Supabase.instance.client
        .from('eleicoes')
        .select('*')
        .lte('data_comeco', now.toIso8601String())
        .gte('data_fim', now.toIso8601String())
        .limit(1);
    if (response.isNotEmpty) {
      return Eleicao.fromJson(response[0]);
    }
    return null;
  }

  Future<List<Candidato>> _fetchCandidatos(String eleicaoId) async {
    final response = await Supabase.instance.client
        .from('candidatos')
        .select('*')
        .eq('eleicao_id', eleicaoId);
    return (response as List<dynamic>)
        .map((json) => Candidato.fromJson(json))
        .toList();
  }

  Future<void> _checkToken() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final eleicao = await _eleicaoFuture;
      if (eleicao != null) {
        final hasRights = await _votingService.hasVotingRights(
          user.id,
          eleicao.id,
        );
        if (!mounted) return;

        if (hasRights) {
          final tokenResponse = await Supabase.instance.client
              .from('tokens')
              .select('token')
              .eq('eleicao_id', eleicao.id)
              .eq('usado', false)
              .limit(1);
          if (!mounted) return;

          setState(() {
            if (tokenResponse.isNotEmpty) {
              _token = tokenResponse[0]['token'];
              _hasToken = true;
            } else {
              _hasToken = false;
            }
          });
        } else {
          setState(() {
            _hasToken = false;
          });
        }
      }
    }
  }

  Future<void> _vote() async {
    if (!mounted) return;

    if (_selectedCandidatoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione um candidato')),
      );
      return;
    }

    if (!_hasToken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, utilize o seu cartão primeiro'),
        ),
      );
      return;
    }

    try {
      final eleicao = await _eleicaoFuture;
      if (!mounted) return;

      if (eleicao != null && _token != null) {
        await _votingService.votar(_token!, eleicao.id, _selectedCandidatoId!);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voto registado com sucesso!')),
        );
        setState(() {
          _selectedCandidatoId = null;
          _hasToken = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao submeter o voto: $e')));
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Votações'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              label: Text(
                widget.userRole,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            ),
          ),
          Builder(
            builder:
                (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () {
                    Scaffold.of(context).openEndDrawer();
                  },
                  tooltip: 'Configurações',
                ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.account_circle,
                    size: 48,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Configurações',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cargo: ${widget.userRole}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer.withAlpha(204),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.credit_card,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                'Configurar Cartão',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const NfcConfigScreen(),
                  ),
                );
              },
            ),
            if (widget.userRole == 'Administrador') ...[
              ListTile(
                leading: Icon(
                  Icons.how_to_vote,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  'Criar Eleição',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ElectionCreationScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.person_add,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  'Registar Utilizador',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const UserRegistrationScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.manage_accounts,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  'Gerir Eleições',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ElectionManagementScreen(),
                    ),
                  );
                },
              ),
              const Divider(),
            ],
            ListTile(
              leading: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Sair',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                await _logout();
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _candidatosFuture = null;
            _eleicaoFuture = _fetchEleicaoAtiva();
          });
          await _eleicaoFuture;
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            constraints: const BoxConstraints(minHeight: 600),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: FutureBuilder<Eleicao?>(
              future: _eleicaoFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data == null) {
                  if (widget.userRole == 'Administrador') {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Não está a decorrer nenhuma eleição'),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const ElectionCreationScreen(),
                                ),
                              );
                            },
                            child: const Text('Criar eleição'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return const Center(
                      child: Text('Não há eleições ativas no momento'),
                    );
                  }
                }

                final eleicao = snapshot.data!;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _startTimer(eleicao.dataFim);
                });

                if (_candidatosFuture == null) {
                  _candidatosFuture = _fetchCandidatos(eleicao.id);
                }
                return Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.all(16.0),
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primaryContainer,
                              Theme.of(
                                context,
                              ).colorScheme.primaryContainer.withAlpha(204),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              eleicao.titulo,
                              style: Theme.of(
                                context,
                              ).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (eleicao.descricao != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                eleicao.descricao!,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                      .withAlpha(230),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.timer,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDuration(_timeRemaining),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FutureBuilder<List<Candidato>>(
                      future: _candidatosFuture,
                      builder: (context, candidatosSnapshot) {
                        if (candidatosSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        } else if (candidatosSnapshot.hasError) {
                          return Center(
                            child: Text('Error: ${candidatosSnapshot.error}'),
                          );
                        } else if (!candidatosSnapshot.hasData ||
                            candidatosSnapshot.data!.isEmpty) {
                          return const Center(
                            child: Text('Nenhum candidato encontrado'),
                          );
                        }

                        final candidatos = candidatosSnapshot.data!;
                        return Column(
                          children: [
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: candidatos.length,
                              itemBuilder: (context, index) {
                                final candidato = candidatos[index];
                                final isSelected =
                                    _selectedCandidatoId == candidato.id;
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                    horizontal: 8.0,
                                  ),
                                  color:
                                      isSelected
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer
                                          : null,
                                  child: ListTile(
                                    title: Text(
                                      candidato.nomeCompleto,
                                      style: TextStyle(
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                    leading: Radio<String>(
                                      value: candidato.id,
                                      groupValue: _selectedCandidatoId,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedCandidatoId = value;
                                        });
                                      },
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedCandidatoId = candidato.id;
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _vote,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16.0,
                                    ),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                  child: const Text(
                                    'Votar',
                                    style: TextStyle(fontSize: 18.0),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
