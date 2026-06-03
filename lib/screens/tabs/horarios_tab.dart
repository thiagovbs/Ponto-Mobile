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
    if (!mounted) return;
    setState(() => _carregandoHorarios = true);
    try {
      final response = await ApiService.dio.get('/horarios'); 
      if (mounted) {
        setState(() => _horarios = response.data);
      }
    } catch (e) {
      _mostrarMensagem('Erro ao carregar horários.', esErro: true);
    } finally {
      if (mounted) setState(() => _carregandoHorarios = false);
    }
  }

  Future<void> _salvarHorario({String? id, required Map<String, dynamic> dados}) async {
    try {
      if (id == null) {
        await ApiService.dio.post('/horarios', data: dados);
      } else {
        await ApiService.dio.put('/horarios/$id', data: dados);
      }
      _mostrarMensagem(id == null ? 'Jornada de trabalho cadastrada com sucesso!' : 'Jornada de trabalho atualizada com sucesso!');
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
    final bool utilizaAlmoco = hor['utilizaAlmocoAutomatico'] ?? true;
    final int minutesAlmoco = hor['duracaoAlmocoMinutos'] ?? 60;

    final stringAlmoco = utilizaAlmoco ? '🍽️ Almoço Auto: ${minutesAlmoco}min' : '🍽️ Almoço: Batida Manual (4x)';

    if (tipoEscala == 'ALTERNADA') {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                  child: Text('🔄 Plantão Alternado (12x36)', style: TextStyle(color: Colors.blue.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                  child: Text(stringAlmoco, style: TextStyle(color: Colors.orange.shade900, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
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
          Text('Seg a Sex: ${hor['horaEntradaPadrao']} às ${hor['horaSaidaPadrao']} • $stringAlmoco', style: const TextStyle(fontWeight: FontWeight.w500)),
          // 🟢 CORREÇÃO: Limpado o style bizarro do "Colors.styleFrom" e padronizado com Colors.grey.shade600
          Text('Sábado: ${trabalhaSabado ? "${hor['horaEntradaSabado']} às ${hor['horaSaidaSabado']}" : "☀️ Folga"}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(
            'Domingo: ${trabalhaDomingo ? "${hor['horaEntradaDomingo']} às ${hor['horaSaidaDomingo']} ${trabalhaDomingoAlt ? '(Alternado)' : '(Fixo)'}" : "☀️ Folga"}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue), 
                              onPressed: () => _abrirFormularioModal(horario: hor),
                              tooltip: 'Editar Jornada',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red), 
                              onPressed: () => _confirmarExclusao(hor['id'], hor['descricao']),
                              tooltip: 'Remover Jornada',
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
        label: const Text('Nova Jornada', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // 🪛 RECONSTRUÇÃO COMPLETA: BottomSheet Reativo com Blindagem Antiestouro
  void _abrirFormularioModal({Map<String, dynamic>? horario}) {
    final bool esEdicion = horario != null;
    
    final txtDescricao = TextEditingController(text: esEdicion ? horario['descricao'] : '');
    String tipoEscala = esEdicion ? (horario['tipoEscala'] ?? 'SEMANAL') : 'SEMANAL';

    final txtEntradaPadrao = TextEditingController(text: esEdicion ? horario['horaEntradaPadrao'] : '08:00');
    final txtSaidaPadrao = TextEditingController(text: esEdicion ? horario['horaSaidaPadrao'] : '17:00');

    bool utilizaAlmocoAutomatico = esEdicion ? (horario['utilizaAlmocoAutomatico'] ?? true) : true;
    int duracaoAlmocoMinutos = esEdicion ? (horario['duracaoAlmocoMinutos'] ?? 60) : 60;

    bool trabalhaSabado = esEdicion ? (horario['trabalhaSabado'] ?? false) : false;
    final txtEntradaSabado = TextEditingController(text: esEdicion ? (horario['horaEntradaSabado'] ?? '08:00') : '08:00');
    final txtSaidaSabado = TextEditingController(text: esEdicion ? (horario['horaSaidaSabado'] ?? '12:00') : '12:00');

    bool trabalhaDomingo = esEdicion ? (horario['trabalhaDomingo'] ?? false) : false;
    bool trabalhaDomingoAlt = esEdicion ? (horario['trabalhaDomingoAlt'] ?? false) : false;
    bool domingoInicioImpar = esEdicion ? (horario['domingoInicioImpar'] ?? true) : true;
    final txtEntradaDomingo = TextEditingController(text: esEdicion ? (horario['horaEntradaDomingo'] ?? '08:00') : '08:00');
    final txtSaidaDomingo = TextEditingController(text: esEdicion ? (horario['horaSaidaDomingo'] ?? '12:00') : '12:00');

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
                      esEdicion ? '📝 Editar Jornada Base' : '➕ Nova Jornada Base', 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: txtDescricao,
                      decoration: const InputDecoration(labelText: 'Nome do Horário / Setor', hintText: 'Ex: Administrativo Geral', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    const Text('Regime de Escala / Tipo de Jornada', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: tipoEscala,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12), border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'SEMANAL', child: Text('Horário Fixo Semanal (Segunda a Domingo)')),
                        DropdownMenuItem(value: 'ALTERNADA', child: Text('Escala Alternada / Plantão (12x36 - Dia Sim, Dia Não)')),
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

                    const Text('Intervalo de Refeição / Almoço', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    SwitchListTile(
                      title: const Text('Ativar Almoço Automático', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      subtitle: const Text('Desconto pré-assinalado sem precisar bater ponto no meio do dia', style: TextStyle(fontSize: 11)),
                      value: utilizaAlmocoAutomatico,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setModalState(() => utilizaAlmocoAutomatico = val),
                    ),
                    if (utilizaAlmocoAutomatico) ...[
                      const SizedBox(height: 4),
                      DropdownButtonFormField<int>(
                        value: duracaoAlmocoMinutos,
                        decoration: const InputDecoration(
                          labelText: 'Duração do Intervalo de Almoço:',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 15, child: Text('15 minutos (Café / Lanche)')),
                          DropdownMenuItem(value: 30, child: Text('30 minutes')),
                          DropdownMenuItem(value: 60, child: Text('1 hora (Padrão CLT)')),
                          DropdownMenuItem(value: 90, child: Text('1 hora e 30 minutos')),
                          DropdownMenuItem(value: 120, child: Text('2 horas')),
                        ],
                        onChanged: (val) => setModalState(() => duracaoAlmocoMinutos = val!),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (tipoEscala == 'ALTERNADA') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Configuração de Plantão Alternado', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                            const SizedBox(height: 4),
                            const Text('O sistema aplicará automaticamente os horários abaixo no formato "Dia Sim, Dia Não". O ciclo de revezamento será calculated a partir da data de início cadastrada no perfil do colaborador.', style: TextStyle(fontSize: 11, color: Colors.black54)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: txtEntradaPadrao,
                                    decoration: const InputDecoration(labelText: 'Horário de Entrada', hintText: 'HH:MM', border: OutlineInputBorder()),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: txtSaidaPadrao,
                                    decoration: const InputDecoration(labelText: 'Horário de Saída', hintText: 'HH:MM', border: OutlineInputBorder()),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    ] else ...[
                      const Text('Configuração Base (Segunda a Sexta)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: txtEntradaPadrao, decoration: const InputDecoration(labelText: 'Entrada Padrão', border: OutlineInputBorder()))),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: txtSaidaPadrao, decoration: const InputDecoration(labelText: 'Saída Padrão', border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      CheckboxListTile(
                        title: const Text('Trabalha aos Sábados?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        value: trabalhaSabado,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (val) => setModalState(() => trabalhaSabado = val ?? false),
                      ),
                      if (trabalhaSabado) ...[
                        Row(
                          children: [
                            Expanded(child: TextField(controller: txtEntradaSabado, decoration: const InputDecoration(labelText: 'Entrada Sábado', border: OutlineInputBorder()))),
                            const SizedBox(width: 12),
                            Expanded(child: TextField(controller: txtSaidaSabado, decoration: const InputDecoration(labelText: 'Saída Sábado', border: OutlineInputBorder()))),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

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
                            Expanded(child: TextField(controller: txtEntradaDomingo, decoration: const InputDecoration(labelText: 'Entrada Domingo', border: OutlineInputBorder()))),
                            const SizedBox(width: 12),
                            Expanded(child: TextField(controller: txtSaidaDomingo, decoration: const InputDecoration(labelText: 'Saída Domingo', border: OutlineInputBorder()))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          title: const Text('Esta jornada trabalha em Domingos Alternados (Escala 15x15)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.blueGrey)),
                          value: trabalhaDomingoAlt,
                          contentPadding: const EdgeInsets.only(left: 12),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (val) => setModalState(() => trabalhaDomingoAlt = val ?? false),
                        ),
                        if (trabalhaDomingoAlt) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 12.0, top: 4),
                            child: DropdownButtonFormField<bool>(
                              value: domingoInicioImpar,
                              decoration: const InputDecoration(labelText: 'Defina o início do ciclo de trabalho:', contentPadding: EdgeInsets.symmetric(horizontal: 8), border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: true, child: Text('Semana Ímpar (Trabalha no próximo domingo)')),
                                DropdownMenuItem(value: false, child: Text('Semana Par (Folga no próximo domingo)')),
                              ],
                              onChanged: (val) => setModalState(() => domingoInicioImpar = val ?? true),
                            ),
                          ),
                        ]
                      ]
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
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
                            'utilizaAlmocoAutomatico': utilizaAlmocoAutomatico,
                            'duracaoAlmocoMinutos': utilizaAlmocoAutomatico ? duracaoAlmocoMinutos : 0,
                            'trabalhaDomingoAlt': tipoEscala == 'SEMANAL' ? trabalhaDomingoAlt : false,
                            'domingoInicioImpar': tipoEscala == 'SEMANAL' ? domingoInicioImpar : true,
                          };

                          if (tipoEscala == 'SEMANAL') {
                            payload['regrasDias'] = regrasDias;
                          } else {
                            payload['entradaAlternada'] = txtEntradaPadrao.text;
                            payload['saidaAlternada'] = txtSaidaPadrao.text;
                          }

                          Navigator.pop(context);
                          _salvarHorario(id: esEdicion ? horario['id'] : null, dados: payload);
                        },
                        child: const Text('Salvar Regra de Horário', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
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
              Navigator.pop(context);
              _eliminarHorario(id);
            },
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}