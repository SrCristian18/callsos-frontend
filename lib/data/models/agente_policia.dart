import 'role.dart';

class AgentePolicia {
  final String id;
  final String name;
  final Role role;
  final String? caiId;

  AgentePolicia({
    required this.id,
    required this.name,
    required this.role,
    this.caiId,
  });
}