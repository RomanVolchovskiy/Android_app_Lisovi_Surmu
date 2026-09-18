import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Generates a DOCX (Word) file with the thematic plan table.
class DocxGenerator {
  // ── Column widths in twentieths of a point (twips). A4 landscape usable ≈ 15840 twips.
  static const int _wNum   = 720;   // №
  static const int _wName  = 5760;  // Назва теми
  static const int _wTotal = 1080;  // Всього
  static const int _wLect  = 1080;  // Лекції
  static const int _wPract = 1440;  // Практичні
  static const int _wSelf  = 1440;  // Самостійні
  // Total: 720+5760+1080+1080+1440+1440 = 11520 (fits A4 landscape margins)

  static const String _darkGreen = '1C3A1C';
  static const String _gold      = 'D4A017';
  static const String _cream     = 'FFF8E7';
  static const String _sumBg     = 'EAD98B';
  static const String _white     = 'FFFFFF';

  /// Generates DOCX bytes for the thematic plan.
  /// [levelName] – display name of the level
  /// [rows] – list of (name, total, lect, pract, self) tuples
  static Uint8List generate({
    required String levelName,
    required List<({String name, int total, int lect, int pract, int self})> rows,
  }) {
    final sumTotal = rows.fold(0, (s, r) => s + r.total);
    final sumLect  = rows.fold(0, (s, r) => s + r.lect);
    final sumPract = rows.fold(0, (s, r) => s + r.pract);
    final sumSelf  = rows.fold(0, (s, r) => s + r.self);

    final doc = _buildDocument(levelName, rows, sumTotal, sumLect, sumPract, sumSelf);
    final rels = _contentTypesXml();
    final wordRels = _wordRelsXml();
    final styles = _stylesXml();
    final settings = _settingsXml();

    final archive = Archive();
    void addFile(String name, String content) {
      final bytes = content.codeUnits;
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addFile('[Content_Types].xml', rels);
    addFile('_rels/.rels', _rootRels());
    addFile('word/document.xml', doc);
    addFile('word/_rels/document.xml.rels', wordRels);
    addFile('word/styles.xml', styles);
    addFile('word/settings.xml', settings);

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  // ─────────────────────────────────────────────────────────────────────────

  static String _buildDocument(
    String levelName,
    List<({String name, int total, int lect, int pract, int self})> rows,
    int sumTotal, int sumLect, int sumPract, int sumSelf,
  ) {
    final sb = StringBuffer();
    sb.write('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
  xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
  xmlns:o="urn:schemas-microsoft-com:office:office"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
  xmlns:v="urn:schemas-microsoft-com:vml"
  xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:w10="urn:schemas-microsoft-com:office:word"
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"
  xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup"
  xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk"
  xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml"
  xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"
  mc:Ignorable="w14 wp14">
<w:body>
''');

    // Title paragraph
    sb.write(_titlePara('Тематичний план — $levelName рівень'));

    // Table
    sb.write('<w:tbl>');
    sb.write(_tblPr());

    // Header row 1: №, Назва теми, "Кількість годин" (spans 4)
    sb.write(_headerRow1());

    // Header row 2: sub-headers for the 4 hours columns
    sb.write(_headerRow2());

    // Data rows
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      sb.write(_dataRow(i + 1, r.name, r.total, r.lect, r.pract, r.self, i % 2 == 1));
    }

    // Total row
    sb.write(_totalRow(sumTotal, sumLect, sumPract, sumSelf));

    sb.write('</w:tbl>');

    // Required empty paragraph after table
    sb.write('<w:p><w:pPr><w:jc w:val="left"/></w:pPr></w:p>');
    sb.write('<w:sectPr>');
    // A4 landscape: 16838 x 11906 twips
    sb.write('<w:pgSz w:w="16838" w:h="11906" w:orient="landscape"/>');
    sb.write('<w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720" w:header="708" w:footer="708" w:gutter="0"/>');
    sb.write('</w:sectPr>');
    sb.write('</w:body></w:document>');
    return sb.toString();
  }

  static String _tblPr() => '''
<w:tblPr>
  <w:tblStyle w:val="TableGrid"/>
  <w:tblW w:w="0" w:type="auto"/>
  <w:tblBorders>
    <w:top    w:val="single" w:sz="4" w:space="0" w:color="1C3A1C"/>
    <w:left   w:val="single" w:sz="4" w:space="0" w:color="1C3A1C"/>
    <w:bottom w:val="single" w:sz="4" w:space="0" w:color="1C3A1C"/>
    <w:right  w:val="single" w:sz="4" w:space="0" w:color="1C3A1C"/>
    <w:insideH w:val="single" w:sz="4" w:space="0" w:color="E8C87A"/>
    <w:insideV w:val="single" w:sz="4" w:space="0" w:color="E8C87A"/>
  </w:tblBorders>
  <w:tblCellMar>
    <w:top    w:w="80"  w:type="dxa"/>
    <w:left   w:w="120" w:type="dxa"/>
    <w:bottom w:w="80"  w:type="dxa"/>
    <w:right  w:w="120" w:type="dxa"/>
  </w:tblCellMar>
</w:tblPr>
''';

  static String _headerRow1() {
    final hoursW = _wTotal + _wLect + _wPract + _wSelf;
    return '''
<w:tr>
  ${_hCell(_wNum,  '№',           _darkGreen, _gold, vMerge: 'restart', bold: true)}
  ${_hCell(_wName, 'Назва теми',  _darkGreen, _gold, vMerge: 'restart', bold: true)}
  ${_hCell(hoursW, 'Кількість годин', _darkGreen, _gold, gridSpan: 4, bold: true)}
</w:tr>
''';
  }

  static String _headerRow2() {
    return '''
<w:tr>
  ${_hCell(_wNum,   '', _darkGreen, _gold, vMerge: 'continue')}
  ${_hCell(_wName,  '', _darkGreen, _gold, vMerge: 'continue')}
  ${_hCell(_wTotal, 'Всього',      '2E5E2E', 'FFFFFF', bold: true)}
  ${_hCell(_wLect,  'Лекції',      '2E5E2E', 'FFFFFF', bold: true)}
  ${_hCell(_wPract, 'Практичні',   '2E5E2E', 'FFFFFF', bold: true)}
  ${_hCell(_wSelf,  'Самостійні',  '2E5E2E', 'FFFFFF', bold: true)}
</w:tr>
''';
  }

  static String _dataRow(int num, String name, int total, int lect, int pract, int self, bool odd) {
    final bg = odd ? _white : _cream;
    return '''
<w:tr>
  ${_dCell(_wNum,   '$num',                            bg, center: true, bold: true)}
  ${_dCell(_wName,  name,                              bg)}
  ${_dCell(_wTotal, '$total',                          bg, center: true, bold: true, color: _darkGreen)}
  ${_dCell(_wLect,  lect  > 0 ? '$lect'  : '\u2014',  bg, center: true)}
  ${_dCell(_wPract, pract > 0 ? '$pract' : '\u2014',  bg, center: true)}
  ${_dCell(_wSelf,  self  > 0 ? '$self'  : '\u2014',  bg, center: true)}
</w:tr>
''';
  }

  static String _totalRow(int total, int lect, int pract, int self) {
    return '''
<w:tr>
  ${_dCell(_wNum,   '',        _sumBg)}
  ${_dCell(_wName,  'Разом',   _sumBg, bold: true, color: _darkGreen)}
  ${_dCell(_wTotal, '$total',  _sumBg, center: true, bold: true, color: _darkGreen)}
  ${_dCell(_wLect,  '$lect',   _sumBg, center: true, bold: true)}
  ${_dCell(_wPract, '$pract',  _sumBg, center: true, bold: true)}
  ${_dCell(_wSelf,  '$self',   _sumBg, center: true, bold: true)}
</w:tr>
''';
  }

  // ── Cell builders ────────────────────────────────────────────────────────

  static String _hCell(int w, String text, String bg, String fg, {
    int gridSpan = 1,
    String? vMerge,
    bool bold = false,
  }) {
    final spanXml = gridSpan > 1 ? '<w:gridSpan w:val="$gridSpan"/>' : '';
    final mergeXml = vMerge != null
        ? vMerge == 'restart'
            ? '<w:vMerge w:val="restart"/>'
            : '<w:vMerge/>'
        : '';
    return '''
<w:tc>
  <w:tcPr>
    <w:tcW w:w="$w" w:type="dxa"/>
    $spanXml
    $mergeXml
    <w:shd w:val="clear" w:color="auto" w:fill="$bg"/>
    <w:vAlign w:val="center"/>
  </w:tcPr>
  <w:p>
    <w:pPr>
      <w:jc w:val="center"/>
      <w:rPr>
        <w:color w:val="$fg"/>
        ${bold ? '<w:b/>' : ''}
        <w:sz w:val="20"/>
        <w:szCs w:val="20"/>
      </w:rPr>
    </w:pPr>
    <w:r>
      <w:rPr>
        <w:color w:val="$fg"/>
        ${bold ? '<w:b/>' : ''}
        <w:sz w:val="20"/>
        <w:szCs w:val="20"/>
      </w:rPr>
      <w:t>${_esc(text)}</w:t>
    </w:r>
  </w:p>
</w:tc>
''';
  }

  static String _dCell(int w, String text, String bg, {
    bool center = false,
    bool bold = false,
    String color = '000000',
  }) {
    return '''
<w:tc>
  <w:tcPr>
    <w:tcW w:w="$w" w:type="dxa"/>
    <w:shd w:val="clear" w:color="auto" w:fill="$bg"/>
    <w:vAlign w:val="center"/>
  </w:tcPr>
  <w:p>
    <w:pPr>
      <w:jc w:val="${center ? 'center' : 'left'}"/>
      <w:rPr>
        <w:color w:val="$color"/>
        ${bold ? '<w:b/>' : ''}
        <w:sz w:val="20"/>
        <w:szCs w:val="20"/>
      </w:rPr>
    </w:pPr>
    <w:r>
      <w:rPr>
        <w:color w:val="$color"/>
        ${bold ? '<w:b/>' : ''}
        <w:sz w:val="20"/>
        <w:szCs w:val="20"/>
      </w:rPr>
      <w:t xml:space="preserve">${_esc(text)}</w:t>
    </w:r>
  </w:p>
</w:tc>
''';
  }

  static String _titlePara(String text) => '''
<w:p>
  <w:pPr>
    <w:jc w:val="center"/>
    <w:spacing w:after="200"/>
    <w:rPr><w:b/><w:sz w:val="28"/><w:szCs w:val="28"/><w:color w:val="1C3A1C"/></w:rPr>
  </w:pPr>
  <w:r>
    <w:rPr><w:b/><w:sz w:val="28"/><w:szCs w:val="28"/><w:color w:val="1C3A1C"/></w:rPr>
    <w:t>${_esc(text)}</w:t>
  </w:r>
</w:p>
''';

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  // ── Supporting XML files ─────────────────────────────────────────────────

  static String _contentTypesXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml"  ContentType="application/xml"/>
  <Override PartName="/word/document.xml"
    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml"
    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/settings.xml"
    ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
</Types>
''';

  static String _rootRels() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
    Target="word/document.xml"/>
</Relationships>
''';

  static String _wordRelsXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles"
    Target="styles.xml"/>
  <Relationship Id="rId2"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings"
    Target="settings.xml"/>
</Relationships>
''';

  static String _stylesXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
          xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"
          mc:Ignorable="w14"
          xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>
        <w:sz w:val="24"/>
        <w:szCs w:val="24"/>
        <w:lang w:val="uk-UA" w:eastAsia="uk-UA" w:bidi="ar-SA"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
  <w:style w:type="table" w:styleId="TableGrid">
    <w:name w:val="Table Grid"/>
    <w:tblPr>
      <w:tblBorders>
        <w:top    w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:left   w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:right  w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>
      </w:tblBorders>
    </w:tblPr>
  </w:style>
</w:styles>
''';

  static String _settingsXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:compat>
    <w:compatSetting w:name="compatibilityMode" w:uri="http://schemas.microsoft.com/office/word" w:val="15"/>
  </w:compat>
</w:settings>
''';
}
