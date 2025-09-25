import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://trwfoehtemmlqphslhug.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRyd2ZvZWh0ZW1tbHFwaHNsaHVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwODM3MDAsImV4cCI6MjA3MjY1OTcwMH0.vIhXBOVJeIEP3DtKYpa91-vJjz5NodIlu9K4vAGVikU',
  );
  await initializeDateFormatting('th_TH');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // เพิ่มบรรทัดนี้
      title: 'Ice Sales App',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 3,
        ),
      ),
      home: const RootPage(),
    );
  }
}

// ---------- Root Page ----------
class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _name;
  String? _phone;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('user_name');
      _phone = prefs.getString('user_phone');
      _isLoggedIn = _name != null && _phone != null;
      _isLoading = false;
    });
  }

  Future<void> _saveLogin(String name, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_phone', phone);
    setState(() {
      _name = name;
      _phone = phone;
      _isLoggedIn = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return _isLoggedIn
        ? MainPage(
            userName: _name!,
            userPhone: _phone!,
            onLogout: () {
              setState(() {
                _isLoggedIn = false;
                _name = null;
                _phone = null;
              });
            },
          )
        : LoginPage(onLogin: _saveLogin);
  }
}

// ---------- Login Page ----------
class LoginPage extends StatefulWidget {
  final Function(String, String) onLogin;
  const LoginPage({super.key, required this.onLogin});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    String name = nameCtrl.text.trim();
    String phone = phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('โปรดกรอกชื่อ-นามสกุลและเบอร์โทร')),
      );
      return;
    }
    widget.onLogin(name, phone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: "ชื่อ-นามสกุล",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: "เบอร์โทร",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submit,
              child: const Text("เข้าสู่ระบบ"),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Main Page ----------
class MainPage extends StatefulWidget {
  final String userName;
  final String userPhone;
  final VoidCallback onLogout;
  const MainPage({
    super.key,
    required this.userName,
    required this.userPhone,
    required this.onLogout,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      SalesRecordPage(userName: widget.userName, userPhone: widget.userPhone),
      const SalesReportPage(),
      const NoPurchasePage(),
      const YearlyStatsPage(),
      ProfilePage(
        userName: widget.userName,
        userPhone: widget.userPhone,
        onLogout: widget.onLogout,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green.shade700,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "บันทึก"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "รายงาน"),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: "ไม่ซื้อ"),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: "ปี"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "โปรไฟล์"),
        ],
      ),
    );
  }
}

// ---------- Sales Record Page ----------
class SalesRecordPage extends StatefulWidget {
  final String userName;
  final String userPhone;
  const SalesRecordPage({
    super.key,
    required this.userName,
    required this.userPhone,
  });
  @override
  State<SalesRecordPage> createState() => _SalesRecordPageState();
}

class _SalesRecordPageState extends State<SalesRecordPage> {
  final amountCtrl = TextEditingController();
  final reasonCtrl = TextEditingController();
  List<String> _shopNames = [];
  String? _selectedShop;
  bool _isLoading = true;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _loadShopNamesFromCsv();
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadShopNamesFromCsv() async {
    try {
      final rawData = await rootBundle.loadString('assets/S11_clean.csv');
      final csvTable = const CsvToListConverter(eol: '\n').convert(rawData);
      final shopSet = <String>{};
      for (var row in csvTable.skip(5)) {
        if (row.isNotEmpty && row[0] is String && row[0].isNotEmpty)
          shopSet.add(row[0] as String);
      }
      setState(() {
        _shopNames = ['ร้านค้าทั่วไป', ...shopSet.toList()];
        _selectedShop = _shopNames.first;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _shopNames = ['ข้อผิดพลาดในการโหลดข้อมูล'];
        _selectedShop = _shopNames.first;
        _isLoading = false;
      });
      print('CSV load error: $e');
    }
  }

