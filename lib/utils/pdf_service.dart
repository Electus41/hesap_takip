import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> generateAndShareEkstre({
    required String companyName,
    required Map<String, dynamic> client,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final pdf = pw.Document();

    // Türkçe karakterlerin (ş, ğ, ı vb.) PDF'te bozulmaması için Google Fonts kullanıyoruz
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    // Toplam borcu hesapla
    double totalDebt = 0;
    for (var t in transactions) {
      if (t['is_paid'] == false) {
        totalDebt += double.tryParse(t['amount'].toString()) ?? 0.0;
      }
    }

    // PDF Sayfasını Çiz
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ÜST BİLGİ (HEADER)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 24,
                          color: PdfColors.cyan700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Mali Musavirlik & Muhasebe Ofisi',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    'HESAP EKSTRESI',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 20,
                      color: PdfColors.grey800,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // MÜKELLEF BİLGİLERİ
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
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'MUKELLEF BILGILERI',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Unvan: ${client['title'] ?? '-'}',
                      style: pw.TextStyle(font: boldFont, fontSize: 14),
                    ),
                    pw.Text(
                      'Yetkili Kisi: ${client['contact_name'] ?? '-'}',
                      style: pw.TextStyle(font: font, fontSize: 12),
                    ),
                    pw.Text(
                      'Tarih: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
                      style: pw.TextStyle(font: font, fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // HESAP HAREKETLERİ TABLOSU
              pw.Text(
                'Hesap Hareketleri & Tahakkuklar',
                style: pw.TextStyle(font: boldFont, fontSize: 14),
              ),
              pw.SizedBox(height: 10),

              // SORUN YARATAN SATIR RENKLERİ KALDIRILDI - SADE VE GARANTİ YÖNTEM
              pw.TableHelper.fromTextArray(
                context: context,
                cellStyle: pw.TextStyle(font: font, fontSize: 10),
                headerStyle: pw.TextStyle(
                  font: boldFont,
                  fontSize: 10,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                data: <List<String>>[
                  ['Tarih', 'Aciklama', 'Durum', 'Tutar'],
                  ...transactions.map((t) {
                    final date = t['created_at'] != null
                        ? DateFormat(
                            'dd.MM.yyyy',
                          ).format(DateTime.parse(t['created_at']))
                        : '-';
                    final desc = t['description'] ?? '-';
                    final isPaid = t['is_paid'] == true;
                    final amount = currencyFormat.format(
                      double.tryParse(t['amount'].toString()) ?? 0,
                    );
                    return [date, desc, isPaid ? 'Odendi' : 'Odenmedi', amount];
                  }),
                ],
              ),
              pw.SizedBox(height: 30),

              // TOPLAM BORÇ (KIRMIZI VE BÜYÜK)
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'TOPLAM BEKLEYEN BORC',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      currencyFormat.format(totalDebt),
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 24,
                        color: PdfColors.red700,
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  'Bu belge $companyName tarafindan HesapTakip sistemi uzerinden otomatik olusturulmustur.',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 9,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    // PDF'i oluştur ve paylaş/indir
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Ekstre_${client['title'].toString().replaceAll(' ', '_')}.pdf',
    );
  }
}
