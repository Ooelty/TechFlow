import 'package:flutter/material.dart';
import 'package:app_mobile/services/glpi_services.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:app_mobile/tickets.dart';
import 'package:app_mobile/techhome.dart';
import 'package:app_mobile/signature.dart';
import 'package:app_mobile/authentification.dart';
import 'dart:convert';

String normalizeBase64(String base64Data) {
  var cleaned = base64Data;

  if (cleaned.contains('SIGNATURE_BASE64:')) {
    cleaned = cleaned.substring(
        cleaned.indexOf('SIGNATURE_BASE64:') + 'SIGNATURE_BASE64:'.length);
  }

  final prefixIndex = cleaned.indexOf('base64,');
  if (prefixIndex >= 0) {
    cleaned = cleaned.substring(prefixIndex + 'base64,'.length);
  }

  cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
  cleaned = cleaned.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');

  // Add proper padding for base64 decoding
  final remainder = cleaned.length % 4;
  if (remainder != 0) {
    cleaned += '=' * (4 - remainder);
  }

  return cleaned;
}

bool isValidBase64(String value) {
  if (value.isEmpty) return false;
  try {
    base64Decode(value);
    return true;
  } catch (_) {
    return false;
  }
}

Widget buildInfoRow(IconData icon, String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: Colors.grey),
      SizedBox(width: 6),
      Text(
        '$label : ',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

class ClosedTicketsPage extends StatefulWidget {
  const ClosedTicketsPage({super.key});

  @override
  State<ClosedTicketsPage> createState() => _ClosedTicketsPageState();
}

class _ClosedTicketsPageState extends State<ClosedTicketsPage> {
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = true;
  String _username = '';
  String _initiales = '';
  bool _isSupervisor = false;
  final _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _checkProfileAndLoad();
  }

  Future<void> _checkProfileAndLoad() async {
    final isSup = await GLPIService.isSupervisor();
    if (!mounted) return;

    if (!isSup) {
      // Rediriger les non-superviseurs
      final navigator = Navigator.of(context);
      navigator.pushReplacement(
        MaterialPageRoute(builder: (context) => const MyTech()),
      );
      return;
    }

    setState(() => _isSupervisor = true);
    _loadClosedTickets();
  }

  Future<void> _loadClosedTickets() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final tickets = await GLPIService.getClosedTicketsWithDocumentSignatures();
    if (!mounted) return;
    setState(() {
      _tickets = tickets;
      _isLoading = false;
    });
  }

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

  // Nettoie le HTML de la description
  String _cleanDescription(String text) {
    final unescape = HtmlUnescape();
    return unescape
        .convert(text)
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  // Couleur selon la priorité
  Color _priorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.red[400]!;
      case 3:
        return Colors.red[300]!;
      case 4:
        return Colors.red[200]!;
      case 5:
        return Colors.red[200]!;
      case 6:
        return Colors.red[200]!;
      default:
        return Colors.grey;
    }
  }

  String _priorityLabel(int priority) {
    switch (priority) {
      case 1:
        return 'Majeure';
      case 2:
        return 'Très haute';
      case 3:
        return 'Haute';
      case 4:
        return 'Moyenne';
      case 5:
        return 'Basse';
      case 6:
        return 'Très basse';
      default:
        return 'Inconnue';
    }
  }

  // Affiche la signature dans un dialog
  void _showSignatureDialog(Map<String, dynamic> ticket) {
    showDialog(
      context: context,
      builder: (context) => _SignatureDialog(ticket: ticket),
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
          'Tickets fermés',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadClosedTickets,
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Color.fromRGBO(22, 82, 195, 1)),
              accountName: Text(_username,
                  style: TextStyle(fontWeight: FontWeight.w500)),
              accountEmail: Text('$_username@dataxpress.com'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white24,
                child: Text(
                  _initiales,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home, color: Color.fromRGBO(22, 82, 195, 1)),
              title: Text('Accueil',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MyTech()),
              ),
            ),
            ListTile(
              leading:
                  Icon(Icons.assignment, color: Color.fromRGBO(22, 82, 195, 1)),
              title: Text('Tickets',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MyTicket()),
              ),
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
                  builder: (context) =>
                      MySignature(ticketId: 0, ticketName: ''),
                ),
              ),
            ),
            if (_isSupervisor)
              ListTile(
                selected: _selectedIndex == 0,
                leading:
                    Icon(Icons.lock, color: Color.fromRGBO(22, 82, 195, 1)),
                title: Text('Tickets signés',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ClosedTicketsPage()),
                ),
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
                  final navigator = Navigator.of(context);
                  await GLPIService.logout();
                  if (!mounted) return;
                  navigator.pushReplacement(
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
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _tickets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, size: 64, color: Colors.grey[300]),
                      SizedBox(height: 16),
                      Text('Aucun ticket fermé',
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadClosedTickets,
                  child: ListView.builder(
                    padding: EdgeInsets.all(12),
                    itemCount: _tickets.length,
                    itemBuilder: (context, index) {
                      final ticket = _tickets[index];
                      final priority =
                          int.tryParse(ticket['priority'].toString()) ?? 0;

                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Row(
                                  children: [
                                    Text(
                                      'Ticket #${ticket['id']}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Spacer(),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color.fromRGBO(
                                            117, 117, 117, 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: Color(0xFF757575),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            'Fermé',
                                            style: TextStyle(
                                              color: Color(0xFF757575),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10),

                                // Titre
                                Text(
                                  ticket['title'] ?? 'Sans titre',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 6),

                                // Description
                                Text(
                                  _cleanDescription(
                                      ticket['description'] ?? ''),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                ),
                                SizedBox(height: 10),

                                // Footer priorité + date
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        // ignore: deprecated_member_use
                                        color: _priorityColor(priority)
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.flag,
                                              size: 11,
                                              color: _priorityColor(priority)),
                                          SizedBox(width: 4),
                                          Text(
                                            _priorityLabel(priority),
                                            style: TextStyle(
                                              color: _priorityColor(priority),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Spacer(),
                                    Icon(Icons.access_time,
                                        size: 12, color: Colors.grey),
                                    SizedBox(width: 4),
                                    Text(
                                      ticket['date_creation']
                                                  .toString()
                                                  .length >=
                                              10
                                          ? ticket['date_creation']
                                              .toString()
                                              .substring(0, 10)
                                          : '',
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10),

                                // Badge signature + bouton voir
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: ticket['has_signature'] == true
                                            ? Color(0xFFE8F5E9)
                                            : Colors.orange[50],
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: ticket['has_signature'] == true
                                              ? Colors.green.shade200
                                              : Colors.orange.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            ticket['has_signature'] == true
                                                ? Icons.verified
                                                : Icons.warning_amber,
                                            size: 14,
                                            color:
                                                ticket['has_signature'] == true
                                                    ? Colors.green[700]
                                                    : Colors.orange[700],
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            ticket['has_signature'] == true
                                                ? 'Signé ✓'
                                                : 'Non signé',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: ticket['has_signature'] ==
                                                      true
                                                  ? Colors.green[700]
                                                  : Colors.orange[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _showSignatureDialog(ticket),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Color(0xFFE8EAF6),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.image_search,
                                                size: 14,
                                                color: Color(0xFF3949AB)),
                                            SizedBox(width: 4),
                                            Text(
                                              'Voir',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF3949AB),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _SignatureDialog extends StatefulWidget {
  final Map<String, dynamic> ticket;

  const _SignatureDialog({required this.ticket});

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  bool _isLoading = false;
  String? _signature;
  String? _error;

  @override
  void initState() {
    super.initState();
    _signature = widget.ticket['signature']?.toString();
    final normalized = _signature != null ? normalizeBase64(_signature!) : '';
    if (normalized.isEmpty || !isValidBase64(normalized)) {
      _loadSignature();
    }
  }

  Future<void> _loadSignature() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ticketId =
          int.tryParse(widget.ticket['id']?.toString() ?? '0') ?? 0;
      if (ticketId > 0) {
        final signature = await GLPIService.getTicketSignature(ticketId);
        if (signature != null && signature.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _signature = signature;
            widget.ticket['signature'] = signature;
            widget.ticket['has_signature'] = true;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger la signature';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getNormalizedSignature() {
    final raw = _signature ?? widget.ticket['signature']?.toString() ?? '';
    return raw.isNotEmpty ? normalizeBase64(raw) : '';
  }

  Widget _buildSignatureImage(String base64String) {
    try {
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.red, size: 32),
                SizedBox(height: 8),
                Text('Erreur décodage signature',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ),
          );
        },
      );
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: Colors.red, size: 32),
            SizedBox(height: 8),
            Text('Erreur décodage signature',
                style: TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final signatureValue = _getNormalizedSignature();
    final hasSignature = signatureValue.isNotEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(Icons.draw, color: Color.fromRGBO(22, 82, 195, 1)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Signature — Ticket #${widget.ticket['id']}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildInfoRow(
                      Icons.title, 'Titre', widget.ticket['title'] ?? ''),
                  SizedBox(height: 6),
                  buildInfoRow(Icons.person, 'Technicien',
                      widget.ticket['technician'] ?? 'N/A'),
                  SizedBox(height: 6),
                  buildInfoRow(
                    Icons.calendar_today,
                    'Créé le',
                    widget.ticket['date_creation'].toString().length >= 10
                        ? widget.ticket['date_creation']
                            .toString()
                            .substring(0, 10)
                        : 'N/A',
                  ),
                  SizedBox(height: 6),
                  buildInfoRow(
                    Icons.lock,
                    'Fermé le',
                    widget.ticket['date_closing'].toString().isNotEmpty &&
                            widget.ticket['date_closing'].toString().length >=
                                10
                        ? widget.ticket['date_closing']
                            .toString()
                            .substring(0, 10)
                        : 'N/A',
                  ),
                  if ((widget.ticket['document_ids'] as List<dynamic>?)
                          ?.isNotEmpty ==
                      true) ...[
                    SizedBox(height: 6),
                    buildInfoRow(
                      Icons.insert_drive_file,
                      'Documents',
                      (widget.ticket['document_ids'] as List<dynamic>)
                          .map((id) => id.toString())
                          .join(', '),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Signature du client :',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.blue[900],
              ),
            ),
            SizedBox(height: 8),
            if (_isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Chargement de la signature...'),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.orange[700], fontSize: 13),
                ),
              )
            else if (hasSignature)
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildSignatureImage(signatureValue),
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aucune signature disponible',
                        style:
                            TextStyle(color: Colors.orange[700], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 12),
            if (hasSignature)
              Row(
                children: [
                  Icon(Icons.verified, color: Colors.green, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Signature validée par le client',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Fermer', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
