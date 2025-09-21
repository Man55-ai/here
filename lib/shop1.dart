import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Supabase
  await Supabase.initialize(
    url: 'https://trwfoehtemmlqphslhug.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRyd2ZvZWh0ZW1tbHFwaHNsaHVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwODM3MDAsImV4cCI6MjA3MjY1OTcwMH0.vIhXBOVJeIEP3DtKYpa91-vJjz5NodIlu9K4vAGVikU',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sales App',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const SalesRecordPage(),
    );
  }
}

class SalesRecordPage extends StatefulWidget {
  const SalesRecordPage({super.key});

  @override
  State<SalesRecordPage> createState() => _SalesRecordPageState();
}

class _SalesRecordPageState extends State<SalesRecordPage> {
  final amountCtrl = TextEditingController();
  List<String> _shopNames = [];
  String? _selectedShop;
  bool _isLoading = true;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadShopNamesFromCsv();
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    super.dispose();
  }

  // ✅ โหลดชื่อร้านจาก CSV
  Future<void> _loadShopNamesFromCsv() async {
    try {
      final rawData = await rootBundle.loadString('assets/S11_clean.csv');
      final List<List<dynamic>> csvTable = const CsvToListConverter(
        eol: '\n',
      ).convert(rawData);

      final Set<String> uniqueShopNames = {};
      if (csvTable.length > 5) {
        for (int i = 5; i < csvTable.length; i++) {
          final row = csvTable[i];
          if (row.isNotEmpty && row[0] is String && row[0].isNotEmpty) {
            uniqueShopNames.add(row[0] as String);
          }
        }
      }

      setState(() {
        // ✅ เพิ่ม "ร้านค้าทั่วไป" ไว้ด้านบนสุด
        _shopNames = ['ร้านค้าทั่วไป', ...uniqueShopNames.toList()];
        _selectedShop = _shopNames.isNotEmpty ? _shopNames.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _shopNames = ['ข้อผิดพลาดในการโหลดข้อมูล'];
        _selectedShop = 'ข้อผิดพลาดในการโหลดข้อมูล';
      });
      print('ข้อผิดพลาดในการโหลด CSV: $e');
    }
  }

  // ✅ บันทึกยอดขายไป Supabase
  Future<void> _saveSalesData() async {
    if (_selectedShop == null ||
        amountCtrl.text.isEmpty ||
        _selectedShop == 'ข้อผิดพลาดในการโหลดข้อมูล') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('โปรดเลือกร้านค้าและใส่ยอดเงินให้ถูกต้อง'),
        ),
      );
      return;
    }

    final double? amount = double.tryParse(amountCtrl.text);
    if (amount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('โปรดใส่ยอดเงินเป็นตัวเลข')));
      return;
    }

    try {
      final response =
          await supabase.from('sales').insert({
            'shop_name': _selectedShop,
            'amount': amount,
            'time': DateTime.now().toIso8601String(),
          }).select(); // ✅ select() เพื่อให้ response ไม่ว่าง

      if (response.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกยอดขายสำหรับ $_selectedShop สำเร็จ!')),
        );

        // ✅ รีเซ็ตยอดเงินหลังบันทึกเสร็จ
        amountCtrl.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึกข้อมูล')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("บันทึกยอดขาย"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "เลือกร้านค้า",
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedShop,
                      items:
                          _shopNames.map((shop) {
                            return DropdownMenuItem<String>(
                              value: shop,
                              child: Text(shop),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedShop = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(
                        labelText: "ยอดเงิน",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saveSalesData,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text("บันทึก"),
                    ),
                  ],
                ),
      ),
    );
  }
}
