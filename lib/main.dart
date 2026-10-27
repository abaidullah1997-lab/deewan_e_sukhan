import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:screenshot/screenshot.dart';
import 'package:image/image.dart' as img;
import 'package:gal/gal.dart';

void main() => runApp(const DeewanApp());

class Poem {
  final String id;
  final String title;
  final String verses;
  final String meter;
  final String qafia;
  final String radeef;

  const Poem({
    required this.id,
    required this.title,
    required this.verses,
    required this.meter,
    required this.qafia,
    required this.radeef,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'verses': verses,
        'meter': meter,
        'qafia': qafia,
        'radeef': radeef,
      };

  factory Poem.fromJson(Map<String, dynamic> json) => Poem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        verses: json['verses']?.toString() ?? '',
        meter: json['meter']?.toString() ?? '',
        qafia: json['qafia']?.toString() ?? '',
        radeef: json['radeef']?.toString() ?? '',
      );
}

class DeewanApp extends StatelessWidget {
  const DeewanApp({super.key});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6C27A);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'دیوانِ عبید',
      theme: ThemeData(
fontFamily: 'JameelNooriNastaleeq',
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101827),
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF17243A),
          foregroundColor: gold,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          filled: true,
          fillColor: const Color(0xFF1C2A40),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: DeewanHome(),
      ),
    );
  }
}

class DeewanHome extends StatefulWidget {
  const DeewanHome({super.key});

  @override
  State<DeewanHome> createState() => _DeewanHomeState();
}

