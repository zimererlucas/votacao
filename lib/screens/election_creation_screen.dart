import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: unused_import
import '../models/eleicao.dart';
// ignore: unused_import
import '../models/candidato.dart';

class ElectionCreationScreen extends StatefulWidget {
  const ElectionCreationScreen({super.key});

  @override
  State<ElectionCreationScreen> createState() => _ElectionCreationScreenState();
}

class _ElectionCreationScreenState extends State<ElectionCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  DateTime? _dataComeco;
  DateTime? _dataFim;
  final List<TextEditingController> _candidatoControllers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addCandidatoField(); // Start with one candidate field
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    for (var controller in _candidatoControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addCandidatoField() {
    setState(() {
      _candidatoControllers.add(TextEditingController());
    });
  }

  void _removeCandidatoField(int index) {
    if (_candidatoControllers.length > 1) {
      setState(() {
        _candidatoControllers[index].dispose();
        _candidatoControllers.removeAt(index);
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        final DateTime selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        );

        setState(() {
          if (isStartDate) {
            _dataComeco = selectedDateTime;
          } else {
            _dataFim = selectedDateTime;
          }
        });
      }
    }
  }

  Future<void> _createElection() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate dates
    if (_dataComeco == null || _dataFim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecione as datas de início e fim.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_dataFim!.isBefore(_dataComeco!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A data de fim deve ser posterior à data de início.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate candidates
    final candidatosValidos =
        _candidatoControllers
            .where((controller) => controller.text.trim().isNotEmpty)
            .toList();

    if (candidatosValidos.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deve haver pelo menos 2 candidatos.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create election
      final electionResponse =
          await Supabase.instance.client
              .from('eleicoes')
              .insert({
                'titulo': _tituloController.text.trim(),
                'descricao':
                    _descricaoController.text.trim().isEmpty
                        ? null
                        : _descricaoController.text.trim(),
                'data_comeco': _dataComeco!.toIso8601String(),
                'data_fim': _dataFim!.toIso8601String(),
              })
              .select()
              .single();

      final eleicaoId = electionResponse['id'];

      // Create candidates
      final candidatosData =
          candidatosValidos.map((controller) {
            return {
              'eleicao_id': eleicaoId,
              'nome_completo': controller.text.trim(),
            };
          }).toList();

      await Supabase.instance.client.from('candidatos').insert(candidatosData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eleição criada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Return to previous screen
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar eleição: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateTitulo(String? value) {
    if (value == null || value.isEmpty) {
      return 'Título é obrigatório';
    }
    if (value.length < 3) {
      return 'Título deve ter pelo menos 3 caracteres';
    }
    return null;
  }

  String? _validateCandidato(String? value, int index) {
    if (value == null || value.trim().isEmpty) {
      return 'Nome do candidato é obrigatório';
    }
    if (value.trim().length < 2) {
      return 'Nome deve ter pelo menos 2 caracteres';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Nova Eleição'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.how_to_vote,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Criar Nova Eleição',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Preencha os detalhes da eleição e adicione os candidatos',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Election Title
                      TextFormField(
                        controller: _tituloController,
                        decoration: InputDecoration(
                          labelText: 'Título da Eleição',
                          prefixIcon: const Icon(Icons.title),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: _validateTitulo,
                      ),
                      const SizedBox(height: 16),

                      // Election Description
                      TextFormField(
                        controller: _descricaoController,
                        decoration: InputDecoration(
                          labelText: 'Descrição (Opcional)',
                          prefixIcon: const Icon(Icons.description),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Start Date
                      InkWell(
                        onTap: () => _selectDate(context, true),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Data de Início',
                            prefixIcon: const Icon(Icons.calendar_today),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _dataComeco != null
                                ? '${_dataComeco!.day}/${_dataComeco!.month}/${_dataComeco!.year} ${_dataComeco!.hour.toString().padLeft(2, '0')}:${_dataComeco!.minute.toString().padLeft(2, '0')}'
                                : 'Selecionar data e hora',
                            style: TextStyle(
                              color:
                                  _dataComeco != null
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // End Date
                      InkWell(
                        onTap: () => _selectDate(context, false),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Data de Fim',
                            prefixIcon: const Icon(Icons.calendar_today),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _dataFim != null
                                ? '${_dataFim!.day}/${_dataFim!.month}/${_dataFim!.year} ${_dataFim!.hour.toString().padLeft(2, '0')}:${_dataFim!.minute.toString().padLeft(2, '0')}'
                                : 'Selecionar data e hora',
                            style: TextStyle(
                              color:
                                  _dataFim != null
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Candidates Section
                      Row(
                        children: [
                          Text(
                            'Candidatos',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _addCandidatoField,
                            icon: Icon(
                              Icons.add_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            tooltip: 'Adicionar Candidato',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Candidate Fields
                      ...List.generate(_candidatoControllers.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _candidatoControllers[index],
                                  decoration: InputDecoration(
                                    labelText: 'Nome do Candidato ${index + 1}',
                                    prefixIcon: const Icon(Icons.person),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator:
                                      (value) =>
                                          _validateCandidato(value, index),
                                ),
                              ),
                              if (_candidatoControllers.length > 1)
                                IconButton(
                                  onPressed: () => _removeCandidatoField(index),
                                  icon: Icon(
                                    Icons.remove_circle,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  tooltip: 'Remover Candidato',
                                ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 32),

                      // Create Election Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createElection,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text(
                                    'Criar Eleição',
                                    style: TextStyle(fontSize: 16),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
