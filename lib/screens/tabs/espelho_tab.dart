import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Para formatar datas e meses
import '../../services/api_service.dart';

class EspelhoTab extends StatefulWidget {
  const EspelhoTab({super.key});

  @override
  State<EspelhoTab> createState() => _EspelhoTabState();
}

class _EspelhoTabState extends State<EspelhoTab> {
  List<dynamic> _funcionarios = [];
  String? _funcionarioSelecionadoId;
  DateTime _mesSelecionado = DateTime.now();
  
  List<dynamic> _linhasEspelho = [];
  bool _carregandoFuncionarios = false;
  bool _carregandoEspelho = false;

  @override
  void initState() {
    super.initState();
    _buscarFuncionarios();
  }

  Future<void> _buscarFuncionarios() async {
    setState(() => _carregandoFuncionarios = true);
    try {
      final response = await ApiService.dio.get('/usuarios');
      
      final List<dynamic> todosUsuarios = response.data;
      final funcionariosFiltrados = todosUsuarios.where((usr) => usr['perfil'] == 'FUNCIONARIO').toList();

      setState(() {
        _funcionarios = funcionariosFiltrados;
        
        if (_funcionarios.isNotEmpty) {
          _funcionarioSelecionadoId = _funcionarios[0]['id'];
          _buscarDadosEspelho(); // Busca o espelho do primeiro da lista
        }
      });
    } catch (e) {
      _mostrarSnackbar('Erro ao carregar lista de funcionários.', esErro: true);
    } finally {
      setState(() => _carregandoFuncionarios = false);
    }
  }

  Future<void> _buscarDadosEspelho() async {
    if (_funcionarioSelecionadoId == null) return;

    setState(() => _carregandoEspelho = true);
    try {
      
      final String mesQuery = DateFormat('MM').format(_mesSelecionado);
      final String anoQuery = DateFormat('yyyy').format(_mesSelecionado);

      
      final response = await ApiService.dio.get(
        '/relatorios/funcionario/$_funcionarioSelecionadoId', 
        queryParameters: {
          'mes': mesQuery,
          'ano': anoQuery,
        },
      );

      setState(() {
        _linhasEspelho = response.data is List ? response.data : (response.data['dias'] ?? []);
      });
    } catch (e) {
      _mostrarSnackbar('Erro ao carregar espelho de ponto do período.', esErro: true);
      setState(() => _linhasEspelho = []);
    } finally {
      setState(() => _carregandoEspelho = false);
    }
  }

  void _mostrarSnackbar(String msg, {bool esErro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: esErro ? Colors.red : Colors.green),
    );
  }

  // Seletor de Meses Nativo simplificado
  Future<void> _selecionarMesAno() async {
    final DateTime? mudou = await showDatePicker(
      context: context,
      initialDate: _mesSelecionado,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: 'SELECIONE O MÊS DO ESPELHO',
    );

    if (mudou != null && mudou != _mesSelecionado) {
      setState(() {
        _mesSelecionado = DateTime(mudou.year, mudou.month);
      });
      _buscarDadosEspelho();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoFuncionarios) {
      return const Center(child: CircularProgressIndicator());
    }

    final textoMes = DateFormat("MMMM 'de' yyyy", "pt_BR").format(_mesSelecionado);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🔎 FILTROS SUPERIORES (FUNCIONÁRIO E MÊS)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Dropdown de Funcionários
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _funcionarioSelecionadoId,
                        decoration: const InputDecoration(
                          labelText: 'Funcionário',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _funcionarios.map<DropdownMenuItem<String>>((func) {
                          return DropdownMenuItem<String>(
                            value: func['id'],
                            child: Text(func['nome']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _funcionarioSelecionadoId = val);
                          _buscarDadosEspelho();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Seletor de Período
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        icon: const Icon(Icons.calendar_month, color: Color(0xFF1E3A8A)),
                        label: Text(
                          textoMes.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                        onPressed: _selecionarMesAno,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 📊 TABELA / LISTAGEM DOS DIAS DO ESPELHO
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: _carregandoEspelho
                    ? const Center(child: CircularProgressIndicator())
                    : _linhasEspelho.isEmpty
                        ? const Center(child: Text('Nenhum registro de ponto encontrado para este período.'))
                        : _buildTabelaEspelho(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Estrutura de tabela rolável, ideal para layouts de Tablet
  Widget _buildTabelaEspelho() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          columns: const [
            DataColumn(label: Text('Data', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Entrada 1', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Saída 1', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Entrada 2', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Saída 2', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Total Horas', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status/Obs', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _linhasEspelho.map<DataRow>((linha) {
            // Mapeia os campos retornados pela agregação da sua API
            final dataExibicao = linha['dataFormatada'] ?? linha['data'] ?? '';
            final e1 = linha['entrada1'] ?? '--:--';
            final s1 = linha['saida1'] ?? '--:--';
            final e2 = linha['entrada2'] ?? '--:--';
            final s2 = linha['saida2'] ?? '--:--';
            final total = linha['horasTrabalhadas'] ?? '00:00';
            final obs = linha['observacao'] ?? linha['status'] ?? 'Normal';

            Color corStatus = Colors.green.shade700;
            if (obs.toString().toLowerCase().contains('falta')) corStatus = Colors.red.shade700;
            if (obs.toString().toLowerCase().contains('atraso')) corStatus = Colors.amber.shade900;

            return DataRow(cells: [
              DataCell(Text(dataExibicao, style: const TextStyle(fontWeight: FontWeight.w500))),
              DataCell(Text(e1)),
              DataCell(Text(s1)),
              DataCell(Text(e2)),
              DataCell(Text(s2)),
              DataCell(Text(total, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: corStatus.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(obs, style: TextStyle(color: corStatus, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}