import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../logs/meal_log.dart'; // MealLog 임포트
import '../logs/exercise_log.dart';
import '../../services/exercise_log_storage_service.dart';
import '../logs/diet_log_screen.dart';
import '../logs/exercise_log_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  CalendarScreenState createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final ExerciseLogStorageService _logStorageService =
      ExerciseLogStorageService();
  List<ExerciseLog> _selectedDayExerciseLogs = [];

  Map<String, List<MealLog>> _dietLogsByDate = {};
  List<MealLog>? _selectedDayDietLog;

  Map<String, List<ExerciseLog>> _exerciseLogsByDate = {};

  @override
  void initState() {
    super.initState();
    _loadExerciseLogForSelectedDay();
    _loadDietLogForSelectedDay();
    _loadAllExerciseLogs();
  }

  // 모든 운동 로그를 불러와 날짜별로 매핑
  Future<void> _loadAllExerciseLogs() async {
    List<ExerciseLog> allLogs = await _logStorageService.loadAllExerciseLogs();
    Map<String, List<ExerciseLog>> logsByDate = {};

    for (var log in allLogs) {
      String dateKey = _getDateKey(log.timestamp);
      if (!logsByDate.containsKey(dateKey)) {
        logsByDate[dateKey] = [];
      }
      logsByDate[dateKey]!.add(log);
    }

    setState(() {
      _exerciseLogsByDate = logsByDate;
    });
  }

  void _loadExerciseLogForSelectedDay() async {
    List<ExerciseLog> logs =
        await _logStorageService.loadExerciseLogsByDate(_selectedDay);
    setState(() {
      _selectedDayExerciseLogs = logs;
    });
  }

  void _loadDietLogForSelectedDay() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('dietLogs');
    if (data != null) {
      try {
        Map<String, dynamic> jsonData = jsonDecode(data);
        setState(() {
          _dietLogsByDate = jsonData.map((date, meals) {
            return MapEntry(
              date,
              List<MealLog>.from(
                (meals as List<dynamic>)
                    .map((mealJson) => MealLog.fromJson(mealJson)),
              ),
            );
          }).cast<String, List<MealLog>>();

          String dateKey = _getDateKey(_selectedDay);
          _selectedDayDietLog = _dietLogsByDate[dateKey];
        });
      } catch (e) {
        debugPrint('Error decoding diet logs: $e');
        setState(() {
          _dietLogsByDate = {};
          _selectedDayDietLog = null;
        });
      }
    } else {
      setState(() {
        _dietLogsByDate = {};
        _selectedDayDietLog = null;
      });
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _loadExerciseLogForSelectedDay();
    _loadDietLogForSelectedDay();
  }

  String _getDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date); // 'YYYY-MM-DD' 형식
  }

  void _navigateToDietLogScreen() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => DietLogScreen(selectedDay: _selectedDay),
      ),
    )
        .then((_) {
      _loadDietLogForSelectedDay();
      _loadAllExerciseLogs();
    });
  }

  void _goToToday() {
    final today = DateTime.now();
    setState(() {
      _selectedDay = today;
      _focusedDay = today;
    });
    _loadExerciseLogForSelectedDay();
    _loadDietLogForSelectedDay();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 100,
        centerTitle: true,
        title: const Padding(
          padding: EdgeInsets.only(top: 20.0),
          child: Text(
            'Calendar',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _goToToday,
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarStyle: CalendarStyle(
                // selectedDecoration: BoxDecoration(
                //   color: Colors.black12,
                //   shape: BoxShape.circle
                // ),
                todayDecoration: BoxDecoration(
                    color: Colors.black12, shape: BoxShape.circle)),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                String dateKey = _getDateKey(date);
                List<Widget> indicators = [];
                if (_exerciseLogsByDate.containsKey(dateKey)) {
                  final exerciseLogs = _exerciseLogsByDate[dateKey]!;
                  bool hasExerciseLog = exerciseLogs.isNotEmpty;
                  if (hasExerciseLog) {
                    indicators.add(
                      FaIcon(
                        FontAwesomeIcons.solidCircleCheck, // 두꺼운 체크 아이콘
                        color: Colors.blueAccent,
                        size: 16, // 아이콘 크기 조정
                      ),
                    );
                  }
                }

                // 식단 로그 체크 표시 (초록색 체크 아이콘)
                if (_dietLogsByDate.containsKey(dateKey)) {
                  final mealLogs = _dietLogsByDate[dateKey]!;
                  bool hasDietLog =
                      mealLogs.any((meal) => meal.foods.isNotEmpty);
                  if (hasDietLog) {
                    indicators.add(
                      FaIcon(
                        FontAwesomeIcons.solidCircleCheck, // 두꺼운 체크 아이콘
                        color: Colors.red,
                        size: 16, // 아이콘 크기 조정
                      ),
                    );
                  }
                }

                if (indicators.isNotEmpty) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: indicators,
                  );
                }
                return null;
              },
              selectedBuilder: (context, date, focusedDay) {
                bool isToday = isSameDay(date, DateTime.now());
                if (isToday) {
                  // 오늘 날짜일 때: 채워진 원
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${date.day}',
                      style: const TextStyle(color: Colors.black),
                    ),
                  );
                } else {
                  // 오늘이 아닌 선택된 날짜일 때: 외곽선만 있는 원
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${date.day}',
                      style: const TextStyle(color: Colors.black),
                    ),
                  );
                }
              },
              todayBuilder: (context, date, focusedDay) {
                // 오늘 날짜의 빌더를 별도로 정의할 수 있습니다.
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${date.day}',
                    style: const TextStyle(color: Colors.black),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: Row(
              children: [
                // Workout Log 섹션
                Expanded(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Workout Log',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _selectedDayExerciseLogs.isNotEmpty
                            ? ListView.builder(
                                itemCount: _selectedDayExerciseLogs.length,
                                itemBuilder: (context, logIndex) {
                                  final log =
                                      _selectedDayExerciseLogs[logIndex];
                                  return ExpansionTile(
                                    title: Text(
                                      DateFormat('HH:mm').format(log.timestamp),
                                      style: const TextStyle(
                                        fontSize: 16,
                                      ),
                                    ),
                                    children: log.exercises.map((exercise) {
                                      return ListTile(
                                        title: Text(
                                          exercise.name,
                                          style: const TextStyle(
                                            decoration: TextDecoration.underline,
                                            fontSize: 16,
                                          ),
                                        ),
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => ExerciseLogDetailScreen(
                                                exercise: exercise,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }).toList(),
                                  );
                                },
                              )
                            : const Center(
                                child: Text('No workout logs for this day'),
                              ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                // Diet Log 섹션
                Expanded(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Diet Log',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _selectedDayDietLog != null &&
                                _selectedDayDietLog!.isNotEmpty
                            ? _buildDietLogSections()
                            : Center(
                                child: ElevatedButton(
                                  onPressed: _navigateToDietLogScreen,
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.black,
                                  ),
                                  child: const Text('Add/Edit Diet'),
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

  /// DietLog 섹션 빌드
  Widget _buildDietLogSections() {
    final List<MealLog> meals = _selectedDayDietLog!;

    return ListView.builder(
      itemCount: meals.length,
      itemBuilder: (context, index) {
        final mealLog = meals[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meal name and edit button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      index == 0
                          ? 'Meal 1'
                          : index == 1
                              ? 'Meal 2'
                              : index == 2
                                  ? 'Meal 3'
                                  : 'Meal ${index + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.black),
                      onPressed: _navigateToDietLogScreen,
                    ),
                  ],
                ),
                // Foods list
                mealLog.foods.isNotEmpty
                    ? Column(
                        children: mealLog.foods.map((consumed) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Food name
                                Text(
                                  consumed.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Nutrient information
                                Text(
                                  'Amount: ${consumed.quantity.toStringAsFixed(1)}g\n'
                                  'Carbs: ${consumed.carbs.toStringAsFixed(1)}g\n'
                                  'Protein: ${consumed.protein.toStringAsFixed(1)}g\n'
                                  'Fat: ${consumed.fat.toStringAsFixed(1)}g',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          'No foods added.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}
