# دليل تحديث رقم الإصدار — Link Xtream

هذا الملف يوضح **كل مكان يجب تحديث رقم الإصدار فيه** حتى يتعرّف التطبيق على التحديث الجديد ويقبله من السيرفر، مع شرح الفرق بين الملفات الوظيفية (التي تؤثر فعلياً على التحديث) والملفات التوثيقية.

> القاعدة الذهبية: التطبيق المثبّت **لا يقرأ رقم الإصدار من ملف التثبيت**، بل يجلب ملف `version.json` من فرع `main` على GitHub ويقارنه بالقيم المدمجة داخل التطبيق نفسه في `updater.dart`. لذلك يجب تحديث **الملفين معاً** ورفعهما.

---

## 1. الملفات الوظيفية (إلزامية — بدونها لن يظهر التحديث)

| # | الملف | ما يجب تغييره | سبب الأهمية |
|---|-------|----------------|--------------|
| 1 | `pubspec.yaml` | `version: X.Y.Z+N` | يحدد إصدار البناء ورقم النسخة داخل ملف `link_xtream.exe` (يُقرأ تلقائياً في `windows/runner`). |
| 2 | `lib/services/updater.dart` | `currentVersion = 'X.Y.Z'` و `currentBuildNumber = N` | هذه هي القيم التي يقارن بها التطبيق المثبّت نسخة السيرفر. إذا بقيت قديمة فلن يظهر التحديث أبداً. |
| 3 | `version.json` | `version` و `build_number` و `release_date` و `download_url` و `changelog` | هذا هو **ملف الإعلان عن التحديث** الذي يجلبه التطبيق من السيرفر. يجب رفعه إلى فرع `main` وليس فقط إلى صفحة الإصدارات. |
| 4 | `installer/LinkXtream.iss` | `#define MyAppVersion "X.Y.Z"` و `VersionInfoVersion=X.Y.Z.0` (وتعليق اسم الملف الناتج) | يحدد إصدار المثبّت واسم ملف الـ Setup الناتج. |
| 5 | `lib/services/xtream_api.dart` | `uaApp = 'LinkXtream/X.Y.Z'` | وكيل التطبيق المُرسل للخادم (تشخيصي، لكن يُفضّل مزامنته). |
| 6 | `lib/screens/settings_screen.dart` | نص `'الإصدار X.Y.Z'` | يظهر للمستخدم في «حول التطبيق»، ويجب أن يطابق النسخة الفعلية. |
| 7 | `lib/screens/login_screen.dart` | نص `'vX.Y.Z'` | يظهر أسفل شاشة تسجيل الدخول. |
| 8 | `test/core_test.dart` | توقعات `UpdateService.isNewerVersion(...)` | ليست ضرورية للتحديث، لكن يجب تحديثها لتبقى الاختبارات ناجحة بعد تغيير `currentVersion/currentBuildNumber`. |

---

## 2. الملفات التوثيقية (مستحسنة)

| الملف | ما يجب تغييره |
|-------|----------------|
| `README-AR.md` | إضافة قسم في «سجل التحديثات» + تحديث اسم ملف المثبّت ورقم الإصدار في قسم إنشاء نسخة التثبيت. |

---

## 3. ملفات لا تحتاج تعديلاً يدوياً

- `windows/runner/Runner.rc`
- `windows/runner/CMakeLists.txt`

هذه الملفات تقرأ `FLUTTER_VERSION` و `FLUTTER_VERSION_MAJOR/MINOR/PATCH/BUILD` تلقائياً من `pubspec.yaml` أثناء البناء، فلا تُكتب فيها أرقام إصدار يدوياً.

---

## 4. خطوات النشر الصحيحة (بالترتيب)

1. اختر الرقم الجديد، مثال: `1.7.2` مع بناء `13`.
2. حدّث الملفات الوظيفية الثمانية أعلاه.
3. شغّل الاختبارات:
   ```powershell
   flutter test
   ```
