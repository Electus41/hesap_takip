import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ClientDetailScreen extends StatefulWidget {
  final Map<String, dynamic> client;
  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    try {
      final res = await supabase
          .from('transactions')
          .select()
          .eq('client_id', widget.client['id'])
          .order('created_at', ascending: false);
      if (mounted)
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // PDF OLUŞTURMA VE YAZDIRMA / PAYLAŞMA
  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    final tableHeaders = [
      'Tarih',
      'Aciklama',
      'Toplam Borc',
      'Odenen',
      'Kalan',
    ];
    final tableData = _transactions.map((t) {
      final total = double.tryParse(t['amount'].toString()) ?? 0.0;
      final paid = double.tryParse(t['paid_amount']?.toString() ?? '0') ?? 0.0;
      final date = t['created_at'] != null
          ? DateFormat('dd.MM.yyyy').format(DateTime.parse(t['created_at']))
          : '-';
      return [
        date,
        t['description'] ?? '',
        formatter.format(total),
        formatter.format(paid),
        formatter.format(total - paid),
      ];
    }).toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'MUKELLEF CARI EKSTRESI',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Firma: ${widget.client['title']}'),
              pw.Text('Vergi No: ${widget.client['tax_number'] ?? '-'}'),
              pw.Text(
                'Tarih: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
              ),
              pw.SizedBox(height: 30),
              pw.TableHelper.fromTextArray(
                headers: tableHeaders,
                data: tableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
              ),
            ],
          );
        },
      ),
    );

    // Ekranda PDF önizlemesi ve Paylaş/Yazdır seçenekleri çıkarır
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${widget.client['title']}_Ekstre.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
    );

    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161A),
        title: Text(
          widget.client['title'],
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
            onPressed: _generatePdf,
            tooltip: 'Cari Ekstre (PDF) Al',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00ACC1)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: _transactions.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white12),
              itemBuilder: (context, index) {
                final t = _transactions[index];
                final total = double.tryParse(t['amount'].toString()) ?? 0.0;
                final paid =
                    double.tryParse(t['paid_amount']?.toString() ?? '0') ?? 0.0;
                final remaining = total - paid;
                final isFullyPaid = t['is_paid'] as bool? ?? false;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isFullyPaid
                        ? Colors.greenAccent.withValues(alpha: 0.1)
                        : Colors.orangeAccent.withValues(alpha: 0.1),
                    child: Icon(
                      isFullyPaid ? Icons.check : Icons.schedule,
                      color: isFullyPaid
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                  ),
                  title: Text(
                    t['description'] ?? 'İşlem',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Ödenen: ${currencyFormatter.format(paid)} | Kalan: ${currencyFormatter.format(remaining)}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  trailing: Text(
                    currencyFormatter.format(total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
