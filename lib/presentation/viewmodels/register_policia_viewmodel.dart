import 'package:flutter/material.dart';

class RegisterPoliciaViewModel extends ChangeNotifier {
  // Estados del proceso
  bool _isTokenRequested = false;
  bool _isTokenValidated = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isTokenRequested => _isTokenRequested;
  bool get isTokenValidated => _isTokenValidated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Controladores
  final tokenController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // Simular solicitud al comando
  Future<void> solicitarToken() async {
    _setLoading(true);
    try {
      // Futuro: await _authService.requestToken();
      await Future.delayed(const Duration(seconds: 2));
      _isTokenRequested = true;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = "Error al solicitar token";
    } finally {
      _setLoading(false);
    }
  }

  // Validar el token ingresado
  void validarToken() {
    if (tokenController.text.isEmpty) {
      _errorMessage = "El token no puede estar vacío";
      notifyListeners();
      return;
    }

    // Futuro: await _authService.verifyToken(tokenController.text);
    // Simulación
    if (tokenController.text == "123456") {
      _isTokenValidated = true;
      notifyListeners();
    } else {
      _isTokenValidated = false;
      // Podrías agregar un manejo de error aquí
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void registrar() {
    if (!_isTokenValidated) return;
    if (passwordController.text != confirmPasswordController.text) {
      _errorMessage = "Las contraseñas no coinciden";
      notifyListeners();
      return;
    }
    print("Llamando a servicio de registro...");
  }

  @override
  void dispose() {
    tokenController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}