class _DeewanHomeState extends State<DeewanHome> {
  static const _storageKey = 'deewan_poems_v2';
  final List<Poem> _poems = [];
  final TextEditingController _search = TextEditingController();
  bool _loading = true;
  String? _loadError;
  int _tab = 0;
  bool _backupBusy = false;
double _poemFontSize = 20.0;
  
final ScreenshotController _posterScreenshotController = ScreenshotController();
  
Future<Uint8List> _makePosterPng(
  Poem poem,
  List<Color> colors, {
  required bool darkText,
}) async {
  final textColor = darkText
      ? const Color(0xFF302116)
      : Colors.white;

  final poster = Directionality(
    textDirection: TextDirection.rtl,
    child: Material(
      color: Colors.transparent,
      child: Container(
        width: 500,
        padding: const EdgeInsets.symmetric(
          horizontal: 30,
          vertical: 45,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: colors,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              poem.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'JameelNooriNastaleeq',
                fontSize: 28,
                color: textColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              poem.verses,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'JameelNooriNastaleeq',
                fontSize: _poemFontSize,
                height: 2,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  return _posterScreenshotController.captureFromLongWidget(
    InheritedTheme.captureAll(context, poster),
    context: context,
    pixelRatio: 2.0,
    delay: const Duration(milliseconds: 500),
    constraints: const BoxConstraints(
      maxWidth: 520,
    ),
  );
}
  
Future<void> _savePosterImage(
  Poem poem,
  List<Color> colors, {
  required bool darkText,
  required bool asJpg,
}) async {
  try {
    final pngBytes = await _makePosterPng(
      poem,
      colors,
      darkText: darkText,
    );

    Uint8List outputBytes = pngBytes;

    if (asJpg) {
      final image = img.decodeImage(pngBytes);

      if (image == null) {
        throw const FormatException(
          'تصویر تیار نہیں ہو سکی',
        );
      }

      outputBytes = Uint8List.fromList(
        img.encodeJpg(image, quality: 90),
      );
    }

    final extension = asJpg ? 'jpg' : 'png';

    final fileName =
        'deewan_poster_${DateTime.now().millisecondsSinceEpoch}.$extension';

    await Gal.putImageBytes(
      outputBytes,
      name: fileName,
    );

    if (!mounted) return;

    _message(
      'پوسٹر $extension فارمیٹ میں گیلری میں محفوظ ہو گیا',
    );
  } catch (e) {
    if (!mounted) return;

    _message('پوسٹر محفوظ نہیں ہو سکا: $e');
  }
}
  
Future<void> _sharePosterImage(
  Poem poem,
  List<Color> colors, {
  required bool darkText,
}) async {
  try {
    final pngBytes = await _makePosterPng(
      poem,
      colors,
      darkText: darkText,
    );

    final fileName =
        'deewan_poster_${DateTime.now().millisecondsSinceEpoch}.png';

    final file = File(
      '${Directory.systemTemp.path}/$fileName',
    );

    await file.writeAsBytes(
      pngBytes,
      flush: true,
    );

    await Share.shareXFiles(
      [XFile(file.path)],
    );
  } catch (e) {
    if (!mounted) return;

    _message(
      'پوسٹر شیئر نہیں ہو سکا: $e',
    );
  }
}
  
  @override
  void initState() {
    super.initState();
    _loadPoems();
  }

  Future<void> _loadPoems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _poems.addAll(decoded.map(
          (item) => Poem.fromJson(Map<String, dynamic>.from(item as Map)),
        ));
      }
    } catch (_) {
      _loadError = 'محفوظ شدہ شاعری پڑھنے میں مسئلہ آیا ہے۔';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _persist(List<Poem> updated) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(
        _storageKey,
        jsonEncode(updated.map((p) => p.toJson()).toList()),
      );
    } catch (_) {
      return false;
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _savePoem(Poem poem) async {
    final updated = List<Poem>.from(_poems);
    final index = updated.indexWhere((p) => p.id == poem.id);
    if (index >= 0) {
      updated[index] = poem;
    } else {
      updated.insert(0, poem);
    }
    if (await _persist(updated)) {
      if (!mounted) return false;
      setState(() {
        _poems..clear()..addAll(updated);
        _tab = 1;
      });
      _message('غزل محفوظ ہو گئی');
      return true;
    } else {
      _message('غزل محفوظ نہیں ہو سکی، دوبارہ کوشش کریں');
      return false;
    }
  }

  Future<void> _deletePoem(Poem poem) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('غزل حذف کریں؟'),
        content: Text('کیا آپ واقعی "${poem.title}" حذف کرنا چاہتے ہیں؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('نہیں'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف کریں'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = _poems.where((p) => p.id != poem.id).toList();
    if (await _persist(updated)) {
      if (!mounted) return;
      setState(() => _poems..clear()..addAll(updated));
      _message('غزل حذف کر دی گئی');
    } else {
      _message('حذف کرنے میں مسئلہ آیا');
    }
  }

  Future<void> _exportBackup() async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    File? temporaryFile;
    try {
      final payload = {
        'format': 'deewan-e-sukhan-backup',
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'poems': _poems.map((p) => p.toJson()).toList(),
      };
      final stamp = DateTime.now().millisecondsSinceEpoch;
      temporaryFile = File('${Directory.systemTemp.path}/deewan_backup_$stamp.json');
      await temporaryFile.writeAsString(jsonEncode(payload), flush: true);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(temporaryFile.path, mimeType: 'application/json')],
        text: 'دیوانِ عبید — غزلوں کا بیک اَپ',
      );
      if (mounted) {
        _message('شیئر مینو سے فائل کو محفوظ کریں؛ پھر فائل موجود ہونے کی تصدیق کریں۔');
      }
    } catch (_) {
      _message('بیک اَپ بنانے میں مسئلہ آیا۔ دوبارہ کوشش کریں۔');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _importBackup() async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      Uint8List? bytes = picked.bytes;
      if (bytes == null && picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      }
      if (bytes == null) throw const FormatException('Cannot read file');
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map || decoded['format'] != 'deewan-e-sukhan-backup' ||
          decoded['version'] != 1 || decoded['poems'] is! List) {
        throw const FormatException('Not a Deewan backup');
      }
      final rawPoems = decoded['poems'] as List;
      final imported = <Poem>[];
      final ids = <String>{};
      for (final item in rawPoems) {
        if (item is! Map) throw const FormatException('Invalid poem');
        final json = Map<String, dynamic>.from(item);
        for (final field in ['id', 'title', 'verses', 'meter', 'qafia', 'radeef']) {
          if (json[field] is! String) throw const FormatException('Invalid field');
        }
        final poem = Poem.fromJson(json);
        if (poem.id.isEmpty || poem.title.trim().isEmpty ||
            poem.verses.trim().isEmpty || !ids.add(poem.id)) {
          throw const FormatException('Invalid poem data');
        }
        imported.add(poem);
      }
      if (!mounted) return;
      final existingIds = _poems.map((p) => p.id).toSet();
      final additions = imported.where((p) => !existingIds.contains(p.id)).toList();
      final duplicates = imported.length - additions.length;
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('بیک اَپ بحال کریں؟'),
          content: Text('فائل میں ${imported.length} غزلیں ہیں۔\n'
              '${additions.length} نئی غزلیں شامل ہوں گی۔\n'
              '$duplicates پہلے سے موجود ہیں، انہیں تبدیل نہیں کیا جائے گا۔\n'
              'آپ کی موجودہ غزلیں حذف نہیں ہوں گی۔'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('منسوخ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('بحال کریں'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      if (additions.isEmpty) {
        _message('تمام غزلیں پہلے سے موجود ہیں؛ کوئی تبدیلی نہیں ہوئی۔');
        return;
      }
      final updated = [..._poems, ...additions];
      if (await _persist(updated)) {
        if (!mounted) return;
        setState(() {
          _poems..clear()..addAll(updated);
          _tab = 1;
        });
        _message('${additions.length} غزلیں کامیابی سے بحال ہو گئیں۔');
      } else {
        _message('بحالی محفوظ نہیں ہو سکی؛ پرانی غزلیں برقرار ہیں۔');
      }
    } catch (_) {
      _message('یہ فائل درست دیوانِ سخن بیک اَپ نہیں یا پڑھی نہیں جا سکی۔');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _openEditor([Poem? poem]) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: PoemEditor(poem: poem, onSave: _savePoem),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دیوانِ عبید')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(child: Text(_loadError!))
              : _tab == 0
                  ? _homePage()
                  : _libraryPage(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.edit_note),
        label: const Text('نئی غزل'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'ہوم'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'میرا دیوان'),
        ],
      ),
    );
  }

  Widget _homePage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 22),
        Image.asset('assets/ubaid.jpg', height: 110, width: 110, fit: BoxFit.cover),
        const SizedBox(height: 18),
        const Text(
          'دیوانِ عبید میں خوش آمدید',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'اپنی غزلیں لکھیں، محفوظ کریں اور اپنے دیوان میں سجائیں۔',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('آپ کی محفوظ غزلیں'),
                const SizedBox(height: 8),
                Text('${_poems.length}', style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('غزل لکھیں'),
                ),
                TextButton(
                  onPressed: () => setState(() => _tab = 1),
                  child: const Text('میرا دیوان کھولیں'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'شاعر: راجہ عبیداللہ عبید',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFE6C27A)),
        ),
      ],
    );
  }

  Widget _libraryPage() {
    final query = _search.text.trim().toLowerCase();
    final filtered = _poems.where((p) {
      return p.title.toLowerCase().contains(query) ||
          p.verses.toLowerCase().contains(query) ||
          p.meter.toLowerCase().contains(query);
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _backupBusy ? null : _exportBackup,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('بیک اَپ بنائیں'),
              ),
              OutlinedButton.icon(
                onPressed: _backupBusy ? null : _importBackup,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('بیک اَپ بحال کریں'),
              ),
            ],
          ),
        ),
        
