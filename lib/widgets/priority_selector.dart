import 'package:flutter/material.dart';
import '../models/task.dart';

class PrioritySelector extends StatelessWidget {
  final TaskPriority selectedPriority;
  final Function(TaskPriority) onPrioritySelected;

  const PrioritySelector({
    super.key,
    required this.selectedPriority,
    required this.onPrioritySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '优先级',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: TaskPriority.values.map((priority) {
                final isSelected = selectedPriority == priority;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(priority.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          onPrioritySelected(priority);
                        }
                      },
                      selectedColor: _getPriorityColor(priority).withOpacity(0.2),
                      checkmarkColor: _getPriorityColor(priority),
                      labelStyle: TextStyle(
                        color: isSelected ? _getPriorityColor(priority) : null,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.green;
    }
  }
}
