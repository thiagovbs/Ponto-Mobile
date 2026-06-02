import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/funcionario_totem.dart';
import 'api_service.dart';

class TotemService {
  final _funcsBox = Hive.box<FuncionarioTotem>('funcionarios_box');
  final _pontosBox = Hive.box<Map>('pontos_offline_box');

  // A. Atualizar a listagem do Totem (Sempre tenta quando abrir o app ou em intervalos)
  Future<void> sincronizarFuncionariosAtivos() async {
    try {
      // Usando o método existente da sua API no Render
      final String urlCompleta = '${ApiService.dio.options.baseUrl}/usuarios';
      final response = await http.get(Uri.parse(urlCompleta));

      // Dentro do método sincronizarFuncionariosAtivos() no totem_service.dart:
      if (response.statusCode == 200) {
        final List<dynamic> dados = json.decode(response.body);
        await _funcsBox.clear();

        for (var item in dados) {
          // Mapeia usando a fábrica do modelo que criamos acima
          final novoFunc = FuncionarioTotem.fromJson(item);
          await _funcsBox.add(novoFunc);
        }
      }
    } catch (e) {
      // Não faz nada, mantém o cache existente na funcionarios_box
    }
  }

  // B. O Fluxo de Pesquisa Local Textual (Nome ou CPF)
  List<FuncionarioTotem> filtrarFuncionariosLocais(String termoBusca) {
    final todos = _funcsBox.values.toList();
    if (termoBusca.isEmpty) return todos;

    final termoLimpo = termoBusca.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

    return todos.where((func) {
      final nomeLimpo = func.nome.toLowerCase();
      final cpfLimpo = func.cpf.replaceAll(RegExp(r'[^0-9]'), '');

      return nomeLimpo.contains(termoLimpo) || cpfLimpo.contains(termoLimpo);
    }).toList();
  }

  // C. Registrar o Ponto no Totem (Garante a gravação imediata)
  Future<void> registrarPontoTotem({required String funcionarioId, double? lat, double? lng}) async {
    final pontoPayload = {
      'usuarioId': funcionarioId,
      'dataHora': DateTime.now().toIso8601String(),
      'latitude': lat ?? 0.0, // Banco exige Float, enviamos 0 se falhar o GPS
      'longitude': lng ?? 0.0,
    };

    try {
      // Tenta enviar direto pro Render imediatamente
      final String urlCompleta = '${ApiService.dio.options.baseUrl}/ponto/bater';
      final response = await http.post(
        Uri.parse(urlCompleta),
        body: json.encode(pontoPayload),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception("Erro do Servidor");
      }
      print("Ponto enviado online com sucesso!");
    } catch (e) {
      // 🚨 Deu ruim na conexão? Guarda na fila offline do celular
      await _pontosBox.add(pontoPayload);
      print("Sem rede. Ponto guardado no armazenamento local do Totem.");
    }
  }

  // D. Limpar Fila Offline (Enviar os pontos guardados assim que a internet voltar)
  Future<void> esvaziarFilaPontosOffline() async {
    if (_pontosBox.isEmpty) return;

    print("Internet restabelecida. Enviando pontos acumulados offline...");
    final chavesCopia = List.from(_pontosBox.keys);

    for (var chave in chavesCopia) {
      final ponto = _pontosBox.get(chave);
      try {
        final String urlCompleta = '${ApiService.dio.options.baseUrl}/ponto/bater';
        final response = await http.post(
          Uri.parse(urlCompleta),
          body: json.encode(ponto),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          await _pontosBox.delete(chave); // Remove da fila local se o Render aceitou
        }
      } catch (e) {
        break; // Para o loop se a internet oscilar no meio do processo
      }
    }
  }
}