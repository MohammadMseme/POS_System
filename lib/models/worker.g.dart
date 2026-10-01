// GENERATED CODE - DO NOT MODIFY BY HAND
// NOTE: hand-written to match this project's existing convention (see
// supplier.g.dart) since build_runner isn't run in this environment. If
// you re-run `flutter pub run build_runner build`, it will regenerate an
// equivalent file from worker.dart.

part of 'worker.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkerPaymentAdapter extends TypeAdapter<WorkerPayment> {
  @override
  final int typeId = 8;

  @override
  WorkerPayment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkerPayment(
      amount: fields[0] as double,
      date: fields[1] as DateTime,
      note: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, WorkerPayment obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.amount)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkerPaymentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkerAdapter extends TypeAdapter<Worker> {
  @override
  final int typeId = 9;

  @override
  Worker read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Worker(
      name: fields[0] as String,
      addedAt: fields[1] as DateTime,
      payments: (fields[2] as List?)?.cast<WorkerPayment>(),
    );
  }

  @override
  void write(BinaryWriter writer, Worker obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.addedAt)
      ..writeByte(2)
      ..write(obj.payments);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}