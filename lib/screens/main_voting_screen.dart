import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/eleicao.dart';
import '../models/candidato.dart';
import '../services/voting_service.dart';
import 'user_registration_screen.dart';
import 'election_creation_screen.dart';
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
    print('Current date: $now');
    final response = await Supabase.instance.client
        .from('eleicoes')
        .select('*')
        .lte('data_comeco', now.toIso8601String())
        .gte('data_fim', now.toIso8601String())
        .limit(1);
    print('Supabase response: $response');
    if (response.isNotEmpty) {
      final eleicao = Eleicao.fromJson(response[0]);
      print(
        'Active election: ${eleicao.titulo}, Start: ${eleicao.dataComeco}, End: ${eleicao.dataFim}',
      );
      return eleicao;
    }
    return null;
  }

  Future<List<Candidato>> _fetchCandidatos(String eleicaoId) async {
    final response = await Supabase.instance.client
        .from('candidatos')
        .select('*')
        .eq('eleicao_id', eleicaoId);
    print('Candidatos response: $response');
    final candidatos =
        (response as List<dynamic>)
            .map((json) => Candidato.fromJson(json))
            .toList();
    print('Parsed candidatos: ${candidatos.length} items');
    return candidatos;
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
        if (hasRights) {
          // Fetch the token from the database
          final tokenResponse = await Supabase.instance.client
              .from('tokens')
              .select('token')
              .eq('eleicao_id', eleicao.id)
              .eq('usado', false)
              .limit(1);
          if (tokenResponse.isNotEmpty) {
            setState(() {
              _token = tokenResponse[0]['token'];
              _hasToken = true;
            });
          } else {
            setState(() {
              _hasToken = false;
            });
          }
        } else {
          setState(() {
            _hasToken = false;
          });
        }
      }
    }
  }

  void _vote() async {
    if (_selectedCandidatoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a candidate to vote for.')),
      );
      return;
    }

    if (!_hasToken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You need a voting token to vote. Please request one first.',
          ),
        ),
      );
      return;
    }

    try {
      final eleicao = await _eleicaoFuture;
      if (eleicao != null) {
        await _votingService.votar(_token!, eleicao.id, _selectedCandidatoId!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vote submitted successfully!')),
        );
        setState(() {
          _selectedCandidatoId = null; // Reset selection after voting
          _hasToken = false; // Token used
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error submitting vote: $e')));
    }
  }

  void _logout() {
    Supabase.instance.client.auth.signOut();
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
                      ).colorScheme.onPrimaryContainer.withOpacity(0.8),
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
                Navigator.of(context).pop(); // Close the drawer
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
                  Navigator.of(context).pop(); // Close the drawer
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
                  Navigator.of(context).pop(); // Close the drawer
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const UserRegistrationScreen(),
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
              onTap: () {
                Navigator.of(context).pop(); // Close the drawer
                _logout();
              },
            ),
          ],
        ),
      ),
      body: FutureBuilder<Eleicao?>(
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
                                (context) => const ElectionCreationScreen(),
                          ),
                        );
                      },
                      child: const Text('Criar eleição'),
                    ),
                  ],
                ),
              );
            } else {
              return const Center(child: Text('No active election found.'));
            }
          } else {
            final eleicao = snapshot.data!;
            // Start timer when election data is loaded
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _startTimer(eleicao.dataFim);
            });

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
                          ).colorScheme.primaryContainer.withOpacity(0.8),
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer.withOpacity(0.9),
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
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(_timeRemaining),
                                style: Theme.of(
                                  context,
                                ).textTheme.titleMedium?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tempo restante para votar',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Candidato>>(
                    future: _candidatosFuture ??= _fetchCandidatos(eleicao.id),
                    builder: (context, candidatosSnapshot) {
                      if (candidatosSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (candidatosSnapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading candidates: ${candidatosSnapshot.error}',
                          ),
                        );
                      } else if (!candidatosSnapshot.hasData ||
                          candidatosSnapshot.data!.isEmpty) {
                        return const Center(
                          child: Text('No candidates found.'),
                        );
                      } else {
                        final candidatos = candidatosSnapshot.data!;
                        return Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                itemCount: candidatos.length,
                                itemBuilder: (context, index) {
                                  final candidato = candidatos[index];
                                  final isSelected =
                                      _selectedCandidatoId == candidato.id;
                                  return Card(
                                    margin: const EdgeInsets.all(8.0),
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
                            ),
                            Container(
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
                                    'Vote',
                                    style: TextStyle(fontSize: 18.0),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
