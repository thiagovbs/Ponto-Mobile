import 'package:hive/hive.dart';

part 'funcionario_totem.g.dart';

@HiveType(typeId: 0)
class FuncionarioTotem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String nome;

  @HiveField(2)
  final String cpf;

  @HiveField(3)
  final String perfil;

  @HiveField(4)
  final String? horarioBaseId;

  @HiveField(5)
  final String? dataInicioEscala;

  // 🟢 NOVOS ATRIBUTOS CORPORATIVOS OBRIGATÓRIOS DO SCHEMA (MULTI-TENANT)
  @HiveField(6)
  final String empresaId;

  @HiveField(7)
  final String filialId;

  @HiveField(8)
  final String setorId;

  FuncionarioTotem({
    required this.id,
    required this.nome,
    required this.cpf,
    required this.perfil,
    this.horarioBaseId,
    this.dataInicioEscala,
    required this.empresaId,
    required this.filialId,
    required this.setorId,
  });

  // Fábrica para converter o JSON da sua API diretamente no Model do Flutter
  factory FuncionarioTotem.fromJson(Map<String, dynamic> json) {
    return FuncionarioTotem(
      id: json['id'] as String,
      nome: json['nome'] as String,
      cpf: json['cpf'] as String,
      perfil: json['perfil'] as String,
      horarioBaseId: json['horarioBaseId'] as String?,
      dataInicioEscala: json['dataInicioEscala'] as String?,
      // 🟢 MAPEAMENTO REATIVO DAS NOVAS CHAVES ESTRUTURAIS DO BANCO POSTGRESQL
      empresaId: (json['empresaId'] ?? 'id-empresa-padrao') as String,
      filialId: (json['filialId'] ?? 'id-filial-padrao') as String,
      setorId: (json['setorId'] ?? 'id-setor-padrao') as String,
    );
  }
}