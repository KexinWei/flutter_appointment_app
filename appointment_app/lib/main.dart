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
          'CREATE TABLE appointments(id INTEGER PRIMARY KEY, title TEXT, date TEXT, time TEXT)',
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
      if (!tempAppointments.containsKey(date)) {
        tempAppointments[date] = [];
      }
      tempAppointments[date]!.add(appointment);
    }
    setState(() {
      appointments = tempAppointments;
    });
  }

  Future<void> _addAppointment(String title, DateTime date, TimeOfDay time, BuildContext context) async {
    await database.insert(
      'appointments',
      {
        'title': title,
        'date': date.toIso8601String(),
        'time': time.format(context), // Use the correct BuildContext
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Appointment Calendar'),
      ),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: DateTime.now(),
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            calendarFormat: CalendarFormat.month,
            eventLoader: (day) {
              return appointments[day] ?? [];
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
              });
              _showAppointmentsForDay(selectedDay, context); // Pass the correct context
            },
          ),
          ElevatedButton(
            onPressed: () {
              _showAddAppointmentDialog(context);
            },
            child: Text('Add Appointment'),
          ),
        ],
      ),
    );
  }

  void _showAppointmentsForDay(DateTime day, BuildContext context) {
    final List<Map<String, dynamic>> selectedAppointments = appointments[day] ?? [];

    showDialog(
      context: context, // Use the correct BuildContext here
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Appointments on ${day.toString().split(' ')[0]}'),
          content: selectedAppointments.isEmpty
              ? Text('No appointments.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: selectedAppointments.map((appointment) {
                    return ListTile(
                      title: Text(appointment['title']),
                      subtitle: Text('${appointment['time']}'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          _deleteAppointment(appointment['id']);
                          Navigator.pop(context); // Close the dialog
                        },
                      ),
                    );
                  }).toList(),
                ),
        );
      },
    );
  }

  void _showAddAppointmentDialog(BuildContext context) {
    String appointmentTitle = '';
    DateTime selectedDate = _selectedDay;
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context, // Correct BuildContext
      builder: (BuildContext context) {
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
                    context: context, // Correct BuildContext
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (pickedDate != null) {
                    selectedDate = pickedDate;
                  }
                },
                child: Text('Pick Date'),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  final TimeOfDay? pickedTime = await showTimePicker(
                    context: context, // Correct BuildContext
                    initialTime: selectedTime,
                  );
                  if (pickedTime != null) {
                    selectedTime = pickedTime;
                  }
                },
                child: Text('Pick Time'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog without adding
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (appointmentTitle.isNotEmpty) {
                  _addAppointment(appointmentTitle, selectedDate, selectedTime, context); // Pass context correctly
                  Navigator.of(context).pop(); // Close dialog after adding
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
