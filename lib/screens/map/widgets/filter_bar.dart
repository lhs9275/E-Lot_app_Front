import 'package:flutter/material.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.showH2,
    required this.showEv,
    required this.showParking,
    required this.h2Color,
    required this.evColor,
    required this.parkingColor,
    required this.onToggleH2,
    required this.onToggleEv,
    required this.onToggleParking,
  });

  final bool showH2;
  final bool showEv;
  final bool showParking;
  final Color h2Color;
  final Color evColor;
  final Color parkingColor;
  final VoidCallback onToggleH2;
  final VoidCallback onToggleEv;
  final VoidCallback onToggleParking;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilterIcon(
            active: showH2,
            icon: Icons.local_gas_station,
            color: h2Color,
            label: 'H2',
            onTap: onToggleH2,
          ),
          const SizedBox(width: 8),
          _FilterIcon(
            active: showEv,
            icon: Icons.ev_station,
            color: evColor,
            label: 'EV',
            onTap: onToggleEv,
          ),
          const SizedBox(width: 8),
          _FilterIcon(
            active: showParking,
            icon: Icons.local_parking,
            color: parkingColor,
            label: 'P',
            onTap: onToggleParking,
          ),
        ],
      ),
    );
  }
}

class _FilterIcon extends StatelessWidget {
  const _FilterIcon({
    required this.active,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = active ? color : Colors.grey.shade300;
    final iconColor = active ? Colors.white : Colors.grey.shade700;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? Colors.black87 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
