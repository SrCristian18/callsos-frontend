import 'package:flutter/material.dart';

class LoginViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

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

  @override
  void dispose() {
    userController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}