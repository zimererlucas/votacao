import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/eleicao.dart';
import '../models/candidato.dart';
import '../services/voting_service.dart';
import 'election_results_screen.dart';

class ElectionManagementScreen extends StatefulWidget {
  const ElectionManagementScreen({super.key});

  @override
  State<ElectionManagementScreen> createState() =>
      _ElectionManagementScreenState();
}

class _ElectionManagementScreenState extends State<ElectionManagementScreen> {
  final VotingService _votingService = VotingService();
  Future<List<Eleicao>>? _electionsFuture;
  final Set<String> _endingElections = {};

  @override
  void initState() {
    super.initState();
    _loadElections();
  }

  void _loadElections() {
    setState(() {
      _electionsFuture = _fetchAllElections();
    });
  }

  Future<List<Eleicao>> _fetchAllElections() async {
    final response = await Supabase.instance.client
        .from('eleicoes')
        .select('*')
        .order('criado_em', ascending: false);

    return (response as List<dynamic>)
        .map((json) => Eleicao.fromJson(json))
        .toList();
  }

  Future<void> _endElection(String electionId, String electionTitle) async {
    if (_endingElections.contains(electionId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Terminar Eleição'),
          content: Text(
            'Tem certeza que deseja terminar a eleição "$electionTitle"? Esta ação não pode ser desfeita.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Terminar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        _endingElections.add(electionId);
      });

      try {
        await _votingService.endElection(electionId);
        _loadElections(); // Refresh the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Eleição terminada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao terminar eleição: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _endingElections.remove(electionId);
          });
        }
      }
    }
  }

  String _getElectionStatus(Eleicao eleicao) {
    final now = DateTime.now();
    if (now.isBefore(eleicao.dataComeco)) {
      return 'Agendada';
    } else if (now.isAfter(eleicao.dataFim)) {
      return 'Terminada';
    } else {
      return 'Ativa';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Ativa':
        return Colors.green;
      case 'Terminada':
        return Colors.grey;
      case 'Agendada':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showEditElectionDialog(Eleicao eleicao) async {
    final startDateController = TextEditingController(
      text:
          '${eleicao.dataComeco.year}-${eleicao.dataComeco.month.toString().padLeft(2, '0')}-${eleicao.dataComeco.day.toString().padLeft(2, '0')} ${eleicao.dataComeco.hour.toString().padLeft(2, '0')}:${eleicao.dataComeco.minute.toString().padLeft(2, '0')}',
    );
    final endDateController = TextEditingController(
      text:
          '${eleicao.dataFim.year}-${eleicao.dataFim.month.toString().padLeft(2, '0')}-${eleicao.dataFim.day.toString().padLeft(2, '0')} ${eleicao.dataFim.hour.toString().padLeft(2, '0')}:${eleicao.dataFim.minute.toString().padLeft(2, '0')}',
    );
    final descriptionController = TextEditingController(
      text: eleicao.descricao ?? '',
    );

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Editar Eleição: ${eleicao.titulo}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: startDateController,
                  decoration: const InputDecoration(
                    labelText: 'Data de Início (YYYY-MM-DD HH:MM)',
                    hintText: '2024-01-01 09:00',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: endDateController,
                  decoration: const InputDecoration(
                    labelText: 'Data de Fim (YYYY-MM-DD HH:MM)',
                    hintText: '2024-01-01 18:00',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final startDate = DateTime.parse(
                    startDateController.text.replaceAll(' ', 'T'),
                  );
                  final endDate = DateTime.parse(
                    endDateController.text.replaceAll(' ', 'T'),
                  );
                  final description =
                      descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim();

                  await _votingService.updateElectionDates(
                    eleicao.id,
                    startDate,
                    endDate,
                  );
                  await _votingService.updateElectionDescription(
                    eleicao.id,
                    description,
                  );

                  _loadElections();
                  Navigator.of(context).pop();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Eleição atualizada com sucesso!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erro ao atualizar eleição: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showManageCandidatesDialog(Eleicao eleicao) async {
    Future<List<Candidato>>? candidatesFuture;

    void loadCandidates() {
      candidatesFuture = _votingService.getCandidatesForElection(eleicao.id);
    }

    loadCandidates();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Gerir Candidatos: ${eleicao.titulo}'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final nameController = TextEditingController();
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Adicionar Candidato'),
                              content: TextField(
                                controller: nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Nome Completo',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(true),
                                  child: const Text('Adicionar'),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmed == true &&
                            nameController.text.trim().isNotEmpty) {
                          try {
                            await _votingService.addCandidate(
                              eleicao.id,
                              nameController.text.trim(),
                            );
                            loadCandidates();
                            setState(() {});
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Candidato adicionado com sucesso!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Erro ao adicionar candidato: $e',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar Candidato'),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Candidato>>(
                      future: candidatesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return Text('Erro: ${snapshot.error}');
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Text('Nenhum candidato encontrado.');
                        } else {
                          final candidates = snapshot.data!;
                          return SizedBox(
                            height: 200,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: candidates.length,
                              itemBuilder: (context, index) {
                                final candidate = candidates[index];
                                return ListTile(
                                  title: Text(candidate.nomeCompleto),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () async {
                                          final nameController =
                                              TextEditingController(
                                                text: candidate.nomeCompleto,
                                              );
                                          final confirmed = await showDialog<
                                            bool
                                          >(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                title: const Text(
                                                  'Editar Candidato',
                                                ),
                                                content: TextField(
                                                  controller: nameController,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText:
                                                            'Nome Completo',
                                                      ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.of(
                                                          context,
                                                        ).pop(false),
                                                    child: const Text(
                                                      'Cancelar',
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed:
                                                        () => Navigator.of(
                                                          context,
                                                        ).pop(true),
                                                    child: const Text('Salvar'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );

                                          if (confirmed == true &&
                                              nameController.text
                                                  .trim()
                                                  .isNotEmpty) {
                                            try {
                                              await _votingService
                                                  .updateCandidate(
                                                    candidate.id,
                                                    nameController.text.trim(),
                                                  );
                                              loadCandidates();
                                              setState(() {});
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Candidato atualizado com sucesso!',
                                                    ),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Erro ao atualizar candidato: $e',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () async {
                                          final confirmed = await showDialog<
                                            bool
                                          >(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                title: const Text(
                                                  'Remover Candidato',
                                                ),
                                                content: Text(
                                                  'Tem certeza que deseja remover "${candidate.nomeCompleto}"?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.of(
                                                          context,
                                                        ).pop(false),
                                                    child: const Text(
                                                      'Cancelar',
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed:
                                                        () => Navigator.of(
                                                          context,
                                                        ).pop(true),
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.red,
                                                          foregroundColor:
                                                              Colors.white,
                                                        ),
                                                    child: const Text(
                                                      'Remover',
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );

                                          if (confirmed == true) {
                                            try {
                                              await _votingService
                                                  .deleteCandidate(
                                                    candidate.id,
                                                  );
                                              loadCandidates();
                                              setState(() {});
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Candidato removido com sucesso!',
                                                    ),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Erro ao remover candidato: $e',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerir Eleições'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<List<Eleicao>>(
        future: _electionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Erro ao carregar eleições: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma eleição encontrada.'));
          } else {
            final elections = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: elections.length,
              itemBuilder: (context, index) {
                final eleicao = elections[index];
                final status = _getElectionStatus(eleicao);
                final isActive = status == 'Ativa';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                eleicao.titulo,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Chip(
                              label: Text(
                                status,
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: _getStatusColor(status),
                            ),
                          ],
                        ),
                        if (eleicao.descricao != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            eleicao.descricao!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Início: ${eleicao.dataComeco.day}/${eleicao.dataComeco.month}/${eleicao.dataComeco.year} ${eleicao.dataComeco.hour.toString().padLeft(2, '0')}:${eleicao.dataComeco.minute.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Fim: ${eleicao.dataFim.day}/${eleicao.dataFim.month}/${eleicao.dataFim.year} ${eleicao.dataFim.hour.toString().padLeft(2, '0')}:${eleicao.dataFim.minute.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        if (status != 'Terminada') ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      () => _showEditElectionDialog(eleicao),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Editar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      () =>
                                          _showManageCandidatesDialog(eleicao),
                                  icon: const Icon(Icons.people),
                                  label: const Text('Candidatos'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.secondary,
                                    foregroundColor:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        // Button to view results (visible to admin even if election active/terminated)
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) => ElectionResultsScreen(
                                        electionId: eleicao.id,
                                      ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.bar_chart),
                            label: const Text('Ver Resultados'),
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _endingElections.contains(eleicao.id)
                                      ? null
                                      : () => _endElection(
                                        eleicao.id,
                                        eleicao.titulo,
                                      ),
                              icon:
                                  _endingElections.contains(eleicao.id)
                                      ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Icon(Icons.stop),
                              label:
                                  _endingElections.contains(eleicao.id)
                                      ? const Text('Terminando...')
                                      : const Text('Terminar Eleição'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onError,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
