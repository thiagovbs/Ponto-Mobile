import 'package:flutter/material.dart';
import 'package:dio/dio.dart'; // 🔥 IMPORTADO PARA MAPEAR OS ERROS DE POST/PUT
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class FuncionariosTab extends StatefulWidget {
  const FuncionariosTab({super.key});

  @override
  State<FuncionariosTab> createState() => _FuncionariosTabState();
}

class _FuncionariosTabState extends State<FuncionariosTab> {
  List<dynamic> _funcionarios = [];
  List<dynamic> _horarios = []; 
  
  // 🟢 NOVOS ESTADOS REATIVOS MULTI-TENANT (ALINHADO COM A WEB)
  List<dynamic> _filiais = [];
  List<dynamic> _setores = [];
  
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
      // 🟢 PARALELISMO SAAS ATÔMICO: Dispara chamadas concorrentes isoladas pelo Token JWT do Admin
      final resultados = await Future.wait([
        ApiService.dio.get('/usuarios'),
        ApiService.dio.get('/horarios'),
        ApiService.dio.get('/filiais'),
        ApiService.dio.get('/setores'),
      ]);

      if (mounted) {
        setState(() {
          _funcionarios = resultados[0].data;
          _horarios = resultados[1].data;
          _filiais = resultados[2].data;
          _setores = resultados[3].data;
        });
      }
    } catch (e) {
      _mostrarMensagem('Erro ao carregar dados multi-tenant.', esErro: true);
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
      _mostrarMensagem(id == null ? 'Novo colaborador cadastrado com sucesso!' : 'Colaborador updated com sucesso!');
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
      _mostrarMensagem('Colaborador removido com sucesso.');
      _carregarDados();
    } catch (e) {
      _mostrarMensagem('Não foi possível excluir o colaborador.', esErro: true);
    }
  }

  void _mostrarMensagem(String msg, {bool esErro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: esErro ? Colors.red : Colors.green),
    );
  }

  // Auxiliar para formatação visual rápida na listagem
  String _formatarDataTabela(String? dataISO) {
    if (dataISO == null || dataISO.trim().isEmpty) return '-';
    try {
      final apenasData = dataISO.split('T')[0];
      final partes = apenasData.split('-');
      if (partes.length == 3) {
        return '${partes[2]}/${partes[1]}/${partes[0]}';
      }
      return apenasData;
    } catch (e) {
      return '-';
    }
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
                      final dataEscala = func['dataInicioEscala']?.toString();

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: esAdmin ? Colors.amber.shade100 : Colors.blue.shade100,
                          child: Icon(esAdmin ? Icons.shield : Icons.person, color: esAdmin ? Colors.amber.shade900 : Colors.blue.shade900),
                        ),
                        title: Text(func['nome'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CPF: ${func['cpf']} • Perfil: ${func['perfil']}'),
                            if (!esAdmin && dataEscala != null)
                              Text(
                                'Início da Escala: ${_formatarDataTabela(dataEscala)}',
                                style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue), 
                              onPressed: () => _abrirFormularioModal(func: func),
                              tooltip: 'Editar Dados do Funcionário',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red), 
                              onPressed: () => _confirmarExclusao(func['id'], func['nome']),
                              tooltip: 'Excluir Funcionário do Sistema',
                            ),
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

  // 🪛 FORMULÁRIO MODAL MULTI-TENANT RECONSTRUÍDO DE ACORDO COM A WEB
  void _abrirFormularioModal({Map<String, dynamic>? func}) {
    final nomeController = TextEditingController(text: func?['nome'] ?? '');
    final cpfController = TextEditingController(text: func?['cpf'] ?? '');
    final senhaController = TextEditingController(); 
    final dataEscalaController = TextEditingController();

    String perfilSelecionado = func?['perfil'] ?? 'FUNCIONARIO';
    String? horarioSelecionado = func?['horarioBaseId']?.toString();
    
    // 🟢 CHAVES DE FILTRAGEM CORPORATIVA DO SAAS
    String? filialSelecionada = func?['filialId']?.toString();
    String? setorSelecionado = func?['setorId']?.toString();

    // Inicializa os setores de acordo com a filial alocada na edição
    List<dynamic> setoresFiltradosLocais = [];
    if (filialSelecionada != null) {
      setoresFiltradosLocais = _setores.where((s) => s['filialId']?.toString() == filialSelecionada).toList();
    }

    // Inicializa a data da escala se houver
    if (func?['dataInicioEscala'] != null) {
      try {
        dataEscalaController.text = func!['dataInicioEscala'].toString().split('T')[0];
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder( 
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24, 
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      func == null ? '➕ Cadastrar Novo Funcionário' : '📝 Editar Funcionário',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(labelText: 'Nome Completo *', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cpfController,
                      keyboardType: TextInputType.number,
                      maxLength: 11,
                      enabled: func == null, 
                      decoration: const InputDecoration(labelText: 'CPF (Apenas números) *', border: OutlineInputBorder(), counterText: ""),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: senhaController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: func == null ? 'Senha de Acesso *' : 'Nova Senha (Deixe em branco para manter)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: perfilSelecionado,
                      decoration: const InputDecoration(labelText: 'Perfil de Acesso', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'FUNCIONARIO', child: Text('Funcionário')),
                        DropdownMenuItem(value: 'ADMIN', child: Text('Administrador')),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          perfilSelecionado = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // 🟢 SELECT 1: FILIAIS OPERACIONAIS DO TENANT
                    DropdownButtonFormField<String?>(
                      value: filialSelecionada,
                      decoration: const InputDecoration(labelText: 'Filial Alocada *', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Selecione a Filial...')),
                        ..._filiais.map((f) => DropdownMenuItem(value: f['id'].toString(), child: Text(f['nome']))),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          filialSelecionada = val;
                          setorSelecionado = null; // 🟢 RESET REATIVO DE ACORDO COM A WEB
                          if (val != null) {
                            setoresFiltradosLocais = _setores.where((s) => s['filialId']?.toString() == val).toList();
                          } else {
                            setoresFiltradosLocais = [];
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // 🟢 SELECT 2: SETORES EM CASCATA FILTRADOS
                    DropdownButtonFormField<String?>(
                      value: setorSelecionado,
                      decoration: InputDecoration(
                        labelText: 'Setor Administrativo *', 
                        border: const OutlineInputBorder(),
                        disabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                      ),
                      // Desabilita se não houver filial selecionada na cascata
                      items: filialSelecionada == null 
                        ? [const DropdownMenuItem(value: null, child: Text('Escolha uma filial primeiro...'))]
                        : [
                            const DropdownMenuItem(value: null, child: Text('Selecione o Setor...')),
                            ...setoresFiltradosLocais.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['nome'])))
                          ],
                      onChanged: filialSelecionada == null ? null : (val) {
                        setModalState(() => setorSelecionado = val);
                      },
                    ),

                    // Oculta os parâmetros de horários se o perfil for alterado para Administrador
                    if (perfilSelecionado == 'FUNCIONARIO') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        value: horarioSelecionado,
                        decoration: const InputDecoration(labelText: 'Jornada / Horário Base', border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Nenhum horário associado')),
                          ..._horarios.map((h) => DropdownMenuItem(value: h['id'].toString(), child: Text(h['descricao']))),
                        ],
                        onChanged: (val) => setModalState(() => horarioSelecionado = val),
                      ),
                      const SizedBox(height: 12),
                      
                      // 🟢 SELECIONADOR DE DATA SEGURO: Crucial para o motor de cálculos de escala do backend
                      TextField(
                        controller: dataEscalaController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Data de Início da Escala *',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today, size: 20),
                        ),
                        onTap: () async {
                          final DateTime? dataEscolhida = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                            helpText: 'SELECIONE O PRIMEIRO DIA DE PLANTÃO ATIVO',
                          );
                          if (dataEscolhida != null) {
                            setModalState(() {
                              dataEscalaController.text = DateFormat('yyyy-MM-dd').format(dataEscolhida);
                            });
                          }
                        },
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0, left: 4.0),
                        child: Text(
                          'Selecione o primeiro dia de trabalho ativo do funcionário.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                        onPressed: () {
                          if (nomeController.text.isEmpty || 
                              cpfController.text.isEmpty || 
                              filialSelecionada == null || 
                              setorSelecionado == null) {
                            _mostrarMensagem('Por favor, preencha todos os campos obrigatórios.', esErro: true);
                            return;
                          }

                          if (func == null && senhaController.text.isEmpty) {
                            _mostrarMensagem('Por favor, preencha a senha de acesso obrigatória.', esErro: true);
                            return;
                          }
                          
                          final Map<String, dynamic> dadosEnvio = {
                            'nome': nomeController.text.trim(),
                            'cpf': cpfController.text.replaceAll(RegExp(r'\D'), '').trim(),
                            'perfil': perfilSelecionado,
                            'filialId': filialSelecionada,
                            'setorId': setorSelecionado,
                            'horarioBaseId': perfilSelecionado == 'FUNCIONARIO' ? horarioSelecionado : null,
                            'dataInicioEscala': perfilSelecionado == 'FUNCIONARIO' && dataEscalaController.text.isNotEmpty 
                                ? '${dataEscalaController.text}T00:00:00.000Z' 
                                : null,
                          };

                          if (senhaController.text.isNotEmpty) {
                            dadosEnvio['senha'] = senhaController.text;
                          }

                          Navigator.pop(context); 
                          _salvarFuncionario(id: func?['id'], dados: dadosEnvio);
                        },
                        child: const Text('Salvar Cadastro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
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
        content: Text('Tem certeza de que deseja remover o funcionário $nome do sistema? Esta ação é irreversível.'),
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