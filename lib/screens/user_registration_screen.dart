import 'package:flutter/material.dart';
import '../services/usuario_service.dart';

class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({super.key});

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _nomeController = TextEditingController();
  String _cargo = 'Eleitor';
  bool _loading = false;
  String? _mensagem;

  final UsuarioService _usuarioService = UsuarioService();

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _adicionarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _mensagem = null;
    });

    try {
      await _usuarioService.adicionarUsuario(
        email: _emailController.text.trim(),
        senha: _senhaController.text,
        nome: _nomeController.text.trim(),
        cargo: _cargo,
      );

      setState(() {
        _mensagem = 'Usuário registrado com sucesso!';
      });

      _emailController.clear();
      _senhaController.clear();
      _nomeController.clear();
      setState(() => _cargo = 'Eleitor');
    } catch (e) {
      setState(() {
        _mensagem = 'Erro: ${e.toString()}';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email é obrigatório';
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value)) return 'Email inválido';
    return null;
  }

  String? _validateSenha(String? value) {
    if (value == null || value.isEmpty) return 'Senha é obrigatória';
    if (value.length < 6) return 'Senha deve ter ao menos 6 caracteres';
    return null;
  }

  String? _validateNome(String? value) {
    if (value == null || value.isEmpty) return 'Nome completo é obrigatório';
    if (value.length < 2) return 'Nome muito curto';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Novo Usuário')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Nome
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome completo',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: _validateNome,
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),

              // Senha
              TextFormField(
                controller: _senhaController,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: _validateSenha,
              ),
              const SizedBox(height: 16),

              // Cargo
              DropdownButtonFormField<String>(
                value: _cargo,
                items: const [
                  DropdownMenuItem(value: 'Eleitor', child: Text('Eleitor')),
                  DropdownMenuItem(
                    value: 'Administrador',
                    child: Text('Administrador'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _cargo = v);
                },
                decoration: const InputDecoration(
                  labelText: 'Cargo',
                  prefixIcon: Icon(Icons.work),
                ),
              ),
              const SizedBox(height: 24),

              // Botão
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _adicionarUsuario,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child:
                      _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Adicionar'),
                ),
              ),

              const SizedBox(height: 16),
              // Caixa de mensagem de sucesso/erro
              if (_mensagem != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color:
                        _mensagem!.startsWith('Erro')
                            ? Colors.red
                            : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    _mensagem!, // texto agora selecionável
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
