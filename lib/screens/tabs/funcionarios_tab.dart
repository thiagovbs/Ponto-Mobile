import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

class FuncionariosTab extends StatefulWidget {
  const FuncionariosTab({super.key});

  @override
  State<FuncionariosTab> createState() => _FuncionariosTabState();
}

class _FuncionariosTabState extends State<FuncionariosTab> {
  List<dynamic> _funcionarios = [];
  List<dynamic> _horarios = []; // Para alimentar o dropdown
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    try {
      final resFunc = await ApiService.dio.get('/usuarios');
      final resHor = await ApiService.dio.get('/horarios');
      setState(() {
        _funcionarios = resFunc.data;
        _horarios = resHor.data;
      });
    } catch (e) {
      _mostrarMensagem('Erro ao carregar dados.', esErro: true);
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _salvarFuncionario({String? id, required Map<String, dynamic> dados}) async {
    try {
      if (id == null) {
        await ApiService.dio.post('/usuarios', data: dados);
      } else {
        await ApiService.dio.put('/usuarios/$id', data: dados);
      }
      _mostrarMensagem('Funcionário salvo!');
      _carregarDados();
    } catch (e) {
      _mostrarMensagem('Erro ao salvar funcionário.', esErro: true);
    }
  }

  Future<void> _eliminarFuncionario(String id) async {
    try {
      await ApiService.dio.delete('/usuarios/$id');
      _mostrarMensagem('Funcionário removido.');
      _carregarDados();
    } catch (e) {
      _mostrarMensagem('Erro ao remover funcionário.', esErro: true);
    }
  }

  void _mostrarMensagem(String msg, {bool esErro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: esErro ? Colors.red : Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _funcionarios.isEmpty
          ? const Center(child: Text('Nenhum funcionário cadastrado.'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: ListView.separated(
                    itemCount: _funcionarios.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final func = _funcionarios[index];
                      final bool esAdmin = func['perfil'] == 'ADMIN';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: esAdmin ? Colors.amber.shade100 : Colors.blue.shade100,
                          child: Icon(esAdmin ? Icons.shield : Icons.person, color: esAdmin ? Colors.amber.shade900 : Colors.blue.shade900),
                        ),
                        title: Text(func['nome'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('CPF: ${func['cpf']} • Perfil: ${func['perfil']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _abrirFormularioModal(func: func)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmarExclusao(func['id'], func['nome'])),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1E3A8A),
        onPressed: () => _abrirFormularioModal(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Novo Funcionário', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _abrirFormularioModal({Map<String, dynamic>? func}) {
    // ... (Mantenha o método _abrirFormularioModal antigo de funcionários aqui)
  }

  void _confirmarExclusao(String id, String nome) {
    // ... (Mantenha o método _confirmarExclusao antigo de funcionários aqui)
  }
}