import 'package:flutter/material.dart';
import 'package:finalproject/screens/CreateTripScreen.dart';

class AppShell {
  /// BottomNavigationBar มาตรฐาน ใช้ร่วมกันทุกหน้า
  static BottomNavigationBar bottomNav({
    required BuildContext context,
    required int currentIndex, // 0 = Home, 1 = My Trips
  }) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: const Color(0xFF00B4F1),
      unselectedItemColor: Colors.grey,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'My Trips'),
      ],
      onTap: (i) {
        if (i == currentIndex) return;
        final route = i == 0 ? '/home' : '/mytrips';
        Navigator.of(context).pushReplacementNamed(route);
      },
    );
  }

  /// FAB มาตรฐาน ใช้ร่วมกันทุกหน้า
  static Widget fab({
    required BuildContext context,
    required Future<void> Function() onRefresh, // callback reload list หลังกลับจากสร้างทริป
  }) {
    return FloatingActionButton(
      backgroundColor: const Color(0xFF00B4F1),
      child: const Icon(Icons.add),
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateTripScreen()),
        );
        await onRefresh();
      },
    );
  }
}
