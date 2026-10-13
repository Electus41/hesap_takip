import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfExportService {
  static Future<void> exportClientStatement({
    required Map<String, dynamic> client,
    required List<Map<String, dynamic>> transactions,
    required double totalBalance,
  }) async {
    final pdf = pw.Document();

    // Türkçe karakter sorunu yaşamamak için Google Fonts'tan Roboto çekiyoruz
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final String clientName = client['title'] ?? 'Bilinmeyen Mükellef';
    final String dateStr = DateFormat(
      'dd.MM.yyyy',
      'tr_TR',
    ).format(DateTime.now());

    // Bakiye Durumu Metni
    String balanceText = totalBalance > 0
        ? 'BORÇLU'
        : (totalBalance < 0 ? 'ALACAKLI' : 'KAPALI');

    // Tablo verilerini hazırlama (Başlıklar + Satırlar)
    final tableData = <List<String>>[
      ['Tarih', 'Açıklama', 'İşlem Tipi', 'Tutar'], // Başlık satırı
    ];

    for (var t in transactions) {
      final isPaid = t['is_paid'] as bool? ?? false;
      final amount = double.tryParse(t['amount'].toString()) ?? 0.0;

      String rowDate = '-';
      if (t['created_at'] != null) {
        try {
          rowDate = DateFormat(
            'dd.MM.yyyy',
          ).format(DateTime.parse(t['created_at']));
        } catch (_) {
          rowDate = t['created_at'].toString().split('T')[0];
        }
      }

      tableData.add([
        rowDate,
        t['description'] ?? 'İşlem',
        isPaid ? 'Tahsilat (-)' : 'Tahakkuk (+)',
        '${amount.toStringAsFixed(2)} TL',
      ]);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Üst Başlık (Header)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'HESAP EKSTRESİ',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 24,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.Text(
                    'Tarih: $dateStr',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                ],
              ),
              pw.Divider(thickness: 2, color: PdfColors.blueGrey300),
              pw.SizedBox(height: 20),

              // Müşteri ve Özet Bilgileri
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Sayın:',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        clientName,
                        style: pw.TextStyle(font: boldFont, fontSize: 16),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Yetkili: ${client['contact_name'] ?? '-'}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                      pw.Text(
                        'Vergi No: ${client['tax_no'] ?? '-'}',
                        style: pw.TextStyle(font: font, fontSize: 12),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(8),
                      ),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'GÜNCEL BAKİYE',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          '${totalBalance.abs().toStringAsFixed(2)} TL',
                          style: pw.TextStyle(font: boldFont, fontSize: 20),
                        ),
                        pw.Text(
                          'Durum: $balanceText',
                          style: pw.TextStyle(font: boldFont, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Hareketler Tablosu
              pw.Text(
                'Hesap Hareketleri:',
                style: pw.TextStyle(font: boldFont, fontSize: 14),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                context: context,
                data: tableData,
                headerStyle: pw.TextStyle(
                  font: boldFont,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellStyle: pw.TextStyle(font: font, fontSize: 10),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                },
              ),

              pw.Spacer(),

              // Alt Bilgi (Footer)
              pw.Divider(color: PdfColors.grey300),
              pw.Center(
                child: pw.Text(
                  'Bu belge HesapTakip sistemi üzerinden otomatik oluşturulmuştur.',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    // PDF'i paylaşıma / indirmeye aç
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Ekstre_${clientName.replaceAll(' ', '_')}.pdf',
    );
  }
}
