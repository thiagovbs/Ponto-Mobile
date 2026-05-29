import 'package:flutter/material.dart';
import 'package:dio/dio.dart'; // 🔥 IMPORTADO PARA MAPEAR OS ERROS DE POST/PUT
import '../../services/api_service.dart';

class FuncionariosTab extends StatefulWidget {
  const FuncionariosTab({super.key});

  @override
  State<FuncionariosTab> createState() => _FuncionariosTabState();
}

class _FuncionariosTabState extends State<FuncionariosTab> {
  List<dynamic> _funcionarios = [];
  List<dynamic> _horarios = []; 
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    if (!mounted) return;
    setState(() => _carregando = true);
    try {
      final resFunc = await ApiService.dio.get('/usuarios');
      final resHor = await ApiService.dio.get('/horarios');
      if (mounted) {
        setState(() {
          _funcionarios = resFunc.data;
          _horarios = resHor.data;
        });
      }
    } catch (e) {
      _mostrarMensagem('Erro ao carregar dados.', esErro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
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
      String msgErro = "Erro ao salvar funcionário.";
      if (e is DioException && e.response?.data != null) {
        msgErro = e.response?.data['erro'] ?? e.response?.data['mensagem'] ?? msgErro;
      }
      _mostrarMensagem(msgErro, esErro: true);
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

  // 🪛 MÉTODO COMPLETAMENTE RECONSTRUÍDO E FUNCIONAL
  void _abrirFormularioModal({Map<String, dynamic>? func}) {
    final nomeController = TextEditingController(text: func?['nome'] ?? '');
    final cpfController = TextEditingController(text: func?['cpf'] ?? '');
    final senhaController = TextEditingController(); // Senha deixada em branco na edição
    String perfilSelecionado = func?['perfil'] ?? 'FUNCIONARIO';
    String? horarioSelecionado = func?['horarioBaseId'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder( // Garante reatividade dentro do Modal do BottomSheet
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24, // Evita que o teclado cubra o modal
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      func == null ? '➕ Cadastrar Funcionário' : '📝 Editar Funcionário',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cpfController,
                      keyboardType: TextInputType.number,
                      enabled: func == null, // Impede a alteração do CPF se for edição (Regra de consistência)
                      decoration: const InputDecoration(labelText: 'CPF (Apenas números)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: senhaController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: func == null ? 'Senha de Acesso' : 'Nova Senha (Deixe em branco para manter)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: perfilSelecionado,
                      decoration: const InputDecoration(labelText: 'Perfil de Sistema', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'FUNCIONARIO', child: Text('Funcionário Padrão')),
                        DropdownMenuItem(value: 'ADMIN', child: Text('Administrador de Painel')),
                      ],
                      onChanged: (val) => setModalState(() => perfilSelecionado = val!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: horarioSelecionado,
                      decoration: const InputDecoration(labelText: 'Jornada / Escala de Trabalho', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Nenhuma Jornada (Apenas Admin)')),
                        ..._horarios.map((h) => DropdownMenuItem(value: h['id'].toString(), child: Text(h['descricao']))),
                      ],
                      onChanged: (val) => setModalState(() => horarioSelecionado = val),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                        onPressed: () {
                          if (nomeController.text.isEmpty || cpfController.text.isEmpty) {
                            _mostrarMensagem('Nome e CPF são obrigatórios.', esErro: true);
                            return;
                          }
                          
                          final Map<String, dynamic> dadosEnvio = {
                            'nome': nomeController.text.trim(),
                            'cpf': cpfController.text.replaceAll(RegExp(r'\D'), '').trim(),
                            'perfil': perfilSelecionado,
                            'horarioBaseId': horarioSelecionado,
                          };

                          if (senhaController.text.isNotEmpty) {
                            dadosEnvio['senha'] = senhaController.text;
                          }

                          Navigator.pop(context); // Fecha o modal antes de disparar o loader da requisição
                          _salvarFuncionario(id: func?['id'], dados: dadosEnvio);
                        },
                        child: const Text('Salvar Cadastro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmarExclusao(String id, String nome) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Registro?'),
        content: Text('Tem certeza de que deseja remover o funcionário $nome da base de dados? Esta ação é irreversível.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _eliminarFuncionario(id);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}