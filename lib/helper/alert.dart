import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  final Map<String, dynamic> statusObj;

  const StatusIndicator({
    super.key,
    required this.statusObj,
  });

  /// يحول الاسم إلى لون
  Color _parseColor(dynamic colorValue) {
    if (colorValue is Color) return colorValue;
    if (colorValue is String) {
      switch (colorValue.toLowerCase()) {
        case 'green':
          return Colors.green;
        case 'red':
          return Colors.red;
        case 'orange':
          return Colors.orange;
        case 'blue':
          return Colors.blue;
        case 'gray':
          return Colors.grey;
        default:
          return Colors.grey;
      }
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final String message = statusObj['message']?.toString() ?? '';
    final Color color = _parseColor(statusObj['color']);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
