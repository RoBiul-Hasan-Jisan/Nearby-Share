import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/transfer_model.dart';

/// Local-only transfer history (SharedPreferences, newest first).
class HistoryProvider extends ChangeNotifier {
  List<TransferModel> _items = [];

  List<TransferModel> get items => List.unmodifiable(_items);
  List<TransferModel> get recent => _items.take(5).toList();

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.prefsHistoryKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _items = list.map((e) => TransferModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      _items = [];
    }
    notifyListeners();
  }

  Future<void> add(TransferModel item) async {
    _items.insert(0, item);
    if (_items.length > AppConstants.maxHistoryItems) {
      _items = _items.sublist(0, AppConstants.maxHistoryItems);
    }
    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    _items = [];
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefsHistoryKey, jsonEncode(_items.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }
}
