// GENERATED CODE - DO NOT MODIFY BY HAND
// NOTE: hand-updated to add HiveField(6) category and HiveField(7)
// shelfNumber. If you re-run build_runner, it will regenerate an
// equivalent file from product.dart.

part of 'product.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 0;

  @override
  Product read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Product(
      barcode: fields[0] as String,
      name: fields[1] as String,
      costPrice: fields[2] as double,
      sellPrice: fields[3] as double,
      stockQuantity: fields[4] as int,
      createdAt: fields[5] as DateTime?,
      // Records written before this field existed simply won't have
      // keys 6/7 in the map, so they default safely to null (which
      // means "not set" everywhere in the UI).
      category: fields[6] as String?,
      shelfNumber: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.barcode)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.costPrice)
      ..writeByte(3)
      ..write(obj.sellPrice)
      ..writeByte(4)
      ..write(obj.stockQuantity)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.shelfNumber);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}