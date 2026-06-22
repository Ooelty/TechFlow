import 'dart:typed_data';

import 'package:app_mobile/services/glpi_services.dart';
import 'package:app_mobile/tickets.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart'; //import de la librairie pour la signature

class MySignature extends StatefulWidget {
  final int ticketId;
  final String ticketName;

  const MySignature(
      {super.key, required this.ticketId, required this.ticketName});

  @override
  State<MySignature> createState() => SignatureState();
}

class SignatureState extends State<MySignature> {
  //____________les variables pour la signature____________________
  final SignatureController _controller = SignatureController(
      //zone de signature
      penStrokeWidth: 3, //épaisseur du trait
      penColor: Colors.black, //couleur de trait
      exportBackgroundColor: Colors.white //fond blan pour lexport
      );
  bool _isSaving = false; //indique si la signature est en cours de sauvegarde
  bool _hasSignature = false; //indique si le client à signé
  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      //écoute les changements dans la zone de signature
      setState(() {
        _hasSignature = _controller.isNotEmpty; //vérifie si le client à signé
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose(); //libère les ressources utilisées par le controller
    super.dispose();
  }

  //___________Dialog de changement de status de ticket apres signature du client
  Future<void> _showStatusChangeDialog() async {
    int? selectedStatus;
    await showDialog(
      context: context,
      barrierDismissible: false, //oblige à choisir un status
      builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
        //changement d'etat de ticket avec setstatedialog
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                  16)), //la forme de alert dialog qui va s'affiche au tech
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
              ),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Signature enregistrée!',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Changer le status de ticket:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              SizedBox(height: 16),
              _buildStatusOption(setStateDialog,
                  status: 5,
                  label: 'Résolu',
                  description: 'Intervention terminée avec succés',
                  color: Colors.blue,
                  icon: Icons.check_circle_outline,
                  selectedStatus: selectedStatus,
                  onSelect: (val) => selectedStatus = val),
              SizedBox(height: 8),
              //option Fermé
              _buildStatusOption(
                setStateDialog,
                status: 6,
                label: 'Fermé',
                description: 'Ticket fermé definitivement',
                color: Colors.black,
                icon: Icons.lock_clock_outlined,
                selectedStatus: selectedStatus,
                onSelect: (val) => selectedStatus = val,
              ),
              SizedBox(height: 8),
              //option En attente
              _buildStatusOption(
                setStateDialog,
                status: 4,
                label: 'En attente',
                description: 'En attente d\'une autre action',
                color: Colors.orange,
                icon: Icons.pause_circle_outline,
                selectedStatus: selectedStatus,
                onSelect: (val) => selectedStatus = val,
              ),
            ],
          ),
          //button ignorer
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Ignorer', style: TextStyle(color: Colors.grey)),
            ),
            GestureDetector(
              onTap: selectedStatus == null
                  ? null
                  : () async {
                      //changement de status de tciket sur glpi
                      final success = await GLPIService.updateTicketStatus(
                          widget.ticketId, selectedStatus!);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Status mis à jour avec succès!'
                                : 'Erreur lors de la mise à jour',
                          ),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                      //retourne à la page de tickets si true §§!!!!!
                      if (success && mounted) {
                        Navigator.pop(context); // ferme le dialog //puis navigue vers la page de tickets on envoyant les details de ticket pour afficher les tickets mis à jour
                        Navigator.pushReplacement(
                          // remplace push par pushReplacement
                          context,
                          MaterialPageRoute(builder: (context) => MyTicket()),
                        );
                      }
                    },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: selectedStatus == null
                      ? Colors.grey[300]
                      : Color.fromRGBO(22, 82, 195, 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Confirmer', //Button confirmer
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            )
          ],
        );
      }),
    );
  }

  ////______________WIDGET OPTION STATUS_________________
  Widget _buildStatusOption(StateSetter setStateDialog,
      {required int status,
      required String label,
      required String description,
      required Color color,
      required IconData icon,
      required int? selectedStatus,
      required Function(int) onSelect}) {
    final isSelected = selectedStatus == status;
    return GestureDetector(
      onTap: () => setStateDialog(() => onSelect(status)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? color : Colors.grey.shade200,
              width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 20,
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400)),
                SizedBox(height: 4),
                Text(description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  //______Sauvegarde de la signature
  Future<void> _saveSignature() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez signer avant de valider'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final Uint8List? imageBytes = await _controller.toPngBytes();

      if (imageBytes == null) {
        throw Exception("Erreur export signature");
      }

      final success = await GLPIService.uploadSignatureDocument(
        ticketId: widget.ticketId,
        imageBytes: imageBytes,
      );

      if (!mounted) return;

      if (success) {
        await _showStatusChangeDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement de la signature'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color(0xFFF0F4FF),
        appBar: AppBar(
          backgroundColor: Color.fromRGBO(22, 81, 195, 1),
          iconTheme: IconThemeData(color: Colors.white),
          title: Text('Signature client',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //info de ticket
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Color(0xFFE8EAF6),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(
                          Icons.assignment,
                          color: Color.fromRGBO(22, 82, 195, 1),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ticket:${widget.ticketId}',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            widget.ticketName,
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ))
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Text('Signature du client',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[900],
                    )),
                SizedBox(height: 6),
                Text(
                  'Veuiller signer ici',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                SizedBox(height: 16),
                //___________ZONE DE SIGNATURE__________________
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      // Bordure bleue si le client a commencé à signer
                      color: _hasSignature
                          ? Color.fromRGBO(22, 82, 195, 1)
                          : Colors.grey.shade300,
                      width: _hasSignature ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        // Zone de dessin de la signature
                        Signature(
                          controller: _controller,
                          height: 220,
                          backgroundColor: Colors.white,
                        ),
                        // Placeholder "Signez ici" si pas encore signé
                        if (!_hasSignature)
                          Positioned.fill(
                              child: IgnorePointer(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.draw_outlined,
                                      size: 32, color: Colors.grey[300]),
                                  SizedBox(height: 8),
                                  Text(
                                    'Signez ici',
                                    style: TextStyle(
                                      color: Colors.grey[300],
                                      fontSize: 14,
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ))
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                //___________BUTTONS____________________
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    //button effacer
                    TextButton.icon(
                      onPressed: _controller.clear, //efface la signature
                      icon: Icon(Icons.delete_outline, color: Colors.red),
                      label:
                          Text('Effacer', style: TextStyle(color: Colors.red)),
                    ),
                    //button valider
                    ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : _saveSignature, //sauvegarde la signature
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromRGBO(22, 82, 195, 1),
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ))
                          : Text('Valider',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500)),
                    )
                  ],
                )
              ],
            )));
  }
}
