enum DbType {
  hive,
  isar;

  String boxFileName(String name) => switch (this) {
    DbType.hive => '$name.hive',
    DbType.isar => '$name.isar',
  };
}
