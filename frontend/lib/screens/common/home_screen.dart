import 'package:flutter/material.dart';
import 'profile_screen.dart';
import '../donor/donate_screen.dart';
import '../requester/request_screen.dart';
import '../common/chat_screen.dart';
import '../common/volunteer_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _indicatorController;

  final Color bgColor = const Color(0xFFF4F4F4);
  final Color accentColor = Colors.brown;

  final List<_NavBarItemData> navItems = const [
    _NavBarItemData(Icons.home, 'Home'),
    _NavBarItemData(Icons.favorite, 'Donate'),
    _NavBarItemData(Icons.handshake, 'Request'),
    _NavBarItemData(Icons.chat, 'Chat'),
    _NavBarItemData(Icons.person, 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _indicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    super.dispose();
  }

  void _onNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _indicatorController.forward(from: 0);
    });

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DonateScreen()),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RequestScreen()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatScreen()),
      );
    } else if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF4F4F4), Color(0xFFE8F5E9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreetingRow(),
                const SizedBox(height: 20),
                _buildMainCard(),
                const SizedBox(height: 20),
                _buildSectionTitle("Causes"),
                const SizedBox(height: 6),
                _buildCausesList(),
                const SizedBox(height: 14),
                _buildSectionTitle("Emergency Help"),
                const SizedBox(height: 10),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 19),
        child: SafeArea(child: _buildBottomNavigationBar()),
      ),
    );
  }

  // Show user's name, default avatar icon
  Widget _buildGreetingRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Wrap the text Column in Expanded to prevent overflow
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hello!",
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                "Welcome to Zero Food Waste",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfileScreen()),
          ),
          child: const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, color: Colors.brown, size: 32),
          ),
        ),
      ],
    );
  }

  Widget _buildMainCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [accentColor.withOpacity(0.7), accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Food Help",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Text(
            "Target: \$23,670",
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildCausesList() {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _causeItem(Icons.restaurant, "Food Help", true),
          _causeItem(Icons.medical_services, "Medicine", false),
          _causeItem(Icons.checkroom, "Clothes", false),
          _causeItem(Icons.school, "Education", false),
          _causeItem(Icons.pets, "Pets", false),
        ],
      ),
    );
  }

  Widget _causeItem(IconData icon, String label, bool selected) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      width: 100,
      decoration: BoxDecoration(
        color: selected ? accentColor.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? accentColor : Colors.grey.shade200,
          width: 2,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: accentColor.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: accentColor, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _actionButton("Donate", Icons.favorite, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DonateScreen()),
              );
            }),
            _actionButton("Volunteer", Icons.volunteer_activism, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => VolunteerScreen()),
              );
            }),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.45,
              child: _actionButton("Request", Icons.handshake, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RequestScreen()),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 200,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accentColor, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(navItems.length, (index) {
            final selected = _selectedIndex == index;
            return Flexible(
              child: GestureDetector(
                onTap: () => _onNavTapped(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Icon(
                    navItems[index].icon,
                    size: selected ? 32 : 28,
                    color: selected ? accentColor : Colors.grey[500],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavBarItemData {
  final IconData icon;
  final String label;
  const _NavBarItemData(this.icon, this.label);
}
