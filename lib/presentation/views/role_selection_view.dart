import 'package:flutter/material.dart';
import '../../core/colores_app.dart';

class RoleSelectionView extends StatelessWidget {
  const RoleSelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blancoVerde,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "IDENTIFÍCATE",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.verdeOscuro),
              ),
              const SizedBox(height: 40),
              
              // Tarjeta Denunciante
              _RoleCard(
                title: "DENUNCIANTE",
                icon: Icons.person_search,
                onTap: () => Navigator.pushNamed(context, '/welcome', arguments: 'denunciante'),
              ),
              
              const SizedBox(height: 20),
              
              // Tarjeta Policía
              _RoleCard(
                title: "POLICÍA / CAI",
                icon: Icons.local_police,
                onTap: () => Navigator.pushNamed(context, '/welcome', arguments: 'policia'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleCard({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(
          children: [
            Icon(icon, size: 50, color: AppColors.verdeClaro),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}