import 'package:app_mobile/services/glpi_services.dart';
import 'package:app_mobile/signature.dart';
import 'package:app_mobile/tickets.dart';
import 'package:flutter/material.dart';
import 'authentification.dart';
import 'package:app_mobile/closedtickets.dart';

class MyTech extends StatefulWidget {
  const MyTech({super.key});

  @override
  State<MyTech> createState() => _MyTechState();
}

class _MyTechState extends State<MyTech> {
  String _username = '';
  String _initiales = '';
  bool _isSupervisor = false;
  final _selectedIndex = 0;
  Map<String, int> _ticketsCount = {
    'total': 0,
    'enCours': 0
  }; // en initialisant le nombre total de tickets et le nombre de tickets en cours à 0
  bool _loadingStats = false; //la cle est un string est la valeur est int

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadStats();
    _checkProfile();
  }

  //methode d'appel au service glpi pour faire appel au tickets au temps reel
  Future<void> _loadStats() async {
    final counts = await GLPIService.getTicketsCount();
    setState(() {
      _ticketsCount =
          counts; // on met à jour le nombre total de tickets et le nombre de tickets en cours
      _loadingStats =
          true; // indique que les statistiques ont été chargées et peuvent être affichées
    });
  }

//gere l'utilisateur connecté et affiche son username et ses initiales dans le drawer
  Future<void> _loadUser() async {
    final username = await GLPIService.getUsername();
    if (!mounted) return;
    setState(() {
      _username = username;
      _initiales = username.length >= 2
          ? username.substring(0, 2).toUpperCase()
          : username.toUpperCase();
    });
  }

  // chargement de profil superviseur pour afficher quelques element dédié au superviseur
  Future<void> _checkProfile() async {
    final isSup = await GLPIService.isSupervisor();
    if (!mounted) return;
    setState(() => _isSupervisor = isSup);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(22, 82, 195, 1),
        elevation: 0.0,
        title: Center(
          child: Text(
            'Data Xpress',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          Icon(Icons.notifications_active, size: 25.0),
        ],
        iconTheme: IconThemeData(color: Colors.white, size: 25.0),
      ),

      //---------DRAWER-----------
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: Color.fromRGBO(22, 82, 195, 1),
              ),
              accountName: Text(
                _username, //  variable qui contient le username de l'utilisateur connecté
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              accountEmail: Text('$_username@dataxpress.com'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white24,
                child: Text(
                  _initiales,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            ListTile(
              selected: _selectedIndex == 0, //true si c'est la page active
              selectedColor: Color.fromRGBO(22, 82, 195, 1),
              leading: Icon(Icons.home, color: Color.fromRGBO(22, 82, 195, 1)),
              title: Text('Accueil',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading:
                  Icon(Icons.assignment, color: Color.fromRGBO(22, 82, 195, 1)),
              title: Text('Tickets',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MyTicket()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.location_on,
                  color: Color.fromRGBO(22, 82, 195, 1)),
              title: Text('Tracking',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.draw, color: Color.fromRGBO(22, 82, 195, 1)),
              title: Text('Signature client',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => MySignature(
                            ticketId: 0,
                            ticketName: '',
                          ))),
            ),
            if (_isSupervisor)
              ListTile(
                leading:
                    Icon(Icons.lock, color: Color.fromRGBO(22, 82, 195, 1)),
                title: Text(
                  'Tickets signés',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ClosedTicketsPage()),
                  );
                },
              ),
            Divider(),
            ListTile(
              leading: Icon(Icons.settings, color: Colors.grey),
              title: Text('Paramètres',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            Spacer(),
            Padding(
              padding: EdgeInsets.all(16),
              //deconnextion item
              child: GestureDetector(
                onTap: () async {
                  await GLPIService.logout();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthPage()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: Colors.red[700], size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Se déconnecter',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      //---------BODY-----------
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 10),
            Text(
              'Bienvenue, $_username !', // Affiche le username dans le message de bienvenue
              style: TextStyle(
                color: Colors.blue[900],
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                _buildStat('${_ticketsCount['total']}',
                    'Total'), //on recupere les tickets ici
                SizedBox(width: 10),
                _buildStat2('${_ticketsCount['enCours']}', 'En cours'),
                SizedBox(width: 10),
                if (_isSupervisor)
                  _buildStat3('${_ticketsCount['signés']}', 'Signés'),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'FONCTIONNALITÉS',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 12),
            _buildCard(
              icon: Icons.assignment,
              title: 'Mes tickets',
              description: 'Voir et gérer les tickets assignés',
              badge: 'Totals:${_ticketsCount['total']}',
              iconColor: Color(0xFF3949AB),
              iconBg: Color(0xFFE8EAF6),
              badgeColor: Color(0xFF3949AB),
              badgeBg: Color(0xFFE8EAF6),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MyTicket()),
                );
              },
            ),
            SizedBox(height: 12),
            if (_isSupervisor)
              _buildCard(
                icon: Icons.assignment_turned_in_rounded,
                title: 'Tickets signés',
                description: 'Voir les tickets fermés et signés',
                badge: 'Signés : ${_ticketsCount['signés'] ?? 0}',
                iconColor: Color.fromARGB(255, 117, 117, 117),
                iconBg: Color.fromARGB(93, 189, 178, 178),
                badgeColor: Color.fromARGB(255, 117, 117, 117),
                badgeBg: Color(0xFFEEEEEE),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ClosedTicketsPage()),
                  );
                },
              ),
            SizedBox(height: 12),
            _buildCard(
              icon: Icons.location_on,
              title: 'Tracking position',
              description: 'Partager votre position en temps réel',
              badge: 'GPS actif',
              iconColor: Color(0xFF388E3C),
              iconBg: Color(0xFFE8F5E9),
              badgeColor: Color(0xFF388E3C),
              badgeBg: Color(0xFFE8F5E9),
              onTap: () {}, //l'evenement vers la page tracking de position
            ),
            SizedBox(height: 12),
            _buildCard(
              icon: Icons.draw,
              title: 'Signature client',
              description: 'Faire signer après intervention',
              badge: 'Requis à la clôture',
              iconColor: Color(0xFFE65100),
              iconBg: Color(0xFFFFF3E0),
              badgeColor: Color(0xFFE65100),
              badgeBg: Color(0xFFFFF3E0),
              onTap: () => {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 225, 229, 255),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.assignment_rounded, color: Color(0xFF3949AB), size: 28),
            SizedBox(height: 8),
            Text(value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
            SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
Widget _buildStat3(String value, String label) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 212, 255, 234),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.assignment_turned_in_rounded, color: Color.fromARGB(255, 34, 142, 57), size: 28),
            SizedBox(height: 8),
            Text(value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
            SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildStat2(String value, String label) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.autorenew_rounded,
                color: Color.fromARGB(255, 217, 115, 7), size: 28),
            SizedBox(height: 8),
            Text(value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
            SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

// cree une carte de fonctionnalité réutilisable pour les différentes options du menu
  Widget _buildCard({
    required IconData icon,
    required String title,
    required String description,
    required String badge,
    required Color iconColor,
    required Color iconBg,
    required Color badgeColor,
    required Color badgeBg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  SizedBox(height: 3),
                  Text(description,
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  SizedBox(height: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                          fontSize: 11,
                          color: badgeColor,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
