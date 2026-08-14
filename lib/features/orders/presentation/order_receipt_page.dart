import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/order_models.dart';
import 'order_ui.dart';
import '../../payments/domain/payment_models.dart';

/// Modern FoodCircle order receipt page with PDF download support.
class OrderReceiptPage extends StatelessWidget {
  const OrderReceiptPage({required this.order, super.key});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Receipt'),
        actions: [
          IconButton(
            key: const Key('receipt-download-pdf'),
            tooltip: 'Download PDF',
            onPressed: () => _downloadPdf(context),
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
            key: const Key('receipt-share-pdf'),
            tooltip: 'Share / Print',
            onPressed: () => _printPdf(context),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _ReceiptCard(order: order),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final document = _buildPdfDocument();
      await Printing.sharePdf(
        bytes: await document.save(),
        filename: 'FoodCircle-receipt-${_shortId(order.id)}.pdf',
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate PDF. Try again.')),
        );
      }
    }
  }

  Future<void> _printPdf(BuildContext context) async {
    try {
      final document = _buildPdfDocument();
      await Printing.layoutPdf(
        onLayout: (_) => document.save(),
        name: 'FoodCircle-receipt-${_shortId(order.id)}',
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open print dialog.')),
        );
      }
    }
  }

  pw.Document _buildPdfDocument() {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context ctx) => _buildPdfReceipt(ctx),
      ),
    );
    return document;
  }

  pw.Widget _buildPdfReceipt(pw.Context ctx) {
    final primaryColor = PdfColor.fromHex('#4F46E5');
    final surfaceColor = PdfColor.fromHex('#F5F5F5');
    final textColor = PdfColor.fromHex('#1C1B1F');
    final mutedColor = PdfColor.fromHex('#6E6E73');

    final totalLabel = 'Total';
    final total = 'BDT ${order.finalPrice.toStringAsFixed(2)}';
    final methodLabel = paymentMethodLabel(order.payment.method);
    final statusStr = paymentStatusLabel(
      order.payment.method,
      order.payment.status,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header branding
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: pw.BoxDecoration(
            color: primaryColor,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'FoodCircle',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Official Order Receipt',
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: PdfColor.fromHex('#C7C4FF'),
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'DELIVERED',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#4ADE80'),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    orderTime(order.createdAt),
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColor.fromHex('#C7C4FF'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 20),

        // Order info block
        pw.Container(
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(
            color: surfaceColor,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfSectionLabel('ORDER INFORMATION', mutedColor),
              pw.SizedBox(height: 10),
              _pdfInfoRow(
                'Order ID',
                '#${_shortId(order.id)}',
                textColor,
                mutedColor,
              ),
              _pdfInfoRow('Kitchen', order.kitchenName, textColor, mutedColor),
              _pdfInfoRow(
                'Delivery Address',
                order.deliveryAddress,
                textColor,
                mutedColor,
              ),
              _pdfInfoRow(
                'Order Date',
                _formatDateTime(order.createdAt),
                textColor,
                mutedColor,
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 14),

        // Item breakdown
        pw.Container(
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(
            color: surfaceColor,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfSectionLabel('ORDER ITEMS', mutedColor),
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColor.fromHex('#E0E0E0'), thickness: 0.5),
              pw.SizedBox(height: 8),
              // Header row
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'Item',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        color: mutedColor,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: 60,
                    child: pw.Text(
                      'Qty',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        color: mutedColor,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: 70,
                    child: pw.Text(
                      'Unit',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        color: mutedColor,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: 80,
                    child: pw.Text(
                      'Total',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        color: mutedColor,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(color: PdfColor.fromHex('#E0E0E0'), thickness: 0.5),
              pw.SizedBox(height: 8),
              // Item row
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      order.itemName,
                      style: pw.TextStyle(fontSize: 11, color: textColor),
                    ),
                  ),
                  pw.SizedBox(
                    width: 60,
                    child: pw.Text(
                      '${order.quantity}',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: 11, color: textColor),
                    ),
                  ),
                  pw.SizedBox(
                    width: 70,
                    child: pw.Text(
                      'BDT ${order.itemPrice.toStringAsFixed(2)}',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 11, color: textColor),
                    ),
                  ),
                  pw.SizedBox(
                    width: 80,
                    child: pw.Text(
                      'BDT ${order.finalPrice.toStringAsFixed(2)}',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColor.fromHex('#C0C0C0'), thickness: 0.8),
              pw.SizedBox(height: 8),
              // Total row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    '$totalLabel: ',
                    style: pw.TextStyle(
                      fontSize: 13,
                      color: mutedColor,
                    ),
                  ),
                  pw.Text(
                    total,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 14),

        // Payment info
        pw.Container(
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(
            color: surfaceColor,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _pdfSectionLabel('PAYMENT DETAILS', mutedColor),
              pw.SizedBox(height: 10),
              _pdfInfoRow(
                'Payment Method',
                methodLabel,
                textColor,
                mutedColor,
              ),
              _pdfInfoRow(
                'Payment Status',
                statusStr,
                textColor,
                mutedColor,
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 24),

        // Footer
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                'Thank you for ordering with FoodCircle!',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'This is a computer-generated receipt and does not require a signature.',
                style: pw.TextStyle(fontSize: 9, color: mutedColor),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfSectionLabel(String label, PdfColor color) => pw.Text(
    label,
    style: pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: color,
      letterSpacing: 1.2,
    ),
  );

  pw.Widget _pdfInfoRow(
    String label,
    String value,
    PdfColor textColor,
    PdfColor mutedColor,
  ) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: mutedColor),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, color: textColor),
          ),
        ),
      ],
    ),
  );
}

