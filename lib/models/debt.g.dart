// GENERATED CODE - DO NOT MODIFY BY HAND
// NOTE: hand-updated to add HiveFields 9-12 (capital recovery tracking).
// Older records simply lack those keys and read safe defaults. If you
// re-run build_runner, it will regenerate an equivalent file from
// debt.dart.

part of 'debt.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DebtAdapter extends TypeAdapter<Debt> {
  @override
  final int typeId = 5;

  @override
  Debt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Debt(
      customerName: fields[0] as String,
      totalAmount: fields[1] as double,
      paidAmount: fields[2] as double,
      remainingAmount: fields[3] as double,
      itemsTaken: (fields[4] as List).cast<String>(),
      createdAt: fields[5] as DateTime,
      // .toList() keeps the list growable so new credit purchases can be
      // merged into an existing debt account.
      saleItems: (fields[6] as List?)?.cast<SaleItem>().toList(),
      totalProfit: (fields[7] as double?) ?? 0.0,
      isPaid: (fields[8] as bool?) ?? false,
      recoveredCapital: fields[9] as double?,
      realizedProfit: fields[10] as double?,
      legacyReleasedRatio: (fields[11] as double?) ?? 0.0,
      legacyItemCount: (fields[12] as int?) ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, Debt obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.customerName)
      ..writeByte(1)
      ..write(obj.totalAmount)
      ..writeByte(2)
      ..write(obj.paidAmount)
      ..writeByte(3)
      ..write(obj.remainingAmount)
      ..writeByte(4)
      ..write(obj.itemsTaken)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.saleItems)
      ..writeByte(7)
      ..write(obj.totalProfit)
      ..writeByte(8)
      ..write(obj.isPaid)
      ..writeByte(9)
      ..write(obj.recoveredCapital)
      ..writeByte(10)
      ..write(obj.realizedProfit)
      ..writeByte(11)
      ..write(obj.legacyReleasedRatio)
      ..writeByte(12)
      ..write(obj.legacyItemCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebtAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
