DateTime utcDateTimeFromJson(String s) => DateTime.parse(s).toUtc();
String utcDateTimeToJson(DateTime dt) => dt.toUtc().toIso8601String();

DateTime? utcDateTimeOrNullFromJson(String? s) =>
    s == null ? null : DateTime.parse(s).toUtc();
String? utcDateTimeOrNullToJson(DateTime? dt) =>
    dt?.toUtc().toIso8601String();
