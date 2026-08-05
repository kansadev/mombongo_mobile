import 'package:flutter/material.dart';
import 'package:mombongo/models/financial_data.dart';

class MetricCard extends StatelessWidget {
  final FinancialMetric metric;

  const MetricCard({Key? key, required this.metric}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: metric.color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            metric.icon,
            size: 28,
            color: metric.color,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          metric.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: Text(
            metric.value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: metric.color,
            ),
          ),
        ),
      ],
    );
  }
}
