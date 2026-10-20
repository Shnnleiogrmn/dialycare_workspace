import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';

class PlannedDurationField extends StatelessWidget {
  const PlannedDurationField({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final int value;
  final ValueChanged<int>? onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    initialValue: value,
    decoration: const InputDecoration(labelText: 'Planned Duration'),
    isExpanded: true,
    items: [
      for (final minutes in {...plannedDurationOptions, value})
        DropdownMenuItem(
          value: minutes,
          child: Text(
            durationLabel(minutes),
            style: const TextStyle(fontSize: 13),
          ),
        ),
    ],
    onChanged: onChanged == null ? null : (v) => onChanged!(v!),
  );
}
