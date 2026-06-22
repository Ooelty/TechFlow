import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GLPIService {
  static const String baseUrl = 'http://192.168.1.7:8080/apirest.php';
  static const String appToken = '39QVq2KsvzWtOyknZ0otntYDoqwzQYyqvLjvEr2a';

  static String? get sessionToken =>
      null; // le token generer pour mon app mobile

//CONNEXION
  static Future<bool> login(String username, String password) async {
    try {
      final credentials = base64Encode(utf8.encode('$username:$password'));

      final response = await http.get(
        Uri.parse('$baseUrl/initSession'),
        headers: {
          'App-Token': appToken,
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Sauvegarde le session token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_token', data['session_token']);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Vérifie si l'utilisateur est superviseur pour afficher quelques fonctionnalités supplémentaires que pour le superviseur
  static Future<bool> isSupervisor() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? '';
    return username == 'supervisor1';
  }

  //  RÉCUPÉRER LE SESSION TOKEN ─────────────────────────
  static Future<String?> getSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_token');
  }

  // Récupérer les infos de l'utilisateur connecté
  // Récupère l'ID de l'utilisateur connecté
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final sessionToken = await getSessionToken();

      final response = await http.get(
        Uri.parse('$baseUrl/getFullSession'),
        headers: {
          'App-Token': appToken,
          'Session-Token': sessionToken ?? '',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final userId = data['session']?['glpiID'];

        if (userId != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('user_id', userId);
        }

        return data['session'];
      }

      return null;
    } catch (e) {
      return null;
    }
  }

//--------GESTION DE L'UTILISATEUR CONNECTÉ──────────────
// Sauvegarder le username au login
  static Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
  }

// Récupérer le username sauvegardé
  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username') ?? '';
  }

  // Récupère le nom d'un utilisateur par son ID pour l'afficher dans les détails du ticket
  static Future<String> getUsernameById(int userId) async {
    try {
      final sessionToken = await getSessionToken();

      final response = await http.get(
        Uri.parse('$baseUrl/User/$userId'),
        headers: {
          'App-Token': appToken,
          'Session-Token': sessionToken ?? '',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        //  data peut être une List ou une Map selon GLPI
        Map<String, dynamic> user;
        if (data is List && data.isNotEmpty) {
          user = data[0]; //si c'est une liste prend le premier
        } else if (data is Map) {
          user = Map<String, dynamic>.from(data);
        } else {
          return 'Technicien #$userId';
        }

        return user['name']?.toString() ?? 'Technicien #$userId';
      }
      return 'Technicien #$userId';
    } catch (e) {
      print('Erreur getUsernameById: $e');
      return 'Technicien #$userId';
    }
  }

//___________________
  // RÉCUPÉRER LES TICKETS ──────────────────────────────
  // Récupérer uniquement les tickets de l'utilisateur connecté

// Récupère les tickets assignés au technicien connecté
  static Future<List<dynamic>> getMyTickets() async {
    final sessionToken = await getSessionToken();
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) return [];

    final res = await http.get(
      Uri.parse(
        '$baseUrl/search/Ticket'
        '?criteria[0][field]=5'
        '&criteria[0][searchtype]=equals'
        '&criteria[0][value]=$userId'
        '&range=0-50',
      ),
      headers: {
        'App-Token': appToken,
        'Session-Token': sessionToken ?? '',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['data'];
    }

    return [];
  }

  static Future<Map<String, dynamic>?> getTicketDetail(int id) async {
    final sessionToken = await getSessionToken();

    final res = await http.get(
      Uri.parse('$baseUrl/Ticket/$id'),
      headers: {
        'App-Token': appToken,
        'Session-Token': sessionToken ?? '',
      },
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }

    return null;
  }

  // on ve recuperer le nombre de tickets crées sur glpi (count) et les projeter sur la page home pour avoir une sychronisation
  static Future<Map<String, int>> getTicketsCount() async {
    try {
      final sessionToken = await getSessionToken();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      //la requete (url)
      final response = await http.get(
          Uri.parse(
              '$baseUrl/search/Ticket?criteria[0][field]=5&criteria[0][searchtype]=equals&criteria[0][value]=$userId&range=0-1000&expand_dropdowns=true'),
          headers: {
            'App-Token': appToken,
            'Session-Token': sessionToken ?? '',
            'Content-Type': 'application/json',
          });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tickets = data['data'] ?? [];
        final total = data['totalcount'] ?? 0;
        final signed = data['data']
                ?.where((ticket) => int.tryParse(ticket['12'].toString()) == 6)
                .length ??
            0;

        int enCours = 0;
        for (var ticket in tickets) {
          final status = int.tryParse(ticket['12'].toString()) ?? 0;
          if (status == 2 || status == 3) enCours++;
        }

        return {'total': total, 'enCours': enCours, 'signés': signed};
      }
      return {'total': 0, 'enCours': 0, 'signés': 0};
    } catch (e) {
      return {'total': 0, 'enCours': 0, 'signés': 0};
    }
  }

  // ── METTRE À JOUR LE STATUT D'UN TICKET ────────────────
  static Future<bool> updateTicketStatus(int ticketId, int status) async {
    try {
      final sessionToken = await getSessionToken();

      final response = await http.put(
        Uri.parse('$baseUrl/Ticket/$ticketId'),
        headers: {
          'App-Token': appToken,
          'Session-Token': sessionToken ?? '',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'input': {
            'status': status,
          }
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  //status 1 : nouveau
  //status 2 : en cours
  //status 3 : résolu
  //status 5 : fermé

  //Gestion de Signature
  static Future<bool> uploadSignatureDocument({
    required int ticketId,
    required Uint8List imageBytes,
  }) async {
    try {
      final sessionToken = await getSessionToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/Document'),
      );

      request.headers.addAll({
        'App-Token': appToken,
        'Session-Token': sessionToken ?? '',
      });

      request.fields['uploadManifest'] = jsonEncode({
        'input': {
          'name': 'signature_ticket_$ticketId',
          '_filename': ['signature_ticket_$ticketId.png'],
        }
      });

      request.files.add(
        http.MultipartFile.fromBytes(
          '_filename[0]',
          imageBytes,
          filename: 'signature_ticket_$ticketId.png',
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      print('DOCUMENT STATUS: ${response.statusCode}');
      print('DOCUMENT BODY: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        final documentId = int.tryParse(data['id'].toString()) ?? 0;

        print('DOCUMENT ID: $documentId');

        if (documentId == 0) return false;

        final linkResponse = await http.post(
          Uri.parse('$baseUrl/Document_Item'),
          headers: {
            'App-Token': appToken,
            'Session-Token': sessionToken ?? '',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'input': {
              'documents_id': documentId,
              'itemtype': 'Ticket',
              'items_id': ticketId,
            }
          }),
        );

        if (linkResponse.statusCode != 200 && linkResponse.statusCode != 201) {
          return false;
        }

        // Ajouter la signature en base64 dans un followup pour un accès direct
        final base64Signature = base64Encode(imageBytes);
        final followupResponse = await http.post(
          Uri.parse('$baseUrl/ITILFollowup'),
          headers: {
            'App-Token': appToken,
            'Session-Token': sessionToken ?? '',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'input': {
              'itemtype': 'Ticket',
              'items_id': ticketId,
              'content': 'SIGNATURE_BASE64:$base64Signature',
              'is_private': 0,
            }
          }),
        );

        print('FOLLOWUP SIGNATURE STATUS: ${followupResponse.statusCode}');
        return followupResponse.statusCode == 200 ||
            followupResponse.statusCode == 201;
      }

      return false;
    } catch (e) {
      print('Erreur uploadSignatureDocument: $e');
      return false;
    }
  }

// Récupère la signature
  static Future<String?> getTicketSignature(int ticketId) async {
    try {
      final sessionToken = await getSessionToken();

      // ── MÉTHODE 1 : Followups (nouvelle approche SIGNATURE_BASE64) ──
      final followupUri = Uri.parse(
        '$baseUrl/ITILFollowup'
        '?itemtype=Ticket'
        '&items_id=$ticketId'
        '&range=0-100'
        '&order=DESC'
        '&sort=id',
      );
      final followupResponse = await http.get(
        followupUri,
        headers: {
          'App-Token': appToken,
          'Session-Token': sessionToken ?? '',
        },
      );

      if (followupResponse.statusCode == 200) {
        final responseBody = jsonDecode(followupResponse.body);
        final followups = responseBody is List
            ? responseBody
            : (responseBody is Map && responseBody['data'] is List)
                ? responseBody['data'] as List
                : <dynamic>[];

        for (var followup in followups) {
          if (followup is! Map) continue;
          final itemtype = followup['itemtype']?.toString() ?? '';
          final itemsId =
              int.tryParse(followup['items_id']?.toString() ?? '0') ?? 0;
          if (itemtype.toLowerCase() != 'ticket' || itemsId != ticketId) {
            continue;
          }

          final content = followup['content']?.toString() ?? '';
          final cleaned = content
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .replaceAll('&nbsp;', '')
              .trim();
          if (cleaned.startsWith('SIGNATURE_BASE64:')) {
            return cleaned.replaceFirst('SIGNATURE_BASE64:', '').trim();
          }
        }
      }

      // Fallback : l'API peut ne pas filtrer correctement par itemtype/items_id.
      final fallbackResponse = await http.get(
        Uri.parse('$baseUrl/ITILFollowup?range=0-100&order=DESC&sort=id'),
        headers: {
          'App-Token': appToken,
          'Session-Token': sessionToken ?? '',
        },
      );

      if (fallbackResponse.statusCode == 200) {
        final fallbackBody = jsonDecode(fallbackResponse.body);
        final fallbackFollowups = fallbackBody is List
            ? fallbackBody
            : (fallbackBody is Map && fallbackBody['data'] is List)
                ? fallbackBody['data'] as List
                : <dynamic>[];

        for (var followup in fallbackFollowups) {
          if (followup is! Map) continue;
          final itemtype = followup['itemtype']?.toString() ?? '';
          final itemsId =
              int.tryParse(followup['items_id']?.toString() ?? '0') ?? 0;
          if (itemtype != 'Ticket' || itemsId != ticketId) continue;

          final content = followup['content']?.toString() ?? '';
          final cleaned = content
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .replaceAll('&nbsp;', '')
              .trim();
          if (cleaned.startsWith('SIGNATURE_BASE64:')) {
            return cleaned.replaceFirst('SIGNATURE_BASE64:', '').trim();
          }
        }
      }

      final documentSignature = await getTicketSignatureFromDocument(ticketId);
      if (documentSignature != null) {
        return documentSignature;
      }

      print('Aucune signature trouvée pour ticket $ticketId');
      return null;
    } catch (e) {
      print('Erreur getTicketSignature: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _getDocumentItemsForTicket(
      int ticketId) async {
    try {
      final sessionToken = await getSessionToken();
      final response = await http.get(
        Uri.parse('$baseUrl/Document_Item?range=0-100'),
        headers: {
          'App-Token': appToken,
          'Session-Token': sessionToken ?? '',
        },
      );

      if (response.statusCode != 200) {
        return [];
      }

      final body = jsonDecode(response.body);
      final list = body is List
          ? body
          : (body is Map && body['data'] is List)
              ? body['data'] as List
              : <dynamic>[];

      return list.whereType<Map<String, dynamic>>().where((item) {
        final itemtype = item['itemtype']?.toString() ?? '';
        final itemsId = int.tryParse(item['items_id']?.toString() ?? '0') ?? 0;
        return itemtype.toLowerCase() == 'ticket' && itemsId == ticketId;
      }).toList();
    } catch (e) {
      print('Erreur _getDocumentItemsForTicket: $e');
      return [];
    }
  }

  static Future<String?> getTicketSignatureFromDocument(int ticketId) async {
    try {
      final sessionToken = await getSessionToken();
      final docs = await _getDocumentItemsForTicket(ticketId);

      if (docs.isEmpty) {
        return null;
      }

      final signaturePattern = 'signature_ticket_$ticketId'.toLowerCase();
      final exactSignatureDocs = docs.where((item) {
        final name = item['name']?.toString().toLowerCase() ?? '';
        final realname = item['realname']?.toString().toLowerCase() ?? '';
        return name.contains(signaturePattern) ||
            realname.contains(signaturePattern);
      }).toList();

      final signatureDocs = exactSignatureDocs.isNotEmpty
          ? exactSignatureDocs
          : docs.where((item) {
              final name = item['name']?.toString().toLowerCase() ?? '';
              final realname = item['realname']?.toString().toLowerCase() ?? '';
              return name.contains('signature') ||
                  realname.contains('signature');
            }).toList();

      if (signatureDocs.isEmpty) {
        return null;
      }

      for (var item in signatureDocs) {
        final documentId =
            int.tryParse(item['documents_id']?.toString() ?? '0') ?? 0;
        if (documentId == 0) continue;

        print(
            'DEBUG: getTicketSignatureFromDocument: trying documentId $documentId for ticket $ticketId');

        final downloadResponse = await http.get(
          Uri.parse('$baseUrl/Document/$documentId?download=1'),
          headers: {
            'App-Token': appToken,
            'Session-Token': sessionToken ?? '',
            'Content-Type': 'application/json',
          },
        );

        if (downloadResponse.statusCode == 200 &&
            downloadResponse.bodyBytes.isNotEmpty) {
          print(
              'DEBUG: downloaded document $documentId bytes=${downloadResponse.bodyBytes.length}');
          return base64Encode(downloadResponse.bodyBytes);
        } else {
          print(
              'DEBUG: failed download for document $documentId status=${downloadResponse.statusCode} bytes=${downloadResponse.bodyBytes.length}');
        }

        final baseServer = baseUrl.replaceAll('/apirest.php', '');
        final fileResponse = await http.get(
          Uri.parse('$baseServer/front/document.send.php?docid=$documentId'),
          headers: {
            'App-Token': appToken,
            'Session-Token': sessionToken ?? '',
          },
        );

        if (fileResponse.statusCode == 200 &&
            fileResponse.bodyBytes.isNotEmpty) {
          print(
              'DEBUG: fallback downloaded document $documentId bytes=${fileResponse.bodyBytes.length}');
          return base64Encode(fileResponse.bodyBytes);
        } else {
          print(
              'DEBUG: fallback failed for document $documentId status=${fileResponse.statusCode} bytes=${fileResponse.bodyBytes.length}');
        }
      }

      return null;
    } catch (e) {
      print('Erreur getTicketSignatureFromDocument: $e');
      return null;
    }
  }

  // Returns both the base64 signature and the document id when available
  static Future<Map<String, dynamic>?> getTicketSignatureFromDocumentInfo(
      int ticketId) async {
    try {
      final sessionToken = await getSessionToken();
      final docs = await _getDocumentItemsForTicket(ticketId);

      if (docs.isEmpty) return null;

      final signaturePattern = 'signature_ticket_$ticketId'.toLowerCase();
      final exactSignatureDocs = docs.where((item) {
        final name = item['name']?.toString().toLowerCase() ?? '';
        final realname = item['realname']?.toString().toLowerCase() ?? '';
        return name.contains(signaturePattern) ||
            realname.contains(signaturePattern);
      }).toList();

      final signatureDocs = exactSignatureDocs.isNotEmpty
          ? exactSignatureDocs
          : docs.where((item) {
              final name = item['name']?.toString().toLowerCase() ?? '';
              final realname = item['realname']?.toString().toLowerCase() ?? '';
              return name.contains('signature') ||
                  realname.contains('signature');
            }).toList();

      if (signatureDocs.isEmpty) return null;

      for (var item in signatureDocs) {
        final documentId =
            int.tryParse(item['documents_id']?.toString() ?? '0') ?? 0;
        if (documentId == 0) continue;

        final downloadResponse = await http.get(
          Uri.parse('$baseUrl/Document/$documentId?download=1'),
          headers: {
            'App-Token': appToken,
            'Session-Token': sessionToken ?? '',
            'Content-Type': 'application/json',
          },
        );

        if (downloadResponse.statusCode == 200 &&
            downloadResponse.bodyBytes.isNotEmpty) {
          return {
            'base64': base64Encode(downloadResponse.bodyBytes),
            'document_id': documentId
          };
        }

        final baseServer = baseUrl.replaceAll('/apirest.php', '');
        final fileResponse = await http.get(
          Uri.parse('$baseServer/front/document.send.php?docid=$documentId'),
          headers: {
            'App-Token': appToken,
            'Session-Token': sessionToken ?? '',
          },
        );

        if (fileResponse.statusCode == 200 &&
            fileResponse.bodyBytes.isNotEmpty) {
          return {
            'base64': base64Encode(fileResponse.bodyBytes),
            'document_id': documentId
          };
        }
      }

      return null;
    } catch (e) {
      print('Erreur getTicketSignatureFromDocumentInfo: $e');
      return null;
    }
  }

  static Future<List<int>> getDocumentIdsForTicket(int ticketId) async {
    try {
      final docs = await _getDocumentItemsForTicket(ticketId);
      return docs
          .whereType<Map>()
          .map<int?>(
              (item) => int.tryParse(item['documents_id']?.toString() ?? '0'))
          .where((id) => id != null)
          .cast<int>()
          .toList();
    } catch (e) {
      print('Erreur getDocumentIdsForTicket: $e');
      return [];
    }
  }

// Récupère les tickets fermés avec signatures
  static Future<List<Map<String, dynamic>>>
      getClosedTicketsWithSignatures() async {
    try {
      final sessionToken = await getSessionToken();

      final response = await http.get(
        Uri.parse(
          '$baseUrl/search/Ticket'
          '?criteria[0][field]=12'
          '&criteria[0][searchtype]=equals'
          '&criteria[0][value]=6'
          '&range=0-100'
          '&expand_dropdowns=true',
        ),
        headers: {
          'App-Token': appToken,
          'Session-Token': sessionToken ?? '',
        },
      );

      print('CLOSED TICKETS status: ${response.statusCode}');

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final tickets = data['data'] ?? [];

      List<Map<String, dynamic>> result = [];

      for (var t in tickets) {
        final id = int.tryParse(t['2']?.toString() ?? '') ?? 0;
        if (id == 0) continue;

        // Récupère les détails du ticket
        final detail = await getTicketDetail(id);
        if (detail == null) continue;

        // Récupère le technicien assigné
        final userId = int.tryParse(
              detail['users_id_lastupdater']?.toString() ?? '0',
            ) ??
            0;
        final technicianName =
            userId != 0 ? await getUsernameById(userId) : 'N/A';

        // Récupère la signature depuis les followups
        // Récupère la signature
        String? signatureBase64;
        try {
          signatureBase64 = await getTicketSignature(id);
        } catch (e) {
          signatureBase64 = null;
        }

        result.add({
          'id': id,
          'title': detail['name'] ?? 'Sans titre',
          'description': detail['content'] ?? '',
          'priority': detail['priority'] ?? 0,
          'date_creation': detail['date_creation'] ?? '',
          'date_closing': detail['closedate'] ?? '',
          'technician': technicianName,
          'has_signature': signatureBase64 != null,
          'signature': signatureBase64, //  base64 string
        });
      }

      print('TICKETS FERMÉS: ${result.length}');
      return result;
    } catch (e) {
      print('Erreur getClosedTicketsWithSignatures: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>>
      getClosedTicketsWithDocumentSignatures() async {
    try {
      final sessionToken = await getSessionToken();

      final response = await http.get(
        Uri.parse(
          '$baseUrl/search/Ticket'
          '?criteria[0][field]=12'
          '&criteria[0][searchtype]=equals'
          '&criteria[0][value]=6'
          '&range=0-100'
          '&expand_dropdowns=true',
        ),
        headers: {
          'App-Token': appToken,
          'Session-Token': sessionToken ?? '',
        },
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final tickets = data['data'] ?? [];
      final List<Map<String, dynamic>> result = [];

      for (var t in tickets) {
        final id = int.tryParse(t['2']?.toString() ?? '') ?? 0;
        if (id == 0) continue;

        final detail = await getTicketDetail(id);
        if (detail == null) continue;

        final userId =
            int.tryParse(detail['users_id_lastupdater']?.toString() ?? '0') ??
                0;
        final technicianName =
            userId != 0 ? await getUsernameById(userId) : 'N/A';

        final documentIds = await getDocumentIdsForTicket(id);
        print('DEBUG: Ticket $id documentIds: $documentIds');

        String? signatureBase64;
        int? signatureDocId;
        try {
          // Prefer followup-based signature (SIGNATURE_BASE64 in ITILFollowup)
          signatureBase64 = await getTicketSignature(id);
        } catch (e) {
          signatureBase64 = null;
        }

        if (signatureBase64 == null) {
          final signatureInfo = await getTicketSignatureFromDocumentInfo(id);
          signatureBase64 = signatureInfo?['base64'];
          signatureDocId = signatureInfo?['document_id'];
        }

        print(
            'DEBUG: Ticket $id signature_doc_id: $signatureDocId signature_found: ${signatureBase64 != null}');

        result.add({
          'id': id,
          'title': detail['name'] ?? 'Sans titre',
          'description': detail['content'] ?? '',
          'priority': detail['priority'] ?? 0,
          'date_creation': detail['date_creation'] ?? '',
          'date_closing': detail['closedate'] ?? '',
          'technician': technicianName,
          'document_ids': documentIds,
          'has_signature': signatureBase64 != null,
          'signature': signatureBase64,
          'signature_doc_id': signatureDocId,
        });
      }

      return result;
    } catch (e) {
      print('Erreur getClosedTicketsWithDocumentSignatures: $e');
      return [];
    }
  }

  // ── DÉCONNEXION ────────────────────────────────────────
  static Future<void> logout() async {
    try {
      final sessionToken = await getSessionToken();

      await http.get(
        Uri.parse('$baseUrl/killSession'),
        headers: {
          'App-Token': appToken,
          'Session-Token': sessionToken ?? '',
        },
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_token');
    } catch (e) {
      // ignore
    }
  }

  //Gestion de tracking
  static Future<bool> sendLocation({
    required int ticketId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final sessionToken = await getSessionToken();

      // Formate l'heure actuelle
      final now = DateTime.now();
      final formattedTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      // Envoie la position comme note (followup) sur le ticket
      final response = await http.post(
        Uri.parse('$baseUrl/ITILFollowup'),
        headers: {
          'App-Token': appToken,
          'Session-Token': sessionToken ?? '',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'input': {
            'itemtype': 'Ticket', // lié à un ticket
            'items_id': ticketId, // ID du ticket
            'content': ' Position technicien à $formattedTime\n'
                'Latitude: $latitude\n'
                'Longitude: $longitude\n'
                'Google Maps: https://maps.google.com/?q=$latitude,$longitude',
            'is_private':
                1, // note privée (visible que par les techniciens/admins)
          }
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

//gestion d'eplacement des tickets
  static Future<Map<String, dynamic>?> getLocationById(int id) async {
    final sessionToken = await getSessionToken();

    final response = await http.get(
      Uri.parse('$baseUrl/Location/$id?expand_dropdowns=true'),
      headers: {
        'App-Token': appToken,
        'Session-Token': sessionToken ?? '',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    return null;
  }
}
