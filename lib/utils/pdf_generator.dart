import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

Future<File> generatePdf(List<Map<String, dynamic>> billItems, double total,
    double packingCost, double previousBalance, String invoiceFor) async {
  final pdf = pw.Document();
  final finalTotal = total + packingCost;

  pdf.addPage(
    pw.MultiPage(
      margin: const pw.EdgeInsets.all(40),
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        // Header
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                'TASCO',
                style: pw.TextStyle(
                  fontSize: 19,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Estimate Bill',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            'Billed To: $invoiceFor',
            style: const pw.TextStyle(fontSize: 12),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            'Invoice Date: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
            style: const pw.TextStyle(fontSize: 12),
          ),
        ),
        pw.SizedBox(height: 12),

        // Table (will span pages as needed)
        pw.Table(
          border: pw.TableBorder.all(width: 1),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.8),
            3: const pw.FlexColumnWidth(1.8),
          },
          children: [
            // Header Row
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFE0E0E0),
              ),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Center(
                    child: pw.Text(
                      'Item',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Center(
                    child: pw.Text(
                      'Qty',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Center(
                    child: pw.Text(
                      'Price',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Center(
                    child: pw.Text(
                      'Total',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Data Rows
            ...billItems.map((item) {
              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      item['name'].toString(),
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Center(
                      child: pw.Text(
                        (item['qty'] as num).toDouble().toString(),
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Center(
                      child: pw.Text(
                        'Rs. ${double.parse(item['price'].toString()).toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Center(
                      child: pw.Text(
                        'Rs. ${double.parse(item['total'].toString()).toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 16),

        // Total Section
        pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Subtotal: Rs. ${total.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 13,
                ),
              ),
              if (packingCost > 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(
                    'Packing Cost: Rs. ${packingCost.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 13,
                    ),
                  ),
                ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8),
                child: pw.Text(
                  'Grand Total: Rs. ${finalTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if (previousBalance > 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Text(
                    'Previous Balance: Rs. ${previousBalance.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 13,
                    ),
                  ),
                ),
              if (previousBalance > 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Text(
                    'Final Due: Rs. ${(finalTotal + previousBalance).toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}'),
      ),
    ),
  );

  final dir = await getApplicationDocumentsDirectory();
  final file =
      File('${dir.path}/invoice_${DateTime.now().millisecondsSinceEpoch}.pdf');
  await file.writeAsBytes(await pdf.save());

  return file;
}