String _shortId(String orderId) =>
    (orderId.length <= 8 ? orderId : orderId.substring(orderId.length - 8))
        .toUpperCase();

String _formatDateTime(DateTime dt) {
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = dt.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]} ${local.year}, $hour:$minute';
}

String paymentMethodLabel(PaymentMethod method) => switch (method) {
  PaymentMethod.bkash => 'bKash',
  PaymentMethod.cashOnDelivery => 'Cash on Delivery',
  PaymentMethod.demoWallet => 'Demo Wallet',
};

// ── In-app receipt widget ──────────────────────────────────────────────────

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      key: const Key('receipt-card'),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'FoodCircle',
                      style: textTheme.headlineSmall?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade400.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.shade400,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '✓ DELIVERED',
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.green.shade300,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Official Order Receipt',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: .75),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _formatDateTime(order.createdAt),
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: .85),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order ID
                _Section(
                  label: 'ORDER DETAILS',
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'Order ID',
                        value: '#${_shortId(order.id)}',
                        bold: true,
                      ),
                      _DetailRow(label: 'Kitchen', value: order.kitchenName),
                      _DetailRow(
                        label: 'Delivery To',
                        value: order.deliveryAddress,
                      ),
                    ],
                  ),
                ),

                const Divider(height: 28),

                // Item breakdown
                _Section(
                  label: 'ITEMS',
                  child: Column(
                    children: [
                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Item',
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Text(
                            'Qty',
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 70,
                            child: Text(
                              'Subtotal',
                              textAlign: TextAlign.right,
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.itemName,
                              style: textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            '×${order.quantity}',
                            style: textTheme.bodyMedium,
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 70,
                            child: Text(
                              orderCurrency(order.finalPrice),
                              textAlign: TextAlign.right,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (order.quantity > 1) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Unit price: ${orderCurrency(order.itemPrice)}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const Divider(height: 20),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      orderCurrency(order.finalPrice),
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),

                const Divider(height: 28),

                // Payment details
                _Section(
                  label: 'PAYMENT',
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'Method',
                        value: paymentMethodLabel(order.payment.method),
                      ),
                      _DetailRow(
                        label: 'Status',
                        value: paymentStatusLabel(
                          order.payment.method,
                          order.payment.status,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Footer message
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        color: scheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Thank you for ordering with FoodCircle! We hope you enjoyed your meal.',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
      const SizedBox(height: 10),
      child,
    ],
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ],
    ),
  );
}
