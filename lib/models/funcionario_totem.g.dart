// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'funcionario_totem.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FuncionarioTotemAdapter extends TypeAdapter<FuncionarioTotem> {
  @override
  final int typeId = 0;

  @override
  FuncionarioTotem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FuncionarioTotem(
      id: fields[0] as String,
      nome: fields[1] as String,
      cpf: fields[2] as String,
      perfil: fields[3] as String,
      horarioBaseId: fields[4] as String?,
      dataInicioEscala: fields[5] as String?,
      empresaId: fields[6] as String,
      filialId: fields[7] as String,
      setorId: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, FuncionarioTotem obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nome)
      ..writeByte(2)
      ..write(obj.cpf)
      ..writeByte(3)
      ..write(obj.perfil)
      ..writeByte(4)
      ..write(obj.horarioBaseId)
      ..writeByte(5)
      ..write(obj.dataInicioEscala)
      ..writeByte(6)
      ..write(obj.empresaId)
      ..writeByte(7)
      ..write(obj.filialId)
      ..writeByte(8)
      ..write(obj.setorId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FuncionarioTotemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
