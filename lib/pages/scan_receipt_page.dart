import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_localizations.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';
import '../services/receipt_ocr_service.dart';

/// Mapping from Gemini's high-level category strings to our [defaultCategories]
/// IDs (which are slightly different — e.g. "food" -> "groceries").
const Map<String, String> _aiToCategoryId = {
  'food': 'groceries',
  'transport': 'transport',
  'shopping': 'shopping',
  'entertainment': 'entertainment',
  'bills': 'utilities',
  'healthcare': 'healthcare',
  'education': 'education',
  'travel': 'other',
  'other': 'other',
};

String _resolveCategoryId(String aiCategory) {
  return _aiToCategoryId[aiCategory.toLowerCase()] ?? 'other';
}

class _EditableLine {
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  String categoryId;
  bool include;

  _EditableLine({
    required this.nameCtrl,
    required this.amountCtrl,
    required this.categoryId,
  }) : include = true;

  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
  }
}

class ScanReceiptPage extends StatefulWidget {
  const ScanReceiptPage({super.key});

  @override
  State<ScanReceiptPage> createState() => _ScanReceiptPageState();
}

class _ScanReceiptPageState extends State<ScanReceiptPage> {
  static const _teal = Color(0xFF0F766E);

  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _scanning = false;
  bool _saving = false;
  String? _error;
  ReceiptScanResult? _result;

  final TextEditingController _merchantCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _currency = 'KZT';
  final List<_EditableLine> _lines = [];

