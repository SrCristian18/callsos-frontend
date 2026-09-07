import 'package:flutter/material.dart';
import '../../core/colores_app.dart';

/// EPIC-20 (deuda técnica, hallazgo #11 de la auditoría original):
/// antes, `CustomInput` era un `StatelessWidget` que hacía
/// `controller: controller ?? TextEditingController()` directo en
/// `build()`. Dos problemas reales, no solo teóricos:
///
/// 1. **Fuga de memoria**: cada vez que este widget se reconstruye
///    (cualquier rebuild del árbol que lo contiene — un `setState()`
///    en el padre, una notificación de Provider, etc.), esa expresión
///    crea un `TextEditingController` NUEVO, y el de la reconstrucción
///    anterior nunca se libera (`dispose()`) — nadie tiene una
///    referencia a él para hacerlo. Se pierde en cada rebuild sin
///    controller explícito.
/// 2. **Pérdida de texto** (más grave que la fuga en sí): `TextField`
///    trata un cambio en la IDENTIDAD de su `controller` como "este es
///    un controller distinto" — como la expresión de arriba crea una
///    instancia nueva en CADA build, el campo puede perder lo que el
///    usuario ya había escrito en cualquier rebuild no relacionado con
///    el campo en sí.
///
/// Fix: `StatefulWidget` con el controller creado UNA sola vez en
/// `initState()` (no en `build()`), liberado en `dispose()` SOLO si
/// fue creado acá adentro — un controller que vino de afuera
/// (`widget.controller != null`) es responsabilidad de quien lo pasó,
/// nunca de este widget.
class CustomInput extends StatefulWidget {
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final TextEditingController? controller;

  const CustomInput({
    super.key,
    required this.hintText,
    required this.icon,
    this.controller,
    this.isPassword = false,
  });

  @override
  State<CustomInput> createState() => _CustomInputState();
}

class _CustomInputState extends State<CustomInput> {
  late TextEditingController _controller;

  /// `true` si el controller lo creamos nosotros acá adentro (porque
  /// `widget.controller` era `null`) — la única condición bajo la cual
  /// `dispose()` debe liberarlo.
  bool _esInterno = false;

  @override
  void initState() {
    super.initState();
    _inicializarController();
  }

  void _inicializarController() {
    if (widget.controller != null) {
      _controller = widget.controller!;
      _esInterno = false;
    } else {
      _controller = TextEditingController();
      _esInterno = true;
    }
  }

  @override
  void didUpdateWidget(CustomInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Defensivo: ningún uso actual de CustomInput cambia `controller`
    // después de construirlo (todos lo fijan una vez, en initState() de
    // la vista que lo contiene, o nunca lo pasan) — pero si algún día
    // pasara, hay que liberar el interno ANTES de reemplazarlo, no
    // dejarlo perdido igual que el bug original.
    if (widget.controller != oldWidget.controller) {
      if (_esInterno) _controller.dispose();
      _inicializarController();
    }
  }

  @override
  void dispose() {
    // Solo el que creamos nosotros — uno que vino de `widget.controller`
    // no es nuestro para liberar (el dueño real puede seguir
    // necesitándolo, ej. para leer el valor final tras cerrar esta vista).
    if (_esInterno) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      // hintText (a diferencia de labelText) desaparece visualmente al
      // escribir, y su anuncio para lectores de pantalla una vez el campo
      // tiene contenido no es consistente entre plataformas. Este
      // Semantics explícito fija el nombre accesible del campo
      // ("¿qué es esto?") de forma persistente, sin cambiar el diseño
      // visual existente (mantener labelText habría requerido rediseñar
      // todos los CustomInput del proyecto — fuera de alcance de este
      // ítem, que es puramente de accesibilidad).
      //
      // EPIC-20 — CONFIRMADO con un test real (no una suposición): sin
      // `excludeSemantics: true`, este `label` NO llega a ningún lado —
      // `find.bySemanticsLabel(hintText)` pasa de encontrar 1 nodo a
      // encontrar 0, no 2 (mismo hallazgo, con la misma causa, que
      // EPIC-19 ya había confirmado en `AppTextField`/`AppPasswordField`
      // — este archivo simplemente nunca había tenido un test que lo
      // pusiera a prueba hasta ahora). Antes este comentario decía que
      // CustomInput era "el patrón ya correcto" a extender en los otros
      // 2 widgets — resulta que le faltaba exactamente lo mismo que a
      // ellos.
      child: Semantics(
        label: widget.hintText,
        excludeSemantics: true,
        child: TextField(
          controller: _controller,
          obscureText: widget.isPassword,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: Icon(widget.icon, color: AppColors.verdeClaro),
            suffixIcon:
                widget.isPassword ? Icon(Icons.visibility_off_outlined) : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          ),
        ),
      ),
    );
  }
}