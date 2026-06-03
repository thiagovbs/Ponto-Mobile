import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

class ApiService {
  // 1. Instância global do Dio
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://ponto-api-1iz6.onrender.com/api',
      connectTimeout: const Duration(seconds: 60), // Lembra dos 60s do Render? Mantenha!
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  // 2. Variável global na memória para guardar o Token recebido no login do Admin
  static String? token;

  // COMPONENTES MULTI-TENANT: Armazenam as chaves da organização configurada no Totem
  static String? empresaId;
  static String? filialId;
  static String? setorId;

  // COMPONENTE DE AUTENTICAÇÃO DO TABLET: Armazena o hash único da portaria
  static String? tokenTotem;

  // 3. Construtor estático para ativar os interceptors de segurança global
  static void inicializar() {
    dio.interceptors.clear(); // Limpa duplicados por segurança
    
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // 🪛 SE HOUVER TOKEN DE ADMIN SALVO, INJETA AUTOMATICAMENTE NO HEADER
          if (token != null && token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          
          // 🟢 RESOLUÇÃO DEFINITIVA: Se a variável de memória sumir, lê diretamente da persistência física do Hive em tempo real
          String? tokenEfetivo = tokenTotem;
          if (tokenEfetivo == null || tokenEfetivo.isEmpty) {
            if (Hive.isBoxOpen('configuracao_box')) {
              final box = Hive.box<String>('configuracao_box');
              tokenEfetivo = box.get('token_totem');
            }
          }

          // 🟢 HIGIENIZAÇÃO RÍGIDA DO CABEÇALHO: Remove quebras de linha ou caracteres de controle invisíveis colados pelo teclado do celular
          if (tokenEfetivo != null && tokenEfetivo.isNotEmpty) {
            final tokenLimpo = tokenEfetivo.replaceAll(RegExp(r'[\n\r\t ]'), '').trim();
            options.headers['x-totem-token'] = tokenLimpo;
          }
          
          options.headers['Content-Type'] = 'application/json';
          return handler.next(options); // Segue viagem com a requisição purificada
        },
        onError: (DioException e, handler) {
          return handler.next(e);
        },
      ),
    );
  }
}