import 'package:flutter/material.dart';

import '../../../../core/constants/wms_theme.dart';

class ListenerNavigation extends StatelessWidget {
  const ListenerNavigation({
    super.key,
    required this.selectedIndex,
    required this.extended,
    required this.onSelected,
  });

  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => NavigationRail(
    backgroundColor: WmsColors.textPrimary,
    extended: extended,
    minWidth: 82,
    minExtendedWidth: 228,
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    indicatorColor: WmsColors.primaryLight,
    selectedIconTheme: const IconThemeData(color: WmsColors.primary),
    unselectedIconTheme: const IconThemeData(color: Colors.white70),
    selectedLabelTextStyle: const TextStyle(
      color: WmsColors.primary,
      fontWeight: FontWeight.w700,
      fontFamily: 'Poppins',
    ),
    unselectedLabelTextStyle: const TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.w500,
      fontFamily: 'Poppins',
    ),
    labelType: extended
        ? NavigationRailLabelType.none
        : NavigationRailLabelType.selected,
    leading: Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 34),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: WmsColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: Colors.white),
          ),
          if (extended) ...[
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WMS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                Text(
                  'WINDOWS LISTENER',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
    destinations: const [
      NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: Text('Dashboard'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.qr_code_scanner_outlined),
        selectedIcon: Icon(Icons.qr_code_scanner_rounded),
        label: Text('File Scan'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings_rounded),
        label: Text('Pengaturan'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.print_outlined),
        selectedIcon: Icon(Icons.print),
        label: Text('Print label'),
      ),
    ],
  );
}
