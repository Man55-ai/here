import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('th_TH', null);
  Intl.defaultLocale = 'th_TH';
  runApp(SalesReportApp());
}

class SalesReportApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'รายงานรายได้',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SalesReportPage(),
    );
  }
}

class SalesReportPage extends StatefulWidget {
  @override
  _SalesReportPageState createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  List<dynamic> _data = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchData();

    // รีเฟรชข้อมูลทุก 10 วินาที
    _timer = Timer.periodic(Duration(seconds: 10), (timer) {
      fetchData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchData() async {
    const url = "https://trwfoehtemmlqphslhug.supabase.co/rest/v1/sales";
    const headers = {
      "apikey":
          "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRyd2ZvZWh0ZW1tbHFwaHNsaHVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwODM3MDAsImV4cCI6MjA3MjY1OTcwMH0.vIhXBOVJeIEP3DtKYpa91-vJjz5NodIlu9K4vAGVikU",
      "Authorization":
          "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRyd2ZvZWh0ZW1tbHFwaHNsaHVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwODM3MDAsImV4cCI6MjA3MjY1OTcwMH0.vIhXBOVJeIEP3DtKYpa91-vJjz5NodIlu9K4vAGVikU",
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        setState(() {
          _data = json.decode(response.body);
        });
      } else {
        print("Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  double calculateDailyTotal(DateTime day) {
    return _data.fold(0.0, (sum, row) {
      DateTime? time =
          row['time'] != null ? DateTime.tryParse(row['time']) : null;
      if (time != null &&
          time.year == day.year &&
          time.month == day.month &&
          time.day == day.day) {
        return sum + (row['amount']?.toDouble() ?? 0.0);
      }
      return sum;
    });
  }

  double calculateMonthlyTotal(DateTime month) {
    return _data.fold(0.0, (sum, row) {
      DateTime? time =
          row['time'] != null ? DateTime.tryParse(row['time']) : null;
      if (time != null &&
          time.year == month.year &&
          time.month == month.month) {
        return sum + (row['amount']?.toDouble() ?? 0.0);
      }
      return sum;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> filteredData = [];
    if (_selectedDay != null) {
      filteredData =
          _data.where((row) {
            DateTime? time =
                row['time'] != null ? DateTime.tryParse(row['time']) : null;
            return time != null &&
                time.year == _selectedDay!.year &&
                time.month == _selectedDay!.month &&
                time.day == _selectedDay!.day;
          }).toList();
    }

    return Scaffold(
      appBar: AppBar(title: Text("📊 รายงานรายได้")),
      body: Column(
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
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
              fetchData();
            },
            calendarFormat: CalendarFormat.month,
            locale: 'th_TH',
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedDay = null;
                    });
                  },
                  child: Text("รีเซ็ต"),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    if (_selectedDay != null) {
                      double total = calculateDailyTotal(_selectedDay!);
                      showDialog(
                        context: context,
                        builder:
                            (_) => AlertDialog(
                              title: Text("ยอดรวมรายวัน"),
                              content: Text(
                                "ยอดรวมวันที่ ${DateFormat('dd/MM/yyyy').format(_selectedDay!)} คือ ${total.toStringAsFixed(2)} บาท",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text("ปิด"),
                                ),
                              ],
                            ),
                      );
                    }
                  },
                  child: Text("ยอดรวมรายวัน"),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    double total = calculateMonthlyTotal(_focusedDay);
                    showDialog(
                      context: context,
                      builder:
                          (_) => AlertDialog(
                            title: Text("ยอดรวมรายเดือน"),
                            content: Text(
                              "ยอดรวมเดือน ${DateFormat('MM/yyyy').format(_focusedDay)} คือ ${total.toStringAsFixed(2)} บาท",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text("ปิด"),
                              ),
                            ],
                          ),
                    );
                  },
                  child: Text("ยอดรวมรายเดือน"),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Expanded(
            child:
                filteredData.isEmpty
                    ? Center(
                      child: Text(
                        _selectedDay != null
                            ? "ไม่มีข้อมูลสำหรับวัน ${DateFormat('dd/MM/yyyy').format(_selectedDay!)}"
                            : "เลือกวันที่เพื่อดูข้อมูล หรือกดรีเซ็ตเพื่อตรวจสอบข้อมูลทั้งหมด",
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                    : ListView.builder(
                      itemCount: filteredData.length,
                      itemBuilder: (context, index) {
                        final row = filteredData[index];
                        DateTime? time =
                            row['time'] != null
                                ? DateTime.tryParse(row['time'])
                                : null;
                        return Card(
                          margin: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: ListTile(
                            title: Text(row['shop_name'] ?? "ไม่ระบุร้านค้า"),
                            subtitle: Text(
                              time != null
                                  ? DateFormat(
                                    "yyyy-MM-dd HH:mm:ss",
                                  ).format(time)
                                  : "-",
                            ),
                            trailing: Text("${row['amount']} บาท"),
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
