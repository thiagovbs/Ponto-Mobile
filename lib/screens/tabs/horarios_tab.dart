import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class HorariosTab extends StatefulWidget {
  
  const HorariosTab({super.key});

  @override
  State<HorariosTab> createState() => _HorariosTabState();
}

class _HorariosTabState extends State<HorariosTab> {
  List<dynamic> _horarios = [];
  bool _carregandoHorarios = false;

  @override
  void initState() {
    super.initState();
    _buscarHorarios();
  }

  Future<void> _buscarHorarios() async {
    setState(() => _carregandoHorarios = true);
    try {
      final response = await ApiService.dio.get('/horarios'); 
      setState(() => _horarios = response.data);
    } catch (e) {
      _mostrarMensagem('Erro ao carregar horários.', esErro: true);
    } finally {
      setState(() => _carregandoHorarios = false);
    }
  }

  Future<void> _salvarHorario({String? id, required Map<String, dynamic> dados}) async {
    try {
      if (id == null) {
        await ApiService.dio.post('/horarios', data: dados);
      } else {
        await ApiService.dio.put('/horarios/$id', data: dados);
      }
      _mostrarMensagem('Jornada salva com sucesso!');
      _buscarHorarios();
    } catch (e) {
      _mostrarMensagem('Erro ao salvar jornada.', esErro: true);
    }
  }

  Future<void> _eliminarHorario(String id) async {
    try {
      await ApiService.dio.delete('/horarios/$id');
      _mostrarMensagem('Jornada removida!');
      _buscarHorarios();
    } catch (e) {
      _mostrarMensagem('Erro ao remover horário.', esErro: true);
    }
  }

