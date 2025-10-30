import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/election_results.dart';
import '../services/voting_service.dart';

class ElectionResultsScreen extends StatefulWidget {
  final String electionId;

  const ElectionResultsScreen({super.key, required this.electionId});

  @override
  State<ElectionResultsScreen> createState() => _ElectionResultsScreenState();
}

class _ElectionResultsScreenState extends State<ElectionResultsScreen> {
  final VotingService _votingService = VotingService();
  Future<ElectionResults>? _resultsFuture;
  bool _showPieChart = true;

  @override
  void initState() {
    super.initState();
    _resultsFuture = _votingService.getElectionResults(widget.electionId);
  }

  Future<void> _generateAndPrintPDF(ElectionResults results) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Resultados da Eleição',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                results.electionTitle,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (results.electionDescription != null) ...[
                pw.SizedBox(height: 10),
                pw.Text(results.electionDescription!),
              ],
              pw.SizedBox(height: 20),
              pw.Text(
                'Período: ${results.electionStart.day}/${results.electionStart.month}/${results.electionStart.year} - ${results.electionEnd.day}/${results.electionEnd.month}/${results.electionEnd.year}',
              ),
              pw.Text('Total de Votos: ${results.totalVotes}'),
              pw.Text(
                'Gerado em: ${results.resultsGeneratedAt.day}/${results.resultsGeneratedAt.month}/${results.resultsGeneratedAt.year} ${results.resultsGeneratedAt.hour}:${results.resultsGeneratedAt.minute.toString().padLeft(2, '0')}',
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'Resultados:',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Posição',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Candidato',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Votos',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Percentagem',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  ...results.candidateResults.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final candidate = entry.value;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(index.toString()),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(candidate.candidateName),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(candidate.voteCount.toString()),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '${candidate.percentage.toStringAsFixed(1)}%',
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              if (results.winners.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Vencedor${results.winners.length > 1 ? 'es' : ''}:',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                ...results.winners.map(
                  (winner) => pw.Text(
                    '${winner.candidateName} - ${winner.voteCount} votos (${winner.percentage.toStringAsFixed(1)}%)',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultados da Eleição'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_showPieChart ? Icons.bar_chart : Icons.pie_chart),
            onPressed: () {
              setState(() {
                _showPieChart = !_showPieChart;
              });
            },
            tooltip:
                _showPieChart
                    ? 'Mostrar gráfico de barras'
                    : 'Mostrar gráfico de pizza',
          ),
        ],
      ),
      body: FutureBuilder<ElectionResults>(
        future: _resultsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Erro ao carregar resultados: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _resultsFuture = _votingService.getElectionResults(
                          widget.electionId,
                        );
                      });
                    },
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData) {
            return const Center(child: Text('Nenhum resultado encontrado.'));
          } else {
            final results = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Election Info Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Text(
                            results.electionTitle,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (results.electionDescription != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              results.electionDescription!,
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${results.electionStart.day}/${results.electionStart.month}/${results.electionStart.year} - ${results.electionEnd.day}/${results.electionEnd.month}/${results.electionEnd.year}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Total de Votos: ${results.totalVotes}',
                              style: TextStyle(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Chart
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Distribuição de Votos',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 300,
                            child:
                                _showPieChart
                                    ? _buildPieChart(results)
                                    : _buildBarChart(results),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Results Table
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tabela de Resultados',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Posição')),
                                DataColumn(label: Text('Candidato')),
                                DataColumn(label: Text('Votos')),
                                DataColumn(label: Text('Percentagem')),
                              ],
                              rows:
                                  results.candidateResults.asMap().entries.map((
                                    entry,
                                  ) {
                                    final index = entry.key + 1;
                                    final candidate = entry.value;
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(index.toString())),
                                        DataCell(Text(candidate.candidateName)),
                                        DataCell(
                                          Text(candidate.voteCount.toString()),
                                        ),
                                        DataCell(
                                          Text(
                                            '${candidate.percentage.toStringAsFixed(1)}%',
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Winner Announcement
                  if (results.winners.isNotEmpty) ...[
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.emoji_events,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              results.winners.length == 1
                                  ? 'Vencedor'
                                  : 'Vencedores',
                              style: Theme.of(
                                context,
                              ).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...results.winners.map(
                              (winner) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Text(
                                  '${winner.candidateName}\n${winner.voteCount} votos (${winner.percentage.toStringAsFixed(1)}%)',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Print Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _generateAndPrintPDF(results),
                      icon: const Icon(Icons.print),
                      label: const Text('Imprimir Resultados'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildPieChart(ElectionResults results) {
    final sections =
        results.candidateResults.map((candidate) {
          final colorIndex =
              results.candidateResults.indexOf(candidate) % _chartColors.length;
          return PieChartSectionData(
            value: candidate.percentage,
            title: '${candidate.percentage.toStringAsFixed(1)}%',
            color: _chartColors[colorIndex],
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList();

    return PieChart(
      PieChartData(sections: sections, sectionsSpace: 2, centerSpaceRadius: 40),
    );
  }

  Widget _buildBarChart(ElectionResults results) {
    final barGroups =
        results.candidateResults.asMap().entries.map((entry) {
          final index = entry.key;
          final candidate = entry.value;
          final colorIndex = index % _chartColors.length;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: candidate.percentage,
                color: _chartColors[colorIndex],
                width: 20,
              ),
            ],
          );
        }).toList();

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < results.candidateResults.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      results.candidateResults[index].candidateName,
                      style: const TextStyle(fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 60,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text('${value.toStringAsFixed(0)}%');
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true),
      ),
    );
  }
}

const _chartColors = [
  Colors.blue,
  Colors.red,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.pink,
  Colors.teal,
  Colors.indigo,
  Colors.amber,
  Colors.cyan,
];
