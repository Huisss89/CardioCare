import 'dart:convert';

class CalibrationModel {
  // W has shape (d+1) x 2  (includes bias row at end)
  final List<List<double>> w;

  CalibrationModel({required this.w});

  Map<String, dynamic> toJson() => {"w": w};

  static CalibrationModel fromJson(Map<String, dynamic> json) {
    final wRaw = (json["w"] as List).map((row) => (row as List).map((v) => (v as num).toDouble()).toList()).toList();
    return CalibrationModel(w: wRaw);
  }

  /// x = [SBP0, DBP0, Height, Weight]  (length d)
  /// internally we append 1 for bias
  List<double> predict(List<double> x) {
    final xp = [...x, 1.0]; // (d+1)
    double sbp = 0.0;
    double dbp = 0.0;

    for (int i = 0; i < xp.length; i++) {
      sbp += xp[i] * w[i][0];
      dbp += xp[i] * w[i][1];
    }
    return [sbp, dbp];
  }

  String toStorageString() => jsonEncode(toJson());
  static CalibrationModel fromStorageString(String s) => fromJson(jsonDecode(s));
}