  void _mostrarMensagem(String msg, {bool esErro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: esErro ? Colors.red : Colors.green),
    );
  }

  Widget _construirSubtituloJornada(Map<String, dynamic> hor) {
    final String tipoEscala = hor['tipoEscala'] ?? 'SEMANAL';

    if (tipoEscala == 'ALTERNADA') {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
              child: Text('🔄 Plantão Alternado (12x36)', style: TextStyle(color: Colors.blue.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 2),
            Text('Horário: ${hor['horaEntradaPadrao']} às ${hor['horaSaidaPadrao']} (12h)', style: const TextStyle(color: Color(0xFF1E40AF), fontWeight: FontWeight.w500)),
          ],
        ),
      );
    } else {
      final bool trabalhaSabado = hor['trabalhaSabado'] ?? false;
      final bool trabalhaDomingo = hor['trabalhaDomingo'] ?? false;
      final bool trabalhaDomingoAlt = hor['trabalhaDomingoAlt'] ?? false;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seg a Sex: ${hor['horaEntradaPadrao']} às ${hor['horaSaidaPadrao']}'),
          Text('Sábado: ${trabalhaSabado ? "${hor['horaEntradaSabado']} às ${hor['horaSaidaSabado']}" : "☀️ Folga"}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(
            'Domingo: ${trabalhaDomingo ? "${hor['horaEntradaDomingo']} às ${hor['horaSaidaDomingo']} ${trabalhaDomingoAlt ? '(Alternado)' : '(Fixo)'}" : "☀️ Folga"}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoHorarios) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _horarios.isEmpty
          ? const Center(child: Text('Nenhuma jornada cadastrada.'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: ListView.separated(
                    itemCount: _horarios.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final hor = _horarios[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE0F2FE),
                          child: Icon(Icons.access_time_filled, color: Color(0xFF0369A1)),
                        ),
                        title: Text(hor['descricao'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: _construirSubtituloJornada(hor),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _abrirFormularioModal(horario: hor)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmarExclusao(hor['id'], hor['descricao'])),
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
        label: const Text('Nova Jornada', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // 🪛 IMPORTANTE: Este método agora está DENTRO das chaves da classe _HorariosTabState
  void _abrirFormularioModal({Map<String, dynamic>? horario}) {
    final bool esEdicion = horario != null;
    
    final txtDescricao = TextEditingController(text: esEdicion ? horario['descricao'] : '');
    String tipoEscala = esEdicion ? (horario['tipoEscala'] ?? 'SEMANAL') : 'SEMANAL';

    final txtEntradaPadrao = TextEditingController(text: esEdicion ? horario['horaEntradaPadrao'] : '08:00');
    final txtSaidaPadrao = TextEditingController(text: esEdicion ? horario['horaSaidaPadrao'] : '17:00');

    bool trabalhaSabado = esEdicion ? (horario['trabalhaSabado'] ?? false) : false;
    final txtEntradaSabado = TextEditingController(text: esEdicion ? (horario['horaEntradaSabado'] ?? '08:00') : '08:00');
    final txtSaidaSabado = TextEditingController(text: esEdicion ? (horario['horaSaidaSabado'] ?? '12:00') : '12:00');

    bool trabalhaDomingo = esEdicion ? (horario['trabalhaDomingo'] ?? false) : false;
    bool trabalhaDomingoAlt = esEdicion ? (horario['trabalhaDomingoAlt'] ?? false) : false;
    bool domingoInicioImpar = esEdicion ? (horario['domingoInicioImpar'] ?? true) : true;
    final txtEntradaDomingo = TextEditingController(text: esEdicion ? (horario['horaEntradaDomingo'] ?? '08:00') : '08:00');
    final txtSaidaDomingo = TextEditingController(text: esEdicion ? (horario['horaSaidaDomingo'] ?? '12:00') : '12:00');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(esEdicion ? '📝 Editar Jornada Base' : '➕ Nova Jornada Base', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 450,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: txtDescricao,
                        decoration: const InputDecoration(labelText: 'Nome do Horário / Setor', hintText: 'Ex: Administrativo Geral'),
                      ),
                      const SizedBox(height: 16),
                      const Text('Regime de Escala / Tipo de Jornada', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: tipoEscala,
                        decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
                        items: const [
                          DropdownMenuItem(value: 'SEMANAL', child: Text('Horário Fixo Semanal')),
                          DropdownMenuItem(value: 'ALTERNADA', child: Text('Plantão Alternado (12x36)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              tipoEscala = val;
                              if (tipoEscala == 'ALTERNADA') {
                                txtEntradaPadrao.text = '07:00';
                                txtSaidaPadrao.text = '19:00';
                              } else {
                                txtEntradaPadrao.text = '08:00';
                                txtSaidaPadrao.text = '17:00';
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      if (tipoEscala == 'ALTERNADA') ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Configuração de Plantão', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                              const SizedBox(height: 4),
                              const Text('O sistema aplicará os horários no formato "Dia Sim, Dia Não" de maneira ininterrupta.', style: TextStyle(fontSize: 11, color: Colors.black54)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: txtEntradaPadrao,
                                      decoration: const InputDecoration(labelText: 'Entrada Plantão', hintText: 'HH:MM', prefixIcon: Icon(Icons.login)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: txtSaidaPadrao,
                                      decoration: const InputDecoration(labelText: 'Saída Plantão', hintText: 'HH:MM', prefixIcon: Icon(Icons.logout)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      ] else ...[
                        const Text('Configuração Base (Segunda a Sexta)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: txtEntradaPadrao, decoration: const InputDecoration(labelText: 'Entrada Padrão'))),
                            const SizedBox(width: 12),
                            Expanded(child: TextField(controller: txtSaidaPadrao, decoration: const InputDecoration(labelText: 'Saída Padrão'))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        CheckboxListTile(
                          title: const Text('Trabalha aos Sábados?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          value: trabalhaSabado,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (val) => setModalState(() => trabalhaSabado = val ?? false),
                        ),
                        if (trabalhaSabado)
                          Row(
                            children: [
                              Expanded(child: TextField(controller: txtEntradaSabado, decoration: const InputDecoration(labelText: 'Entrada Sábado'))),
                              const SizedBox(width: 12),
                              Expanded(child: TextField(controller: txtSaidaSabado, decoration: const InputDecoration(labelText: 'Saída Sábado'))),
                            ],
                          ),

                        CheckboxListTile(
                          title: const Text('Trabalha aos Domingos?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          value: trabalhaDomingo,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (val) => setModalState(() => trabalhaDomingo = val ?? false),
                        ),
                        if (trabalhaDomingo) ...[
                          Row(
                            children: [
                              Expanded(child: TextField(controller: txtEntradaDomingo, decoration: const InputDecoration(labelText: 'Entrada Domingo'))),
                              const SizedBox(width: 12),
                              Expanded(child: TextField(controller: txtSaidaDomingo, decoration: const InputDecoration(labelText: 'Saída Domingo'))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            title: const Text('Domingos Alternados? (15x15)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.blueGrey)),
                            value: trabalhaDomingoAlt,
                            contentPadding: const EdgeInsets.only(left: 12),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (val) => setModalState(() => trabalhaDomingoAlt = val ?? false),
                          ),
                          if (trabalhaDomingoAlt)
                            Padding(
                              padding: const EdgeInsets.only(left: 24.0, top: 4),
                              child: DropdownButtonFormField<bool>(
                                initialValue: domingoInicioImpar,
                                decoration: const InputDecoration(labelText: 'Início do Ciclo', contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                                items: const [
                                  DropdownMenuItem(value: true, child: Text('Semana Ímpar (Trabalha já)')),
                                  DropdownMenuItem(value: false, child: Text('Semana Par (Folga primeiro)')),
                                ],
                                onChanged: (val) => setModalState(() => domingoInicioImpar = val ?? true),
                              ),
                            )
                        ]
                      ]
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                  onPressed: () {
                    if (txtDescricao.text.trim().isEmpty) {
                      _mostrarMensagem('O nome do horário é obrigatório.', esErro: true);
                      return;
                    }

                    final List<Map<String, dynamic>> regrasDias = [
                      {'dia': 'Segunda-feira', 'numero': 1, 'trabalha': true, 'entrada': txtEntradaPadrao.text, 'saida': txtSaidaPadrao.text},
                      {'dia': 'Terça-feira', 'numero': 2, 'trabalha': true, 'entrada': txtEntradaPadrao.text, 'saida': txtSaidaPadrao.text},
                      {'dia': 'Quarta-feira', 'numero': 3, 'trabalha': true, 'entrada': txtEntradaPadrao.text, 'saida': txtSaidaPadrao.text},
                      {'dia': 'Quinta-feira', 'numero': 4, 'trabalha': true, 'entrada': txtEntradaPadrao.text, 'saida': txtSaidaPadrao.text},
                      {'dia': 'Sexta-feira', 'numero': 5, 'trabalha': true, 'entrada': txtEntradaPadrao.text, 'saida': txtSaidaPadrao.text},
                      {'dia': 'Sábado', 'numero': 6, 'trabalha': tipoEscala == 'SEMANAL' ? trabalhaSabado : false, 'entrada': txtEntradaSabado.text, 'saida': txtSaidaSabado.text},
                      {'dia': 'Domingo', 'numero': 0, 'trabalha': tipoEscala == 'SEMANAL' ? trabalhaDomingo : false, 'entrada': txtEntradaDomingo.text, 'saida': txtSaidaDomingo.text},
                    ];

                    final payload = {
                      'descricao': txtDescricao.text.trim(),
                      'tipoEscala': tipoEscala,
                      'regrasDias': regrasDias,
                      'trabalhaDomingoAlt': tipoEscala == 'SEMANAL' ? trabalhaDomingoAlt : false,
                      'domingoInicioImpar': tipoEscala == 'SEMANAL' ? domingoInicioImpar : true,
                      'entradaAlternada': txtEntradaPadrao.text,
                      'saidaAlternada': txtSaidaPadrao.text,
                    };

                    _salvarHorario(id: esEdicion ? horario['id'] : null, dados: payload);
                    Navigator.pop(context);
                  },
                  child: Text(esEdicion ? 'Salvar' : 'Criar', style: const TextStyle(color: Colors.white)),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _confirmarExclusao(String id, String descricao) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Remoção'),
        content: Text('Deseja realmente excluir a jornada "$descricao"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _eliminarHorario(id);
              Navigator.pop(context);
            },
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
} // Fim do _HorariosTabState