4. ابنِ نسخة الويندوز:
   ```powershell
   flutter build windows --release
   ```
5. ابنِ المثبّت:
   ```powershell
   & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\LinkXtream.iss
   ```
   الناتج: `dist\Link-Xtream-Setup-1.7.2.exe`
6. أنشئ وسم (tag) جديداً على GitHub، مثال `v1.7.2`، وارفع ملف الـ Setup كمرفق (Asset) في الـ Release.
7. **تأكد أن `download_url` داخل `version.json` يطابق رابط المرفق الحقيقي حرفياً.**
8. **ارفع `version.json` إلى فرع `main`** (هذه الخطوة هي التي يقرأها التطبيق فعلياً):
   ```powershell
   git add version.json
   git commit -m "release: v1.7.2"
   git push origin main
   ```
9. انتظر من دقيقة إلى 5 دقائق (تخزين GitHub المؤقت لملفات `raw`)، ثم من داخل التطبيق:
   **الإعدادات ← حول التطبيق ← التحقق من وجود تحديثات جديدة**.

---

## 5. كيف يعرف التطبيق أن هناك تحديثاً؟

داخل `lib/services/updater.dart`:

```dart
static const String currentVersion = '1.7.2';
static const int currentBuildNumber = 13;

static const String defaultUpdateUrl =
    'https://raw.githubusercontent.com/Muadbaka/link-xtream/main/version.json';
```

ويُعتبر هناك تحديث إذا تحقق أحد الشرطين:

- `build_number` في `version.json` **أكبر من** `currentBuildNumber` المدمج في التطبيق.
- أو `version` في `version.json` **أعلى دلالياً** من `currentVersion` المدمج في التطبيق.

لذلك:

| الحالة | النتيجة |
|--------|---------|
| حدّثت `version.json` فقط | التطبيقات القديمة ستظهر لها التحديث، لكن النسخة الجديدة ستظل ترى نفسها بحاجة لتحديث (لأن رقمها المدمج لم يتغيّر). |
| حدّثت `updater.dart` فقط | **لن يظهر أي تحديث**، لأن السيرفر ما زال يعلن الرقم القديم. |
| حدّثت الاثنين ورفعت `version.json` إلى `main` | يعمل التحديث بشكل صحيح. |

---

## 6. قائمة تحقق سريعة قبل النشر

- [ ] `pubspec.yaml` → `version: X.Y.Z+N`
- [ ] `lib/services/updater.dart` → `currentVersion` و `currentBuildNumber`
- [ ] `version.json` → الإصدار ورقم البناء وتاريخ الإصدار ورابط التحميل وسجل التغييرات
- [ ] `installer/LinkXtream.iss` → `MyAppVersion` و `VersionInfoVersion`
- [ ] `lib/services/xtream_api.dart` → `uaApp`
- [ ] `lib/screens/settings_screen.dart` → نص الإصدار
- [ ] `lib/screens/login_screen.dart` → نص الإصدار
- [ ] `test/core_test.dart` → تحديث توقعات المقارنة (إن لزم)
- [ ] بناء `flutter build windows --release`
- [ ] إنشاء الـ Setup عبر Inno Setup
- [ ] رفع الـ Setup إلى GitHub Releases
- [ ] التأكد من `download_url`
- [ ] رفع `version.json` إلى `main` عبر `git push`

---

## 7. التحقق من أن السيرفر يعلن الإصدار الجديد

```powershell
$u = "https://raw.githubusercontent.com/Muadbaka/link-xtream/main/version.json?t=" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
(Invoke-WebRequest -UseBasicParsing -Uri $u).Content
```

يجب أن يظهر:

```json
{
  "version": "1.7.2",
  "build_number": 13
}
```

إن ظهر الرقم القديم، فالملف لم يُرفع إلى `main` بعد، أو أن التخزين المؤقت لدى GitHub لم ينتهِ بعد (حتى 5 دقائق تقريباً).
