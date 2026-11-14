/// تعلّم موضع بداية اعتمادات نهاية الحلقة (End Credits) من سلوك المستخدم.
///
/// الفكرة: عند ضغط «تخطي النهاية» أو إغلاق المشغّل بعد ظهور شريط التخطي،
/// نسجّل نسبة الموضع من مدة الحلقة. وعند تكرار نسبة متقاربة في حلقتين على
/// الأقل من نفس المسلسل نعتمدها كبداية اعتماد ونطبّقها تلقائياً على بقية
/// الحلقات بدل انتظار عدّاد النهاية الكامل (الذي يتضمن الموسيقى الختامية).
class CreditsLearning {
  CreditsLearning._();

  /// أدنى نسبة مقبولة — أقل من ذلك يعني مشاهدة جزئية وليست نهاية حقيقية.
  static const double minRatio = 0.85;

  /// أعلى نسبة مقبولة — أعلى من ذلك يعني أن المستخدم شاهد الاعتمادات كاملة.
  static const double maxRatio = 0.995;

  /// نصف نافذة التقارب بين العينات (2%).
  static const double tolerance = 0.02;

  /// أقصى عدد عينات محفوظة لكل مسلسل.
  static const int maxSamples = 8;

  /// عدد العينات المتقاربة المطلوب لاعتماد النسبة.
  static const int minSamples = 2;

  /// يضيف عينة جديدة (مع تقليم القائمة) ويعيد القائمة المحدّثة.
  static List<double> addSample(List<double> samples, double ratio) {
    final list = [...samples, ratio];
    if (list.length <= maxSamples) return list;
    return list.sublist(list.length - maxSamples);
  }

  /// يعيد النسبة المعتمدة إذا وُجدت عينتان متقاربتان على الأقل، وإلا null.
  ///
  /// يُعتمد أكبر تجمّع من العينات ضمن ±[tolerance] ويؤخذ متوسطه لتقليل
  /// تأثر النتيجة بأي عينة شاذة.
  static double? decide(List<double> samples) {
    final valid = samples
        .where((r) => r >= minRatio && r <= maxRatio && r.isFinite)
        .toList(growable: false);
    if (valid.length < minSamples) return null;

    double? bestRatio;
    var bestCount = 0;
    for (final center in valid) {
      final cluster =
          valid.where((r) => (r - center).abs() <= tolerance).toList();
      if (cluster.length > bestCount) {
        bestCount = cluster.length;
        bestRatio = cluster.reduce((a, b) => a + b) / cluster.length;
      }
    }
    return bestCount >= minSamples ? bestRatio : null;
  }
}
