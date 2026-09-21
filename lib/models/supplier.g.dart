// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SupplierPaymentAdapter extends TypeAdapter<SupplierPayment> {
  @override
  final int typeId = 3;

  @override
  SupplierPayment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SupplierPayment(
      amountPaid: fields[0] as double,
      date: fields[1] as DateTime,
      notes: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SupplierPayment obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.amountPaid)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierPaymentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SupplierAdapter extends TypeAdapter<Supplier> {
  @override
  final int typeId = 4;

  @override
  Supplier read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Supplier(
      name: fields[0] as String,
      notes: fields[1] as String,
      payments: (fields[2] as List?)?.cast<SupplierPayment>(),
      remainingAmount: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Supplier obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.notes)
      ..writeByte(2)
      ..write(obj.payments)
      ..writeByte(3)
      ..write(obj.remainingAmount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
