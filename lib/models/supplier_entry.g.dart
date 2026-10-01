// GENERATED CODE - DO NOT MODIFY BY HAND
// NOTE: hand-written to match this project's existing convention (see
// supplier.g.dart) since build_runner isn't run in this environment. If
// you re-run build_runner, it will regenerate an equivalent file from
// supplier_entry.dart.

part of 'supplier_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SupplierOrderItemAdapter extends TypeAdapter<SupplierOrderItem> {
  @override
  final int typeId = 11;

  @override
  SupplierOrderItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SupplierOrderItem(
      name: fields[0] as String,
      costPrice: fields[1] as double,
      sellPrice: fields[2] as double,
      quantity: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SupplierOrderItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.costPrice)
      ..writeByte(2)
      ..write(obj.sellPrice)
      ..writeByte(3)
      ..write(obj.quantity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierOrderItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SupplierEntryAdapter extends TypeAdapter<SupplierEntry> {
  @override
  final int typeId = 12;

  @override
  SupplierEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SupplierEntry(
      title: fields[0] as String,
      amount: fields[1] as double,
      date: fields[2] as DateTime,
      note: fields[3] as String,
      items: (fields[4] as List?)?.cast<SupplierOrderItem>(),
    );
  }

  @override
  void write(BinaryWriter writer, SupplierEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.note)
      ..writeByte(4)
      ..write(obj.items);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}