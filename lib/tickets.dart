import 'package:app_mobile/authentification.dart';
import 'package:app_mobile/services/glpi_services.dart';
import 'package:flutter/material.dart';
import 'package:app_mobile/techhome.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:app_mobile/tracking.dart';
import 'package:app_mobile/signature.dart';
import 'package:app_mobile/closedtickets.dart';

class MyTicket extends StatefulWidget {
  const MyTicket({super.key});

  @override
  State<MyTicket> createState() => _MyWidgetState();
}

//on va gerer l'utilisateur connecté
class _MyWidgetState extends State<MyTicket> {
  //declaration des variables qui contient les retours du back
  String _username = '';
  String _initiales = '';
  bool _isSupervisor = false;
  List<dynamic> _tickets =
      []; //liste des tickets qui va etre recuperer de glpi et afficher dans la page
  bool _isLoading = true;
  final _selectedIndex = 0;

  @override
  void initState() {
    //methode qui va etre executer lors de l'initialisation de la page
    super.initState();
    _loadUser();
    _loadTickets();
    _checkProfile(); //s'xecute lors de l'initialisation de la page pour faire appel a la methode qui recupere les tickets sur glpi
  }

  //recuperation du technicien authentifié
  Future<void> _loadUser() async {
    final username = await GLPIService.getUsername();
    if (!mounted) return;
    setState(() {
      //changement de  l'etat de variable par changement d'utilisateur authentifié
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

  //methode pour faire appel à la methode getmytickets de glpiservice
  Future<void> _loadTickets() async {
    final tickets = await GLPIService.getMyTickets();

    List enriched = [];

    for (var t in tickets) {
      final id = int.tryParse(t['2']
          .toString()); // récupérer l'ID du ticket de manière sécurisée et le convertir en int

      if (id != null) {
        final detail = await GLPIService.getTicketDetail(
            id); // récupérer les détails du ticket en utilisant l'ID recuperé

        enriched.add({
          'id': id,
          'title': (detail?['name'] ?? 'Sans titre').toString(),
          'description': (detail?['content'] ?? '').toString(),
          'status': detail?['status'] ?? 0,
          'priority': detail?['priority'] ?? 0,
          'date': (detail?['date_creation'] ?? '').toString(),
        });
      }
    }
    if (!mounted) return;
    setState(() {
      // mettre à jour l'état de la page avec les tickets enrichis
      _tickets = enriched;
      _isLoading = false;
    });
  }

  Color _statusColor(int status) {
    switch (status) {
      case 1:
        return Color.fromARGB(112, 4, 201, 30); // Nouveau
      case 2:
        return Color.fromARGB(255, 255, 170, 0); // En cours assigné
      case 3:
        return Color(0xFF9C27B0); // En cours planifié
      case 4:
        return Color.fromARGB(255, 216, 24, 24); // En attente
      case 5:
        return Color.fromARGB(255, 42, 84, 201); // Résolu
      case 6:
        return Color.fromARGB(197, 0, 0, 0); //fermé
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(int status) {
    switch (status) {
      case 1:
        return 'Nouveau';
      case 2:
        return 'En cours (assigné)';
      case 3:
        return 'En cours (planifié)';
      case 4:
        return 'En attente';
      case 5:
        return 'Résolu';
      case 6:
        return 'Fermé';
      default:
        return 'Inconnu';
    }
  }

  //Couleur selon La priorité
  Color _priorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.red; //Majeure
      case 2:
        return Colors.red[400]!; //tres haute
      case 3:
        return Colors.red[300]!; //haute
      case 4:
        return Colors.red[200]!; //moyenne
      case 5:
        return Colors.red[200]!; //basse
      case 6:
        return Colors.red[100]!; //Tres basse
      default:
        return Colors.black;
    }
  }

  //le label pour chaque Priorité
  String _priorityLabel(int priority) {
    switch (priority) {
      case 1:
        return 'Majeure';
      case 2:
        return 'Trés haute';
      case 3:
        return 'Haute';
      case 4:
        return 'Moyenne';
      case 5:
        return 'Basse';
      case 6:
        return 'Trés basse';

      default:
        return 'Inconnue';
    }
  }

  //classe button sur le ticket
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

//dialog apres le clique sur le ticket qui prend de temps jusqu'a la confirmation de technicien
  Future<bool?> _showConfirmDialog({
    // la methode s'attend a un clique sur oui cette comfirmation est assigne a true (bool?)
    required String title,
    required String message,
    required Color confirmColor,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: confirmColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Confirmer',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color(0xFFF0F4FF),
        appBar: AppBar(
          backgroundColor: Color.fromRGBO(22, 82, 195, 1),
          iconTheme: IconThemeData(color: Colors.white),
          title: Text(
            'Mes tickets',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),

        //le drawer
        drawer: Drawer(
            backgroundColor: Colors.white,
            child: Column(
              children: [
                UserAccountsDrawerHeader(
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(22, 82, 195, 1),
                  ),
                  accountName: Text(
                    _username,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  accountEmail: Text('$_username@dataxpress.com'),
                  currentAccountPicture: CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Text(_initiales,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ))),
                ),

                //icon home
                ListTile(
                  leading:
                      Icon(Icons.home, color: Color.fromRGBO(22, 82, 195, 1)),
                  title: Text(
                    'Accueil',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (context) => const MyTech())),
                ),

                //icon tickets active
                ListTile(
                  selected: _selectedIndex == 0, // c'est la page sélectionnée
                  selectedColor: Color.fromRGBO(22, 82, 195, 1),
                  leading: Icon(Icons.assignment,
                      color: Color.fromRGBO(22, 82, 195, 1)),
                  title: Text('Tickets',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                    leading: Icon(Icons.location_on,
                        color: Color.fromRGBO(22, 82, 195, 1)),
                    title: Text(
                      'Tracking',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () => Navigator.pop(context)),
                ListTile(
                  leading:
                      Icon(Icons.draw, color: Color.fromRGBO(22, 82, 195, 1)),
                  title: Text('Signature client',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(context),
                ),
                if(_isSupervisor)
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
                    child: GestureDetector(
                      onTap: () async {
                        await GLPIService
                            .logout(); //pour le changement de session de technicien

                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const AuthPage()));
                      },
                      //la partie où on va poser ce déconnecter
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout,
                                color: Colors.red[700], size: 18),
                            SizedBox(width: 8),
                            Text('Se déconnecter',
                                style: TextStyle(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.w500))
                          ],
                        ),
                      ),
                    ))
              ],
            )),
        //_______________BODY___________________
        //on va récuperer les tickets disponibles ou crées sur glpi ON AJOUTE APRES LA MODIFICATION DE STATUS DE TICKET
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _tickets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_turned_in,
                            size: 64, color: Colors.grey[300]),
                        SizedBox(height: 16),
                        Text('Aucun ticket assigné',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadTickets,
                    child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _tickets.length,
                        itemBuilder: (context, index) {
                          final ticket = _tickets[index];
                          ticket.forEach(
                              (key, value) => print('CHAMP $key: $value'));

                          // parsing sécurisé
                          final status =
                              int.tryParse(ticket['status'].toString()) ?? 0;
                          final priority =
                              int.tryParse(ticket['priority'].toString()) ?? 0;
                          String cleanDescription(String text) {
                            final unescape = HtmlUnescape();
                            //gestion de description de ticket

                            //  Décoder les entités HTML
                            String decoded = unescape.convert(text);

                            // Supprimer les balises HTML
                            String cleaned = decoded
                                .replaceAll(RegExp(r'<[^>]*>'), '')
                                .replaceAll('&#60;', '<')
                                .replaceAll('&#62;', '>')
                                .replaceAll('&nbsp;', ' ');

                            return cleaned.trim();
                          }

                          return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 2,
                                  child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Header : ID + badge statut
                                            Row(
                                              children: [
                                                Text(
                                                  'Ticket:${ticket['id']}', // ID du ticket
                                                  style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                                Spacer(),
                                                // badge statut coloré
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _statusColor(
                                                            status) //on peut assigner
                                                        .withOpacity(0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: _statusColor(
                                                              status),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),
                                                      SizedBox(width: 5),
                                                      Text(
                                                        _statusLabel(status),
                                                        style: TextStyle(
                                                          color: _statusColor(
                                                              status),
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 10),

                                            // Titre du ticket
                                            Text(
                                              ticket['title'] ?? 'Sans titre',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            SizedBox(height: 6),

                                            // Description nettoyée pour decoder la description envoyer par glpi et eviter les erreurs de formatage
                                            Text(
                                              cleanDescription(
                                                  // on utilise la fonction de nettoyage pour afficher une description propre et lisible
                                                  ticket['description'] ?? ''),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            SizedBox(height: 10),

                                            // Footer : priorité + date
                                            Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Footer : priorité + date
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 8,
                                                                vertical: 3),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: _priorityColor(
                                                                  priority)
                                                              .withOpacity(
                                                                  0.12),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.flag,
                                                                size: 11,
                                                                color: _priorityColor(
                                                                    priority)),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              _priorityLabel(
                                                                  priority),
                                                              style: TextStyle(
                                                                color:
                                                                    _priorityColor(
                                                                        priority),
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Spacer(),
                                                      Icon(Icons.access_time,
                                                          size: 12,
                                                          color: Colors.grey),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        (ticket['date'] !=
                                                                    null &&
                                                                ticket['date']
                                                                        .toString()
                                                                        .length >=
                                                                    10)
                                                            ? ticket['date']
                                                                .toString()
                                                                .substring(
                                                                    0, 10)
                                                            : '',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 8),
                                                  //gestion de boutton pour prendre en charge le ticket ou le marquer comme resolu ou faire signer le client selon le status du ticket
                                                  // Boutons actions sur une nouvelle ligne
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 6,
                                                    children: [
                                                      if (status == 1)
                                                        _buildActionButton(
                                                          label:
                                                              'Prendre en charge',
                                                          icon:
                                                              Icons.play_arrow,
                                                          color:
                                                              Colors.blue[700]!,
                                                          bg: Color(0xFFE3F2FD),
                                                          onTap: () async {
                                                            final confirm =
                                                                await _showConfirmDialog(
                                                              title:
                                                                  'Prendre en charge',
                                                              message:
                                                                  'Voulez-vous prendre en charge ce ticket ?',
                                                              confirmColor:
                                                                  Colors.blue[
                                                                      700]!,
                                                            );
                                                            if (confirm ==
                                                                true) {
                                                              final ticketId =
                                                                  int.tryParse(ticket[
                                                                              'id']
                                                                          .toString()) ??
                                                                      0;
                                                              final success =
                                                                  await GLPIService
                                                                      .updateTicketStatus(
                                                                          ticketId,
                                                                          2);
                                                              if (success) {
                                                                ScaffoldMessenger.of(
                                                                        context)
                                                                    .showSnackBar(
                                                                  SnackBar(
                                                                    content: Text(
                                                                        'Ticket pris en charge !'),
                                                                    backgroundColor:
                                                                        Colors.blue[
                                                                            700],
                                                                  ),
                                                                );
                                                                _loadTickets();
                                                              }
                                                            }
                                                          },
                                                        ),
                                                      if (status == 2 ||
                                                          status == 3) ...[
                                                        //si letati du ticket est 2 ou 3 donc tracker s'affiche
                                                        _buildActionButton(
                                                          label: 'Tracker',
                                                          icon:
                                                              Icons.location_on,
                                                          color: Colors
                                                              .green[700]!,
                                                          bg: Color(0xFFE8F5E9),
                                                          onTap: () {
                                                            final ticketId =
                                                                int.tryParse(ticket[
                                                                            'id']
                                                                        .toString()) ??
                                                                    0;
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) =>
                                                                    MyTrackingPage(
                                                                        ticketId:
                                                                            ticketId),
                                                              ),
                                                            );
                                                          },
                                                        ), //le technicien qui confirme que le ticket est bien resolu
                                                        _buildActionButton(
                                                          label: 'Résolu',
                                                          icon: Icons.check_box,
                                                          color: Colors
                                                              .green[800]!,
                                                          bg: Color(0xFFE8F5E9),
                                                          onTap: () async {
                                                            final confirm =
                                                                await _showConfirmDialog(
                                                              title:
                                                                  'Marquer résolu',
                                                              message:
                                                                  'Confirmer la résolution de ce ticket ?',
                                                              confirmColor:
                                                                  Colors.green[
                                                                      700]!,
                                                            );
                                                            if (confirm ==
                                                                true) {
                                                              final ticketId =
                                                                  int.tryParse(ticket[
                                                                              'id']
                                                                          .toString()) ??
                                                                      0;
                                                              final success =
                                                                  await GLPIService //l'etat de ticket change de id=2 (en cours assigné) ou id=3 (en cours planifié) à id=5 (résolu)
                                                                      .updateTicketStatus(
                                                                          ticketId,
                                                                          5);
                                                              if (success) {
                                                                ScaffoldMessenger.of(
                                                                        context)
                                                                    .showSnackBar(
                                                                  SnackBar(
                                                                    content: Text(
                                                                        'Ticket marqué comme résolu !'),
                                                                    backgroundColor:
                                                                        Colors
                                                                            .green,
                                                                  ),
                                                                );
                                                                _loadTickets();
                                                              }
                                                            }
                                                          },
                                                        ),
                                                      ],
                                                      if (status ==
                                                          5) // 5==Résolu
                                                        _buildActionButton(
                                                            label:
                                                                'Faire signer',
                                                            icon: Icons.draw,
                                                            color: Color(
                                                                0xFF3949AB),
                                                            bg: Color(
                                                                0xFFE8EAF6),
                                                            onTap: () async {
                                                              final ticketId =
                                                                  int.tryParse(ticket[
                                                                              'id']
                                                                          .toString()) ??
                                                                      0;
                                                              //on a recuperer l'etat du ticket de la page signature
                                                              final result =
                                                                  await Navigator
                                                                      .push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder:
                                                                      (context) =>
                                                                          MySignature(
                                                                    ticketId:
                                                                        ticketId,
                                                                    ticketName:
                                                                        ticket['title'] ??
                                                                            'Ticket sans titre',
                                                                  ),
                                                                ),
                                                              );
                                                              //refresh apres signature
                                                              if (result ==
                                                                      true &&
                                                                  mounted) {
                                                                _loadTickets();
                                                              }
                                                            }),
                                                    ],
                                                  )
                                                ])
                                          ]))));
                        })));
  }
}
