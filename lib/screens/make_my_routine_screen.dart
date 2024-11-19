// lib/screens/make_my_routine_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/exercise.dart';
import '../models/exercise_log.dart';
import '../services/routine_storage_service.dart';
import '../services/exercise_log_storage_service.dart'; // 추가
import '../widgets/exercise_card.dart';

class MakeMyRoutineScreen extends StatefulWidget {
  final List<Exercise>? initialExercises; // 초기 운동 리스트

  const MakeMyRoutineScreen({Key? key, this.initialExercises}) : super(key: key);

  @override
  State<MakeMyRoutineScreen> createState() => _MakeMyRoutineScreenState();
}

class _MakeMyRoutineScreenState extends State<MakeMyRoutineScreen> {
  List<Exercise> _exercises = [];
  final RoutineStorageService _storageService = RoutineStorageService();
  final ExerciseLogStorageService _logStorageService =
  ExerciseLogStorageService(); // 추가
  final AudioPlayer _audioPlayer = AudioPlayer();

  Duration _timerDuration = const Duration(minutes: 1);
  bool _isTimerRunning = false;
  Duration _remainingTime = const Duration();

  @override
  void initState() {
    super.initState();
    _loadRoutine();
  }

  Future<void> _loadRoutine() async {
    if (widget.initialExercises != null &&
        widget.initialExercises!.isNotEmpty) {
      setState(() {
        _exercises = widget.initialExercises!;
      });
    } else {
      List<Exercise> loadedExercises = await _storageService.loadRoutine();
      setState(() {
        if (loadedExercises.isEmpty) {
          _exercises.add(Exercise(
            name: "새 운동",
            sets: [],
            recentRecord: '20kg x 10회',
            recommendedRecord: '25kg x 10회',
          ));
        } else {
          _exercises.addAll(loadedExercises);
        }
      });
    }
  }

  void _addExercise() {
    setState(() {
      _exercises.add(Exercise(
        name: "새 운동",
        sets: [],
        recentRecord: '20kg x 10회',
        recommendedRecord: '25kg x 10회',
      ));
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  Future<void> _saveAllExercises() async {
    await _storageService.saveRoutine(_exercises);
    await _saveExerciseLog(); // 운동 기록 저장

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('모든 운동이 저장되었습니다!')),
    );

    // 홈 화면으로 이동
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _saveExerciseLog() async {
    DateTime now = DateTime.now();
    DateTime dateOnly = DateTime(now.year, now.month, now.day);

    ExerciseLog log = ExerciseLog(
      date: dateOnly,
      exercises: _exercises,
    );
    await _logStorageService.saveExerciseLog(log);
    print("운동 기록이 저장되었습니다: ${log.toJson()}");
  }

  Future<void> _saveExercise(int index) async {
    await _storageService.saveRoutine(_exercises);
  }

  void _updateSets(int index, List<Map<String, int>> sets) {
    setState(() {
      _exercises[index] = Exercise(
        name: _exercises[index].name,
        sets: sets,
        recentRecord: _exercises[index].recentRecord,
        recommendedRecord: _exercises[index].recommendedRecord,
      );
    });
  }

  // 타이머 관련 메서드들
  void _startTimer() {
    setState(() {
      _isTimerRunning = true;
      _remainingTime = _timerDuration;
    });
    _countDown();
  }

  void _cancelTimer() {
    setState(() {
      _isTimerRunning = false;
      _remainingTime = _timerDuration;
    });
  }

  void _countDown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_remainingTime > const Duration(seconds: 1) && _isTimerRunning) {
        setState(() {
          _remainingTime -= const Duration(seconds: 1);
        });
        _countDown();
      } else if (_isTimerRunning) {
        setState(() {
          _isTimerRunning = false;
        });
        _playSound();
      }
    });
  }

  Future<void> _playSound() async {
    await _audioPlayer.play(AssetSource('sounds/timer_end.mp3'));
  }

  void _showTimerPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SizedBox(
        height: 250,
        child: CupertinoTimerPicker(
          initialTimerDuration: _timerDuration,
          mode: CupertinoTimerPickerMode.ms,
          onTimerDurationChanged: (Duration newDuration) {
            setState(() {
              _timerDuration = newDuration;
              _remainingTime = newDuration;
            });
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: const Text(
          'My Routine',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, size: 30),
            onPressed: _saveAllExercises, // 저장 후 홈 화면으로 이동
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _exercises.length,
              itemBuilder: (context, index) {
                final exercise = _exercises[index];
                return Column(
                  children: [
                    ExerciseCard(
                      exercise: exercise,
                      onDelete: () => _removeExercise(index),
                      onSetsUpdated: (sets) => _updateSets(index, sets),
                      onSave: () => _saveExercise(index), // 개별 저장
                    ),
                    const SizedBox(height: 10),
                    if (index == _exercises.length - 1)
                      ElevatedButton.icon(
                        onPressed: _addExercise,
                        icon: const Icon(Icons.add, color: Colors.grey),
                        label: const Text(
                          "Add",
                          style: TextStyle(color: Colors.black),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
          // 타이머 위젯
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_timerDuration == const Duration(minutes: 0)) ...[
                      // 초기 상태: 타이머가 설정되지 않았을 때
                      ElevatedButton(
                        onPressed: _showTimerPicker,
                        child: const Text("Timer set"),
                      ),
                    ] else ...[
                      // 타이머가 설정된 후 표시
                      Text(
                        _isTimerRunning
                            ? "Remaining time: ${_remainingTime.inMinutes}:${(_remainingTime.inSeconds % 60).toString().padLeft(2, '0')}"
                            : "Time set: ${_timerDuration.inMinutes}:${(_timerDuration.inSeconds % 60).toString().padLeft(2, '0')}",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          // 타이머 시작/취소 버튼
                          ElevatedButton(
                            onPressed:
                            _isTimerRunning ? _cancelTimer : _startTimer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              _isTimerRunning ? Colors.red : Colors.green,
                              minimumSize: const Size(50, 36),
                              padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: Text(_isTimerRunning ? "Stop" : "Start"),
                          ),
                          const SizedBox(width: 8),
                          // 시간 설정 버튼
                          ElevatedButton(
                            onPressed: _showTimerPicker,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(50, 36),
                              padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text("Set"),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}