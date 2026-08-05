import 'package:flutter/material.dart';

class FinancialMetric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  FinancialMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class RevenueHistory {
  final String date;
  final String amount;
  final String period;

  RevenueHistory({
    required this.date,
    required this.amount,
    required this.period,
  });
}