  Future<void> _saveSalesData() async {
    if (_selectedShop == null ||
        _selectedShop == 'ข้อผิดพลาดในการโหลดข้อมูล' ||
        amountCtrl.text.isEmpty) {
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
      final inserted = await Supabase.instance.client.from('sales').insert({
        "shop_name": _selectedShop,
        "amount": amount,
        "time": DateTime.now().toIso8601String(),
        "user_name": widget.userName,
        "user_phone": widget.userPhone,
      }).select() as List;
      if (inserted.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกยอดขายสำหรับ $_selectedShop สำเร็จ!')),
        );
        amountCtrl.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _saveNoPurchase() async {
    if (_selectedShop == null || reasonCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('โปรดใส่เหตุผลและเลือกร้านค้า')),
      );
      return;
    }
    String? imageUrl;
    if (_pickedImage != null) {
      final fileName =
          'public/${DateTime.now().millisecondsSinceEpoch}_${widget.userPhone}.jpg';
      try {
        await Supabase.instance.client.storage
            .from('images')
            .upload(fileName, _pickedImage!);
        imageUrl = Supabase.instance.client.storage
            .from('images')
            .getPublicUrl(fileName);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการอัปโหลดไฟล์: $e')),
        );
        return;
      }
    }
    try {
      await Supabase.instance.client.from('no_purchase').insert({
        "shop_name": _selectedShop,
        "reason": reasonCtrl.text,
        "image_url": imageUrl,
        "user_name": widget.userName,
        "user_phone": widget.userPhone,
        "time": DateTime.now().toIso8601String(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกเหตุผลสำหรับ $_selectedShop สำเร็จ!')),
      );
      reasonCtrl.clear();
      setState(() => _pickedImage = null);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("บันทึกยอดขาย")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "เลือกร้านค้า",
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedShop,
                      items: _shopNames
                          .map(
                            (shop) => DropdownMenuItem(
                              value: shop,
                              child: Text(shop),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedShop = v),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountCtrl,
                      style: const TextStyle(color: Colors.green),
                      decoration: const InputDecoration(
                        labelText: "ยอดขาย",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saveSalesData,
                      child: const Text("บันทึกยอดขาย"),
                    ),
                    const Divider(height: 32),
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: "เหตุผล (ถ้าไม่ซื้อ)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_pickedImage != null)
                      Image.file(_pickedImage!, height: 120),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _pickImage,
                          child: const Text("ถ่ายรูป"),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _saveNoPurchase,
                          child: const Text("ร้านนี้ไม่ซื้อ"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ---------- Sales Report Page ----------
class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});
  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // REMOVE this line:
  // bool _showSummary = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.from('sales').select() as List;
      setState(() {
        _data = res.map((e) => e as Map<String, dynamic>).toList();
      });
    } catch (e) {
      print("Error fetching data: $e");
    }
    setState(() => _isLoading = false);
  }

  double _calculateDailyTotal(DateTime day) {
    return _data.fold(0.0, (sum, row) {
      DateTime? time =
          row['time'] != null ? DateTime.tryParse(row['time']) : null;
      if (time != null &&
          time.year == day.year &&
          time.month == day.month &&
          time.day == day.day) return sum + (row['amount']?.toDouble() ?? 0);
      return sum;
    });
  }

  double _calculateMonthlyTotal(DateTime month) {
    return _data.fold(0.0, (sum, row) {
      DateTime? time =
          row['time'] != null ? DateTime.tryParse(row['time']) : null;
      if (time != null && time.year == month.year && time.month == month.month)
        return sum + (row['amount']?.toDouble() ?? 0);
      return sum;
    });
  }

  // ---------- แก้ไขส่วนนี้ ----------
  List<Map<String, dynamic>> _filteredData() {
    if (_selectedDay == null) return [];

    final filteredList = _data.where((row) {
      DateTime? time =
          row['time'] != null ? DateTime.tryParse(row['time']) : null;
      return time != null &&
          time.year == _selectedDay!.year &&
          time.month == _selectedDay!.month &&
          time.day == _selectedDay!.day;
    }).toList();

    // เรียงลำดับจากใหม่ไปเก่า (เวลาล่าสุดอยู่บนสุด)
    filteredList.sort((a, b) {
      final timeA = DateTime.tryParse(a['time'] ?? '');
      final timeB = DateTime.tryParse(b['time'] ?? '');
      if (timeA == null || timeB == null) return 0;
      return timeB.compareTo(timeA);
    });

    return filteredList;
  }
  // ---------- สิ้นสุดส่วนที่แก้ไข ----------

  void _showSummary() {
    final double dailyTotal =
        _selectedDay != null ? _calculateDailyTotal(_selectedDay!) : 0.0;
    final double monthlyTotal = _calculateMonthlyTotal(_focusedDay);

    final String dailyText = _selectedDay != null
        ? "ยอดรวมวันที่ ${DateFormat('d MMMM yyyy', 'th_TH').format(_selectedDay!)}: ${NumberFormat("#,###").format(dailyTotal)} บาท"
        : "";
    final String monthlyText =
        "ยอดรวมเดือน ${DateFormat('MMMM yyyy', 'th_TH').format(_focusedDay)}: ${NumberFormat("#,###").format(monthlyTotal)} บาท";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("สรุปยอดรวม"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedDay != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(dailyText),
              ),
            Text(monthlyText),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ปิด"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredData = _filteredData();
    return Scaffold(
      appBar: AppBar(title: const Text("รายงานรายได้")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TableCalendar(
                  focusedDay: _focusedDay,
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) => setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  }),
                  onPageChanged: (focusedDay) =>
                      setState(() => _focusedDay = focusedDay),
                  calendarFormat: CalendarFormat.month,
                  locale: 'th_TH',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _showSummary,
                        child: const Text("สรุปยอด"),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredData.length,
                    itemBuilder: (_, index) {
                      final row = filteredData[index];
                      final userName = row['user_name'] ?? '-';
                      final phone = row['user_phone'] ?? '-';
                      // ---------- แก้ไขส่วนนี้ ----------
                      final time = row['time'] != null
                          ? DateTime.tryParse(row['time'])
                          : null;
                      final formattedDate = time != null
                          ? DateFormat(
                              'dd/MM/yyyy HH:mm',
                              'th_TH',
                            ).format(time)
                          : '-';
                      // ---------- สิ้นสุดส่วนที่แก้ไข ----------
                      return ListTile(
                        title: Text(row['shop_name'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ยอด: ${row['amount'] ?? 0}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // ---------- เพิ่มบรรทัดนี้ ----------
                            Text('วันที่และเวลา: $formattedDate'),
                            // ---------- สิ้นสุดการเพิ่ม ----------
                            Text('บันทึกโดย: $userName'),
                            Text('เบอร์โทร: $phone'),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ---------- No Purchase Page ----------
class NoPurchasePage extends StatefulWidget {
  const NoPurchasePage({super.key});

  @override
  State<NoPurchasePage> createState() => _NoPurchasePageState();
}

class _NoPurchasePageState extends State<NoPurchasePage> {
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('no_purchase')
          .select()
          .order('time', ascending: false) as List;
      setState(() {
        _data = res.map((e) => e as Map<String, dynamic>).toList();
      });
    } catch (e) {
      print("Error fetching no_purchase: $e");
    }
    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get filteredData {
    if (_selectedDay == null) return _data;
    return _data.where((row) {
      DateTime? time =
          row['time'] != null ? DateTime.tryParse(row['time']) : null;
      return time != null &&
          time.year == _selectedDay!.year &&
          time.month == _selectedDay!.month &&
          time.day == _selectedDay!.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ร้านไม่ซื้อ")),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  TableCalendar(
                    focusedDay: _focusedDay,
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) =>
                        setState(() => _focusedDay = focusedDay),
                    locale: 'th_TH',
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => setState(() => _selectedDay = null),
                        child: const Text("รีเซ็ต"),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredData.length,
                      itemBuilder: (context, index) {
                        final row = filteredData[index];
                        final time = row['time'] != null
                            ? DateTime.tryParse(row['time'])
                            : null;
                        return Card(
                          child: ListTile(
                            title: Text(row['shop_name'] ?? '-'),
                            subtitle: Text(
                              "เหตุผล: ${row['reason'] ?? '-'}\nวันที่: ${time != null ? DateFormat('dd/MM/yyyy HH:mm').format(time) : '-'}\nผู้บันทึก: ${row['user_name'] ?? ''} (${row['user_phone'] ?? ''})",
                            ),
                            trailing: row['image_url'] != null
                                ? IconButton(
                                    icon: const Icon(Icons.image),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          content: Image.network(
                                            row['image_url'],
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ---------- YearlyStatsPage ----------
class YearlyStatsPage extends StatefulWidget {
  const YearlyStatsPage({super.key});
  @override
  State<YearlyStatsPage> createState() => _YearlyStatsPageState();
}

class _YearlyStatsPageState extends State<YearlyStatsPage> {
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;
  int _focusedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.from('sales').select() as List;
      setState(() {
        _data = res.map((e) => e as Map<String, dynamic>).toList();
      });
    } catch (e) {
      print("Error fetching: $e");
    }
    setState(() => _isLoading = false);
  }

  double _monthTotal(int month) {
    return _data.fold(0.0, (sum, row) {
      DateTime? time =
          row['time'] != null ? DateTime.tryParse(row['time']) : null;
      if (time != null && time.year == _focusedYear && time.month == month) {
        return sum + (row['amount']?.toDouble() ?? 0);
      }
      return sum;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("สรุปยอดรายปี")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(8),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100000,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, meta) {
                          const monthLabels = [
                            "ม.ค",
                            "ก.พ",
                            "มี.ค",
                            "เม.ย",
                            "พ.ค",
                            "มิ.ย",
                            "ก.ค",
                            "ส.ค",
                            "ก.ย",
                            "ต.ค",
                            "พ.ย",
                            "ธ.ค",
                          ];
                          return Text(monthLabels[value.toInt()]);
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false, // แก้ไขตรงนี้
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(12, (index) {
                    final val = _monthTotal(index + 1);
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(toY: val, color: Colors.green),
                      ],
                    );
                  }),
                ),
              ),
            ),
    );
  }
}

// ---------- Profile Page ----------
class ProfilePage extends StatefulWidget {
  final String userName;
  final String userPhone;
  final VoidCallback onLogout;
  const ProfilePage({
    super.key,
    required this.userName,
    required this.userPhone,
    required this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _imageUrl;
  bool _isUploading = false;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('user_image_url');
    setState(() => _imageUrl = url);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    final imageFile = File(pickedFile.path);

    setState(() => _isUploading = true);
    try {
      final fileName =
          'avatars/${widget.userPhone}.png'; // ใช้เบอร์โทรเป็นชื่อไฟล์
      await _supabase.storage.from('images').upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(upsert: true), // ✅ อนุญาตอัปโหลดทับ
          );
      final publicUrl = _supabase.storage.from('images').getPublicUrl(fileName);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_image_url', publicUrl);
      setState(() => _imageUrl = publicUrl);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการอัปโหลด: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    await prefs.remove('user_phone');
    await prefs.remove('user_image_url');
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("โปรไฟล์")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage:
                        _imageUrl != null ? NetworkImage(_imageUrl!) : null,
                    child: _imageUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.grey,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: _isUploading
                        ? const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.camera_alt, size: 30),
                            onPressed: _pickImage,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                "ชื่อ-นามสกุล: ${widget.userName}",
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                "เบอร์โทร: ${widget.userPhone}",
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: _logout,
                child: const Text("ออกจากระบบ"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
