import 'package:app_mobile/services/glpi_services.dart';
import 'package:app_mobile/techhome.dart';
import 'package:flutter/material.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _MyWidgetState();
}

//controllers pour allouer l'espace memoire aux valeur entrées
class _MyWidgetState extends State<AuthPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _errorMessage;
  bool boolLoading = false;
  //fct qui gere le mot de passe et email saisie
  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    //connexion avec glpi et appel a la methode login creer dans le service
    final success = await GLPIService.login(username, password);

    //direction vers la page home si les infos entrés sont deja compatibles avec les infos sur glpi
    if (!mounted) return;

    if (success) {
      await GLPIService.saveUsername(username);
      await GLPIService
          .getCurrentUser(); //pour faire appel a la methode qui recupere le username authentifié
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MyTech()),
      );
    } else {
      setState(() {
        _errorMessage = 'username ou mot de passe incorrect';
        boolLoading = true;
      });
    }
  }

  //dispose pour liberer les ressources allouées par les controlleurs
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // empêche le redimensionnement brusque
      body: SingleChildScrollView(
        // fix de l'overflow
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              colors: [
                Colors.blue[900] ?? Colors.blue,
                Colors.lightBlueAccent[700] ?? Colors.lightBlue,
                Colors.white,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(height: 80),
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "Data Xpress",
                      style: TextStyle(color: Colors.white, fontSize: 30),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Bon retour!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(60),
                    topRight: Radius.circular(60),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                  child: Column(
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromRGBO(47, 56, 171, 1),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: <Widget>[
                            // Champ email
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey[200] ?? Colors.grey,
                                  ),
                                ),
                              ),
                              child: TextField(
                                controller: _usernameController,
                                keyboardType: TextInputType
                                    .text, //pour le nom on fait .text
                                decoration: InputDecoration(
                                  hintText: "Identifiant", //placeholder
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            // Champ mot de passe
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey[200] ?? Colors.grey,
                                  ),
                                ),
                              ),
                              child: TextField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  hintText: "Mot de passe",
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      if (_errorMessage != null)
                        Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      SizedBox(height: 10),
                      Text(
                        "Mot de passe oublié?",
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 40),
                      GestureDetector(
                        onTap: _handleLogin,
                        child: Container(
                          height: 50,
                          margin: EdgeInsets.symmetric(horizontal: 50),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            color: Colors.blue[900] ?? Colors.blue,
                          ),
                          child: Center(
                            child: Text(
                              "Se connecter",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