Padding(
  padding: const EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 8,
  ),
  child: Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 8,
    children: [
      OutlinedButton(
        onPressed: _poemFontSize > 14
            ? () {
                setState(() {
                  _poemFontSize -= 2;
                });
              }
            : null,
        child: const Text('A−'),
      ),
      Text('سائز: ${_poemFontSize.toInt()}'),
      FilledButton(
        onPressed: _poemFontSize < 36
            ? () {
                setState(() {
                  _poemFontSize += 2;
                });
              }
            : null,
        child: const Text('A+'),
      ),
    ],
  ),
),
        
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'غزل تلاش کریں',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _poems.isEmpty
                        ? 'ابھی کوئی غزل محفوظ نہیں۔ نئی غزل لکھیں۔'
                        : 'کوئی غزل نہیں ملی۔',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final poem = filtered[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(poem.title,
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            
Text(
  poem.verses,
  style: TextStyle(fontSize: _poemFontSize),
  maxLines: 4,
  overflow: TextOverflow.ellipsis,
),

                            if (poem.meter.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('بحر: ${poem.meter}',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                            Wrap(
                              spacing: 8,
                              children: [
                                
TextButton.icon(
  onPressed: () {
    const posterThemes = <String, List<Color>>{
      'شاہی سنہری': [
        Color(0xFF17243A),
        Color(0xFF453014),
      ],
      'رومانوی گلابی': [
        Color(0xFF4A1838),
        Color(0xFF9C5277),
      ],
      'زمردی سبز': [
        Color(0xFF102F2B),
        Color(0xFF39765D),
      ],
      'کلاسیکی کاغذی': [
        Color(0xFFF7E8CB),
        Color(0xFFC5A67C),
      ],
      'رات کا آسمان': [
        Color(0xFF080E27),
        Color(0xFF243C73),
      ],
      'غروبِ آفتاب': [
        Color(0xFF612C42),
        Color(0xFFDF8B45),
      ],
'نیلمی رات': [
  Color(0xFF071C38),
  Color(0xFF244A70),
],
'جامنی خواب': [
  Color(0xFF241438),
  Color(0xFF684A86),
],
'سبز جنگل': [
  Color(0xFF0F281D),
  Color(0xFF315542),
],
'سرخ مخمل': [
  Color(0xFF2D0D16),
  Color(0xFF7C283B),
],
'سیاہ و سنہری': [
  Color(0xFF0B0B0D),
  Color(0xFF66501F),
],
'نیلا سمندر': [
  Color(0xFF063A47),
  Color(0xFF166A79),
],
};
    
    String selectedDesign = 'شاہی سنہری';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setPosterState) {
          final textColor =
              selectedDesign == 'کلاسیکی کاغذی'
                  ? const Color(0xFF302116)
                  : Colors.white;

          
return AlertDialog(
  scrollable: true,
  
            backgroundColor: const Color(0xFF101827),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          MediaQuery.of(context).size.height *
                          0.40,
                    ),
                    child: SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: posterThemes[
                                selectedDesign]!,
                          ),
                          borderRadius:
                              BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: [
                            Text(
                              poem.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily:
                                    'JameelNooriNastaleeq',
                                fontSize: 26,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              poem.verses,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily:
                                    'JameelNooriNastaleeq',
                                fontSize: _poemFontSize,
                                height: 2,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'پوسٹر کا ڈیزائن منتخب کریں',
                    style: TextStyle(
                      color: Color(0xFFE6C27A),
                    ),
                  ),
                  DropdownButton<String>(
                    
                    value: selectedDesign,
                    isExpanded: true,
                    dropdownColor:
                        const Color(0xFF17243A),
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    items: posterThemes.keys.map((name) {
                      return DropdownMenuItem<String>(
                        value: name,
                        child: Text(name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setPosterState(() {
                          selectedDesign = value;
                        });
                      }
                    },
                  ),
                  
const SizedBox(height: 12),
Wrap(
  alignment: WrapAlignment.center,
  spacing: 8,
  runSpacing: 8,
  children: [
    OutlinedButton.icon(
      onPressed: () async {
        await _savePosterImage(
          poem,
          posterThemes[selectedDesign]!,
          darkText:
              selectedDesign == 'کلاسیکی کاغذی',
          asJpg: false,
        );
      },
      icon: const Icon(Icons.download),
      label: const Text('PNG'),
    ),
    OutlinedButton.icon(
      onPressed: () async {
        await _savePosterImage(
          poem,
          posterThemes[selectedDesign]!,
          darkText:
              selectedDesign == 'کلاسیکی کاغذی',
          asJpg: true,
        );
      },
      icon: const Icon(Icons.download),
      label: const Text('JPG'),
    ),
    FilledButton.icon(
      onPressed: () async {
        await _sharePosterImage(
          poem,
          posterThemes[selectedDesign]!,
          darkText:
              selectedDesign == 'کلاسیکی کاغذی',
        );
      },
      icon: const Icon(Icons.share),
      label: const Text('شیئر'),
    ),
  ],
),
                  
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext),
                child: const Text('بند کریں'),
              ),
            ],
          );
        },
      ),
    );
  },
  icon: const Icon(Icons.image_outlined),
  label: const Text('پوسٹر'),
),
  

                                
                                TextButton.icon(
                                  onPressed: () => _openEditor(poem),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('ترمیم'),
                                ),
                                TextButton.icon(
                                  onPressed: () => _deletePoem(poem),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('حذف'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class PoemEditor extends StatefulWidget {
  final Poem? poem;
  final Future<bool> Function(Poem) onSave;

  const PoemEditor({super.key, this.poem, required this.onSave});

  @override
  State<PoemEditor> createState() => _PoemEditorState();
}

class _PoemEditorState extends State<PoemEditor> {
  late final TextEditingController _title;
  late final TextEditingController _verses;
  late final TextEditingController _meter;
  late final TextEditingController _qafia;
  late final TextEditingController _radeef;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.poem;
    _title = TextEditingController(text: p?.title ?? '');
    _verses = TextEditingController(text: p?.verses ?? '');
    _meter = TextEditingController(text: p?.meter ?? '');
    _qafia = TextEditingController(text: p?.qafia ?? '');
    _radeef = TextEditingController(text: p?.radeef ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _verses.dispose();
    _meter.dispose();
    _qafia.dispose();
    _radeef.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _verses.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عنوان اور اشعار دونوں لکھیں')),
      );
      return;
    }
    setState(() => _saving = true);
    final poem = Poem(
      id: widget.poem?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      verses: _verses.text.trim(),
      meter: _meter.text.trim(),
      qafia: _qafia.text.trim(),
      radeef: _radeef.text.trim(),
    );
    final saved = await widget.onSave(poem);
    if (mounted) {
      setState(() => _saving = false);
      if (saved) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.poem == null ? 'نئی غزل' : 'غزل کی ترمیم')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'غزل کا عنوان *'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _verses,
            maxLines: 12,
            minLines: 7,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'اشعار *',
              hintText: 'ہر مصرع نئی سطر میں لکھیں',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _meter,
            decoration: const InputDecoration(labelText: 'بحر (اختیاری)'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _qafia,
            decoration: const InputDecoration(labelText: 'قافیہ (اختیاری)'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _radeef,
            decoration: const InputDecoration(labelText: 'ردیف (اختیاری)'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.save),
            label: Text(_saving ? 'محفوظ ہو رہی ہے...' : 'غزل محفوظ کریں'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
