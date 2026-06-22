import 'package:flutter/material.dart';

import 'package:app_mobile/authentification.dart';

void main() {
  runApp(Xapp()); //lapp
}

class Xapp extends StatelessWidget {
  const Xapp({super.key});

  //tous les elements qui vont etre executer lors du demarrage vont etre ecrit ici

  @override //permet d'eliminer la duplication de quelque methode lors de leurs utilisation dans le code
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner:
          false, //on va eliminer le debug  en haut à droite
      home: AuthPage(),
    ); // on va initialiser home page ici avec son importation
  }
}
