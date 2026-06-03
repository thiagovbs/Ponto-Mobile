import 'package:dio/dio.dart';

class ApiService {
  // 1. Instância global do Dio
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://ponto-api-1iz6.onrender.com/api',
      //baseUrl: 'http://localhost:3003/api',
      connectTimeout: const Duration(seconds: 60), // Lembra dos 60s do Render? Mantenha!
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  // 2. Variável global na memória para guardar o Token recebido no login do Admin
  static String? token;

  // 🟢 COMPONENTES MULTI-TENANT: Armazenam as chaves da organização configurada no Totem
  static String? empresaId;
  static String? filialId;
  static String? setorId;

  // 🟢 COMPONENTE DE AUTENTICAÇÃO DO TABLET: Armazena o hash único da portaria
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
          
          // 🟢 INJEÇÃO AUTOMÁTICA DO TOKEN DO TOTEM: Alinhado com a aduana de segurança do backend
          if (tokenTotem != null && tokenTotem!.isNotEmpty) {
            options.headers['x-totem-token'] = tokenTotem;
          }
          
          options.headers['Content-Type'] = 'application/json';
          return handler.next(options); // Segue viagem com a requisição purificada
        },
        onError: (DioException e, handler) {
          // Aqui você pode tratar erros globais (como token expirado) no futuro
          return handler.next(e);
        },
      ),
    );
  }
}