  @override
  void dispose() {
    _merchantCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (image == null) return;
      setState(() {
        _imageFile = File(image.path);
        _result = null;
        _error = null;
        for (final l in _lines) {
          l.dispose();
        }
        _lines.clear();
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _scan() async {
    final file = _imageFile;
    if (file == null) return;
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      // Read context-dependent values BEFORE await to avoid async-gap warning.
      final keyMissingMsg = context.t('aiKeyMissing');
      final defaultCurrency = context.appCurrency.code;

      final available = await ReceiptOcrService.isAvailable();
      if (!available) {
        if (!mounted) return;
        setState(() {
          _scanning = false;
          _error = keyMissingMsg;
        });
        return;
      }
      final result = await ReceiptOcrService.scan(
        file,
        defaultCurrency: defaultCurrency,
      );

      // Populate editable form
      _merchantCtrl.text = result.merchant ?? '';
      _date = result.date ?? DateTime.now();
      _currency = result.currency;
      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();
      for (final item in result.items) {
        _lines.add(_EditableLine(
          nameCtrl: TextEditingController(text: item.name),
          amountCtrl:
              TextEditingController(text: item.amount.toStringAsFixed(2)),
          categoryId: _resolveCategoryId(item.suggestedCategory),
        ));
      }

      // If Gemini gave a total but no items, create a single fallback line.
      if (_lines.isEmpty && result.total > 0) {
        _lines.add(_EditableLine(
          nameCtrl:
              TextEditingController(text: result.merchant ?? 'Receipt total'),
          amountCtrl: TextEditingController(text: result.total.toStringAsFixed(2)),
          categoryId: 'other',
        ));
      }

      if (!mounted) return;
      setState(() {
        _result = result;
        _scanning = false;
      });
    } on ReceiptOcrException catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = '$e';
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _saveAll() async {
    final included = _lines.where((l) => l.include).toList();
    if (included.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('selectAtLeastOne'))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final uuid = const Uuid();
      for (final line in included) {
        final amount = double.tryParse(
                line.amountCtrl.text.trim().replaceAll(',', '.')) ??
            0.0;
        if (amount <= 0) continue;
        final tx = TransactionModel(
          id: uuid.v4(),
          title: line.nameCtrl.text.trim().isEmpty
              ? (_merchantCtrl.text.trim().isEmpty
                  ? 'Receipt'
                  : _merchantCtrl.text.trim())
              : line.nameCtrl.text.trim(),
          amount: amount,
          date: _date,
          type: TransactionType.expense,
          categoryId: line.categoryId,
          notes: _merchantCtrl.text.trim().isEmpty
              ? 'Scanned receipt'
              : 'Scanned: ${_merchantCtrl.text.trim()}',
          source: TransactionSource.import,
          currency: _currency,
          receiptImagePath: _imageFile?.path,
        );
        await FirestoreService.addTransaction(tx);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tx('savedNTransactions',
              {'count': included.length.toString()})),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text(context.t('scanReceipt')),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImagePicker(),
              const SizedBox(height: 16),
              if (_imageFile != null && _result == null && !_scanning)
                ElevatedButton.icon(
                  onPressed: _scan,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(context.t('analyzeWithAI')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              if (_scanning) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(context.t('analyzingReceipt'),
                    textAlign: TextAlign.center),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Color(0xFFB91C1C)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style:
                                const TextStyle(color: Color(0xFFB91C1C)))),
                  ]),
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 24),
                _buildResultEditor(),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _result == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveAll,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(context.tx('saveNTransactions', {
                    'count':
                        _lines.where((l) => l.include).length.toString()
                  })),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildImagePicker() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (_imageFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_imageFile!,
                  height: 220, fit: BoxFit.cover, width: double.infinity),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(context.t('chooseReceiptSource')),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: Text(context.t('camera')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: Text(context.t('gallery')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultEditor() {
    final result = _result!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF0F766E)),
              const SizedBox(width: 8),
              Text(context.t('extractedData'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16)),
              const Spacer(),
              _ConfidencePill(level: result.confidence),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _merchantCtrl,
            decoration: InputDecoration(
              labelText: context.t('merchant'),
              prefixIcon: const Icon(Icons.store),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: context.t('date'),
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: const OutlineInputBorder(),
                    ),
                    child: Text(DateFormat.yMMMd().format(_date)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.t('currency'),
                    border: const OutlineInputBorder(),
                  ),
                  child: Text(_currency,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                context.tx('lineItemsN',
                    {'count': _lines.length.toString()}),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              Text(
                '${context.t('total')}: ${_formattedTotal()} $_currency',
                style: const TextStyle(
                    color: Color(0xFF0F766E), fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._lines.asMap().entries.map((entry) => _buildLineRow(entry.key)),
          if (_lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(context.t('noItemsExtracted'),
                  textAlign: TextAlign.center),
            ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _lines.add(_EditableLine(
                  nameCtrl: TextEditingController(),
                  amountCtrl: TextEditingController(text: '0'),
                  categoryId: 'other',
                ));
              });
            },
            icon: const Icon(Icons.add),
            label: Text(context.t('addItem')),
          ),
        ],
      ),
    );
  }

  String _formattedTotal() {
    double sum = 0;
    for (final l in _lines.where((l) => l.include)) {
      sum += double.tryParse(l.amountCtrl.text.replaceAll(',', '.')) ?? 0;
    }
    return sum.toStringAsFixed(2);
  }

  Widget _buildLineRow(int index) {
    final line = _lines[index];
    final expenseCats =
        defaultCategories.where((c) => c.type == TransactionType.expense).toList();
    final selectedCat = expenseCats.firstWhere(
      (c) => c.id == line.categoryId,
      orElse: () => expenseCats.last,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: line.include ? const Color(0xFFF8FAFA) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: line.include,
                  onChanged: (v) =>
                      setState(() => line.include = v ?? true),
                ),
                Expanded(
                  child: TextField(
                    controller: line.nameCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Item',
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: line.amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFB91C1C)),
                  tooltip: context.t('delete'),
                  onPressed: () {
                    setState(() {
                      _lines[index].dispose();
                      _lines.removeAt(index);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(selectedCat.icon, size: 18, color: selectedCat.color),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: line.categoryId,
                    underline: const SizedBox.shrink(),
                    items: expenseCats
                        .map((c) => DropdownMenuItem<String>(
                              value: c.id,
                              child: Row(children: [
                                Icon(c.icon, size: 18, color: c.color),
                                const SizedBox(width: 8),
                                Text(context.categoryName(c.id)),
                              ]),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => line.categoryId = v);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidencePill extends StatelessWidget {
  final String level;
  const _ConfidencePill({required this.level});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (level.toLowerCase()) {
      case 'high':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        break;
      case 'medium':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        break;
      default:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        level.toUpperCase(),
        style: TextStyle(
            color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}
