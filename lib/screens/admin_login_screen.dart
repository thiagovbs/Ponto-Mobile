import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import '../services/api_service.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _cpfController = TextEditingController(); // 🪛 Mudou para CPF
  final _senhaController = TextEditingController();
  bool _carregando = false;

  Future<void> _fazerLogin() async {
    // Remove pontos e traços se você preferir enviar apenas os 11 números limpos para a API
    final cpfLimpo = _cpfController.text.replaceAll('.', '').replaceAll('-', '').trim();

    if (cpfLimpo.isEmpty || _senhaController.text.isEmpty) {
      _mostrarErro('Preencha todos os campos.');
      return;
    }

    if (cpfLimpo.length != 11) {
      _mostrarErro('O CPF informado está incompleto.');
      return;
    }

    setState(() => _carregando = true);

    try {
      // 🪛 Enviando 'cpf' no payload em vez de 'email'
      final response = await ApiService.dio.post('/auth/login', data: {
        'cpf': cpfLimpo, // ou _cpfController.text se sua API exigir com pontos
        'senha': _senhaController.text,
      });

      // Valida o perfil do usuário retornado
      if (response.data['usuario']['perfil'] == 'ADMIN') {
        if (!mounted) return;
        ApiService.token = response.data['token'];
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
      } else {
        _mostrarErro('Acesso negado. Você não é um administrador.');
      }
    } catch (e) {
      _mostrarErro('Erro ao fazer login. Verifique suas credenciais.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login Administrativo')),
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person, size: 64, color: Color(0xFF1E3A8A)),
              const SizedBox(height: 16),
              const Text('Acesso Restrito', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              
              // 🪛 INPUT DE CPF CONFIGURADO PARA NÚMEROS
              TextField(
                controller: _cpfController,
                keyboardType: TextInputType.number,
                maxLength: 14, // 000.000.000-00 tem 14 caracteres
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  // Se não instalou o pacote de máscara, comente a linha abaixo:
                  _CpfInputFormatter(), 
                ],
                decoration: const InputDecoration(
                  labelText: 'CPF', 
                  hintText: '000.000.000-00',
                  border: OutlineInputBorder(),
                  counterText: "", // Esconde o contador de caracteres chato
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _senhaController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                  onPressed: _carregando ? null : _fazerLogin,
                  child: _carregando 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Entrar no Painel', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Se o usuário estiver apagando, permite a ação sem forçar formatação incorreta
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    final text = newValue.text.replaceAll(RegExp(r'\D'), ''); // Remove tudo que não for número
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(text[i]);
    }
    
    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}