// lib/services/photo_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/photo.dart';

class PhotoService {
  static const String _photosKey = 'photos';

  Future<List<Photo>> loadPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPhotos = prefs.getStringList(_photosKey) ?? [];
    return savedPhotos
        .map((photo) => Photo.fromJson(jsonDecode(photo) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // 최신 날짜 순 정렬
  }

  Future<void> savePhotos(List<Photo> photos) async {
    final prefs = await SharedPreferences.getInstance();
    final photosJson = photos.map((photo) => jsonEncode(photo.toJson())).toList();
    await prefs.setStringList(_photosKey, photosJson);
  }

  Future<void> addPhoto(Photo photo) async {
    final photos = await loadPhotos();
    photos.insert(0, photo); // 새로운 사진을 리스트의 시작 부분에 추가
    await savePhotos(photos);
  }

  Future<void> deletePhoto(int index) async {
    final photos = await loadPhotos();
    if (index >= 0 && index < photos.length) {
      photos.removeAt(index);
      await savePhotos(photos);
    }
  }
}