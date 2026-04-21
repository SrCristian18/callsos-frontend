import 'package:flutter/material.dart';

class LoginViewModel extends ChangeNotifier {
  //getters
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Controladores para capturar el texto
  final TextEditingController userController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();



  Future<void> login(BuildContext context) async {
    if (userController.text.isEmpty || passwordController.text.isEmpty) {
      // Aquí podrías mostrar un error
      return;
    }

    _isLoading = true;
    notifyListeners();

    // Simulamos una petición al backend hexagonal
    await Future.delayed(const Duration(seconds: 2));

    _isLoading = false;
    notifyListeners();
    
    print("Login exitoso para: ${userController.text}");
  }

  void resetForm(){
    userController.clear();
    passwordController.clear();
    _errorMessage = null;
  }

  bool isValid(){
    if(userController.text.isEmpty || passwordController.text.isEmpty){
      _errorMessage = "Por favor, completa todos los campos";
      notifyListeners();
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    userController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}