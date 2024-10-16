import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  runApp(AppointmentCalendarApp());
}

class AppointmentCalendarApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Appointment Calendar',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AppointmentCalendarScreen(),
    );
  }
}

class AppointmentCalendarScreen extends StatefulWidget {
  @override
  _AppointmentCalendarScreenState createState() =>
      _AppointmentCalendarScreenState();
}

class _AppointmentCalendarScreenState extends State<AppointmentCalendarScreen> {
  late Database database;
  Map<DateTime, List<Map<String, dynamic>>> appointments = {};
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    database = await openDatabase(
      join(await getDatabasesPath(), 'appointments.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE appointments(id INTEGER PRIMARY KEY, title TEXT, date TEXT, time TEXT, location TEXT, notes TEXT)',
        );
      },
      version: 1,
    );
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    final List<Map<String, dynamic>> data = await database.query('appointments');
    Map<DateTime, List<Map<String, dynamic>>> tempAppointments = {};
    for (var appointment in data) {
      DateTime date = DateTime.parse(appointment['date']);
      DateTime dateWithoutTime = DateTime(date.year, date.month, date.day);
      if (!tempAppointments.containsKey(dateWithoutTime)) {
        tempAppointments[dateWithoutTime] = [];
      }
      tempAppointments[dateWithoutTime]!.add(appointment);
    }
    setState(() {
      appointments = tempAppointments;
    });
  }

  Future<void> _addAppointment(
      String title, DateTime date, TimeOfDay time, String? location, String? notes, BuildContext context) async {
    final formattedTime = time.hour.toString().padLeft(2, '0') + ':' + time.minute.toString().padLeft(2, '0');
    await database.insert(
      'appointments',
      {
        'title': title,
        'date': date.toIso8601String(),
        'time': formattedTime,
        'location': location ?? '',
        'notes': notes ?? '',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _loadAppointments();
  }

  Future<void> _deleteAppointment(int id) async {
    await database.delete(
      'appointments',
      where: 'id = ?',
      whereArgs: [id],
    );
    _loadAppointments();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Appointment Calendar'),
        ),
        body: Column(
          children: [
            TableCalendar(
              focusedDay: _focusedDay,
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',
              },
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              eventLoader: (day) {
                DateTime dayWithoutTime = DateTime(day.year, day.month, day.day);
                return appointments[dayWithoutTime]?.isNotEmpty == true ? [''] : [];
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay; // 保持显示选中的日期
                });
              },
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
            ),
            ElevatedButton(
              onPressed: () {
                _showAddAppointmentDialog(context);
              },
              child: Text('Add Appointment'),
            ),
            Expanded(
              child: _buildAppointmentListForSelectedDay(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentListForSelectedDay() {
    final List<Map<String, dynamic>> selectedAppointments = appointments[DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day)] ?? [];

    if (selectedAppointments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('No appointments on this day.'),
      );
    }

    return ListView.builder(
      itemCount: selectedAppointments.length,
      itemBuilder: (context, index) {
        final appointment = selectedAppointments[index];
        return ListTile(
          title: Text(appointment['title']),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Time: ${appointment['time']}'),
              if (appointment['location'] != null && appointment['location'].isNotEmpty)
                Text('Location: ${appointment['location']}'),
              if (appointment['notes'] != null && appointment['notes'].isNotEmpty)
                Text('Notes: ${appointment['notes']}'),
            ],
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              _deleteAppointment(appointment['id']);
            },
          ),
        );
      },
    );
  }

  void _showAddAppointmentDialog(BuildContext context) {
    String appointmentTitle = '';
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    String? appointmentLocation;
    String? appointmentNotes;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Appointment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: InputDecoration(labelText: 'Appointment Title'),
                    onChanged: (value) {
                      appointmentTitle = value;
                    },
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          selectedDate = pickedDate;
                        });
                      }
                    },
                    child: Text('Pick Date'),
                  ),
                  if (selectedDate != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Selected Date: ${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}'),
                    ),
                  ElevatedButton(
                    onPressed: () async {
                      final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (pickedTime != null) {
                        setState(() {
                          selectedTime = pickedTime;
                        });
                      }
                    },
                    child: Text('Pick Time'),
                  ),
                  if (selectedTime != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Selected Time: ${selectedTime!.format(context)}'),
                    ),
                  SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(labelText: 'Location (Optional)'),
                    onChanged: (value) {
                      appointmentLocation = value;
                    },
                  ),
                  SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(labelText: 'Notes (Optional)'),
                    onChanged: (value) {
                      appointmentNotes = value;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (appointmentTitle.isNotEmpty && selectedDate != null && selectedTime != null) {
                      _addAppointment(
                        appointmentTitle,
                        selectedDate!,
                        selectedTime!,
                        appointmentLocation,
                        appointmentNotes,
                        context,
                      );
                      Navigator.of(context).pop();
                    } else {
                      _showOverlayError(context, 'Title, Date, and Time are required!');
                    }
                  },
                  child: Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showOverlayError(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.9,
        left: 10,
        right: 10,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(10),
            color: Colors.redAccent,
            child: Text(
              message,
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
    overlay?.insert(overlayEntry);

    Future.delayed(Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }
}
