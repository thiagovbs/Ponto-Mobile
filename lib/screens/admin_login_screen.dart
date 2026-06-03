import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart'; 
import '../services/api_service.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _cpfController = TextEditingController();
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
      // Enviando 'cpf' no payload em vez de 'email'
      final response = await ApiService.dio.post('/auth/login', data: {
        'cpf': cpfLimpo,
        'senha': _senhaController.text,
      });

      // Valida o perfil do usuário retornado
      if (response.data['usuario']['perfil'] == 'ADMIN' || response.data['usuario']['perfil'] == 'SUPER_ADMIN') {
        if (!mounted) return;
        
        // 🟢 INJEÇÃO MULTI-TENANT ALINHADA COM A WEB: Extrai e persiste as chaves de lotação no ApiService
        ApiService.token = response.data['token'];
        ApiService.empresaId = response.data['usuario']['empresaId']?.toString();
        ApiService.filialId = response.data['usuario']['filialId']?.toString();
        ApiService.setorId = response.data['usuario']['setorId']?.toString();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
      } else {
        _mostrarErro('Acesso negado. Você não é um administrador.');
      }
    } catch (e) {
      // Captura os detalhes brutos do erro
      String mensagemErro = "Erro desconhecido.";
      String detalheTecnico = e.toString();

      if (e is DioException) {
        // 🪛 Variável local explicitamente tipada para o Dart mapear os subatributos do Dio
        final dioError = e;

        mensagemErro = "Falha na comunicação com a API do Render.";
        detalheTecnico = "Tipo: ${dioError.type}\n"
                        "Status Code: ${dioError.response?.statusCode}\n"
                        "Mensagem: ${dioError.message}\n"
                        "Data: ${dioError.response?.data}";
      }

      // 🔥 ABRE UM ALERTA INFORMATIVO NA TELA DO TABLET
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false, // Força o usuário a clicar no botão para fechar
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.report_problem, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              const Text('Erro de Diagnóstico', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mensagemErro, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                const Text('Detalhes técnicos para o desenvolvedor:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300)
                  ),
                  child: Text(
                    detalheTecnico,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
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
              
              // INPUT DE CPF CONFIGURADO PARA NÚMEROS
              TextField(
                controller: _cpfController,
                keyboardType: TextInputType.number,
                maxLength: 14, // 000.000.000-00 tem 14 caracteres
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
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