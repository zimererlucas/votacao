import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NfcConfigScreen extends StatefulWidget {
  const NfcConfigScreen({super.key});

  @override
  State<NfcConfigScreen> createState() => _NfcConfigScreenState();
}

class _NfcConfigScreenState extends State<NfcConfigScreen> {
  String? _tagId;
  bool _isReading = false;
  bool _hasTag = false;
  String? _currentTag;

  @override
  void initState() {
    super.initState();
    _checkCurrentTag();
  }

  Future<void> _checkCurrentTag() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final response =
          await Supabase.instance.client
              .from('perfis')
              .select('tag_nfc')
              .eq('id', user.id)
              .single();

      debugPrint('Usuário atual: ${user.id}');
      debugPrint('Tag atual do Supabase: ${response['tag_nfc']}');

      setState(() {
        _currentTag = response['tag_nfc'];
        _hasTag = _currentTag != null;
      });
    }
  }

  // Função auxiliar para converter lista de bytes em HEX
  String toHexString(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
  }

  Future<void> _startNfcReading() async {
    if (_isReading) return;

    debugPrint('Iniciando leitura NFC...');
    setState(() {
      _isReading = true;
      _tagId = null;
    });

    try {
      final isAvailable = await NfcManager.instance.isAvailable();
      debugPrint('NFC disponível? $isAvailable');

      if (!isAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NFC não está disponível neste dispositivo.'),
          ),
        );
        setState(() => _isReading = false);
        return;
      }

      await NfcManager.instance.stopSession(); // garante sessão limpa

      NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          debugPrint('Tag descoberta: $tag');

          try {
            String hexCode = 'Código Hex não encontrado';

            if (tag.data is Map) {
              debugPrint('tag.data é Map, iniciando parsing...');
              final data = Map<String, dynamic>.from(tag.data as Map);
              data.forEach((key, value) {
                debugPrint('Chave principal: $key -> $value');
                if (value is Map) {
                  value.forEach((subKey, subValue) {
                    debugPrint('SubKey: $subKey -> $subValue');
                    if (subKey == 'identifier' && subValue is List<int>) {
                      hexCode = toHexString(subValue);
                      debugPrint('HEX encontrado: $hexCode');
                    }
                  });
                }
              });
            } else {
              debugPrint('tag.data não é Map!');
            }

            setState(() => _tagId = hexCode);
          } catch (e, stack) {
            debugPrint('Erro ao processar tag: $e\n$stack');
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Erro ao ler NFC: $e')));
          } finally {
            debugPrint('Finalizando sessão NFC...');
            await NfcManager.instance.stopSession();
            setState(() => _isReading = false);
          }
        },
      );
    } catch (e, stack) {
      debugPrint('Erro geral NFC: $e\n$stack');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
      await NfcManager.instance.stopSession();
      setState(() => _isReading = false);
    }
  }

  Future<void> _saveTag() async {
    if (_tagId == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    debugPrint('Salvando tag $_tagId para o usuário ${user.id}');

    try {
      await Supabase.instance.client
          .from('perfis')
          .update({'tag_nfc': _tagId})
          .eq('id', user.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tag NFC associada com sucesso!')),
      );

      setState(() {
        _currentTag = _tagId;
        _hasTag = true;
        _tagId = null;
      });
    } catch (e) {
      debugPrint('Erro ao salvar tag: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar tag: $e')));
    }
  }

  Future<void> _reconfigureTag() async {
    debugPrint('Reconfigurando tag...');
    setState(() {
      _hasTag = false;
      _currentTag = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar Cartão')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hasTag) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sua conta já está associada a um cartão.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Tag atual: $_currentTag'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _reconfigureTag,
                        child: const Text('Reconfigurar'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Text(
                'Aproxime o cartão NFC do dispositivo para associar.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isReading ? null : _startNfcReading,
                  icon: const Icon(Icons.nfc),
                  label: Text(_isReading ? 'Lendo...' : 'Ler Cartão'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              if (_tagId != null) ...[
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tag ID: $_tagId'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _saveTag,
                          child: const Text('Associar Cartão'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
