import 'dart:async';
import 'package:flutter/material.dart';
import '../models/fund_model.dart';
import '../core/services/firestore_service.dart';

class CommunityFundProvider extends ChangeNotifier {
  final FirestoreService _fs = FirestoreService();

  FundSummary? _summary;
  List<FundTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  StreamSubscription<FundSummary?>? _summarySub;
  StreamSubscription<List<FundTransaction>>? _txnSub;
  String? _currentAptId;

  FundSummary? get summary => _summary;
  List<FundTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get isInitialized => _summary != null;
  String? get error => _error;

  // Convenience filtered lists
  List<FundTransaction> get collections =>
      _transactions.where((t) => t.isCollection).toList();
  List<FundTransaction> get expenses =>
      _transactions.where((t) => t.isExpense).toList();

  void startListening(String aptId) {
    if (_currentAptId == aptId) return; // already listening
    _currentAptId = aptId;
    _cancelSubs();

    _summarySub = _fs.streamFundSummary(aptId).listen(
      (s) {
        _summary = s;
        notifyListeners();
      },
      onError: (_) => notifyListeners(),
    );

    _txnSub = _fs.streamFundTransactions(aptId).listen(
      (list) {
        _transactions = list;
        notifyListeners();
      },
      onError: (_) => notifyListeners(),
    );
  }

  void stopListening() {
    _cancelSubs();
    _currentAptId = null;
    _summary = null;
    _transactions = [];
    notifyListeners();
  }

  void _cancelSubs() {
    _summarySub?.cancel();
    _txnSub?.cancel();
    _summarySub = null;
    _txnSub = null;
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> initializeFund({required String aptId, required String createdBy}) async {
    _setLoading(true);
    try {
      await _fs.initializeFund(aptId: aptId, createdBy: createdBy);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<String> addCollection({
    required String aptId,
    required int amountPaise,
    required String description,
    required String createdBy,
    required String createdByName,
    String? receiptNote,
  }) async {
    _setLoading(true);
    try {
      final id = await _fs.addFundCollection(
        aptId: aptId,
        amountPaise: amountPaise,
        description: description,
        createdBy: createdBy,
        createdByName: createdByName,
        receiptNote: receiptNote,
      );
      // Optimistic update — reflect immediately before Firestore stream fires.
      if (_summary != null) {
        _summary = _summary!.copyWith(
          balancePaise: _summary!.balancePaise + amountPaise,
          totalCollectedPaise: _summary!.totalCollectedPaise + amountPaise,
          transactionCount: _summary!.transactionCount + 1,
          lastUpdatedAt: DateTime.now(),
        );
      }
      _transactions = [
        FundTransaction(
          id: id,
          apartmentId: aptId,
          type: FundTxnType.collection,
          amountPaise: amountPaise,
          description: description,
          category: FundCategory.general,
          createdBy: createdBy,
          createdByName: createdByName,
          createdAt: DateTime.now(),
          receiptNote: receiptNote?.isEmpty == true ? null : receiptNote,
        ),
        ..._transactions,
      ];
      _error = null;
      return id;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<String> addExpense({
    required String aptId,
    required int amountPaise,
    required String description,
    required String category,
    required String createdBy,
    required String createdByName,
    String? receiptNote,
  }) async {
    _setLoading(true);
    try {
      final id = await _fs.addFundExpense(
        aptId: aptId,
        amountPaise: amountPaise,
        description: description,
        category: category,
        createdBy: createdBy,
        createdByName: createdByName,
        receiptNote: receiptNote,
      );
      // Optimistic update — reflect immediately before Firestore stream fires.
      if (_summary != null) {
        _summary = _summary!.copyWith(
          balancePaise: _summary!.balancePaise - amountPaise,
          totalExpensedPaise: _summary!.totalExpensedPaise + amountPaise,
          transactionCount: _summary!.transactionCount + 1,
          lastUpdatedAt: DateTime.now(),
        );
      }
      _transactions = [
        FundTransaction(
          id: id,
          apartmentId: aptId,
          type: FundTxnType.expense,
          amountPaise: amountPaise,
          description: description,
          category: category,
          createdBy: createdBy,
          createdByName: createdByName,
          createdAt: DateTime.now(),
          receiptNote: receiptNote?.isEmpty == true ? null : receiptNote,
        ),
        ..._transactions,
      ];
      _error = null;
      return id;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelSubs();
    super.dispose();
  }
}
