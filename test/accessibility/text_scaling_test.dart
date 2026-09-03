import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:CallSos/core/app_routes.dart';
import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/models/enums/tipo_incidente_enum.dart';
import 'package:CallSos/data/models/incidente.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/secure_storage.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';
import 'package:CallSos/presentation/views/login_view.dart';
import 'package:CallSos/presentation/widgets/incidente_card.dart';
import 'package:CallSos/presentation/widgets/role_header.dart';

/// EPIC-14 (Accesibilidad y usabilidad) — "soporte de texto escalable
/// del sistema".
///
/// La app no deshabilita ni fija `textScaler` en ningún lado (buena
/// señal — se verificó por grep antes de escribir esto: cero usos de
/// `textScaleFactor`/`textScaler`/`MediaQuery(` en `lib/`), así que ya
/// respeta la preferencia de tamaño de letra del sistema operativo por
/// default. Lo que este archivo confirma es la otra mitad del
/// requisito: que el LAYOUT no se rompe (overflow) cuando esa
/// preferencia está en un valor grande — 1.3x (ajuste común) y 2.0x
/// (el máximo típico en Android/iOS) — en los widgets más reutilizados
/// de la app.
///
/// No cubre TODAS las pantallas (inviable en un solo archivo) — son los
/// widgets compartidos de mayor superficie: `IncidenteCard` (en las 4
/// Home), `RoleHeader` (en las 4 Home) y el formulario de `LoginView`
/// (mismo esqueleto que login_policia/register_*).
class MockAuthService extends Mock implements IAuthService {}

class FakeSecureStorage implements ISecureStorage {
  final Map<String, String> _datos = {};
  @override
  Future<String?> read(String key) async => _datos[key];
  @override
  Future<void> write(String key, String value) async => _datos[key] = value;
  @override
  Future<void> delete(String key) async => _datos.remove(key);
}

/// Envuelve toda la MaterialApp fijando `textScaler` vía `builder` — es
/// la forma correcta de simular la preferencia de tamaño de letra del
/// SISTEMA en un test (afecta a toda la app, AppBar incluido), a
/// diferencia de envolver un widget suelto con un `MediaQuery` propio
/// (no sirve para un `PreferredSizeWidget` como `RoleHeader`, que
/// `Scaffold.appBar` exige tal cual, sin poder envolverlo en otro
/// widget intermedio).
Widget _appConEscala(double escala, Widget home,
    {Map<String, WidgetBuilder>? routes, String? initialRoute}) {
  return MaterialApp(
    initialRoute: initialRoute,
    home: initialRoute == null ? home : null,
    routes: routes ?? const {},
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escala)),
      child: child!,
    ),
  );
}

void main() {
  Incidente incidenteConTextoLargo() => Incidente(
        id: 'i-001',
        fechaHora: DateTime(2026, 6, 14, 10, 30),
        tipo: TipoIncidenteEnum.ROBOS_O_ASALTOS,
        descripcion: 'Se reporta una situación de robo en la vía pública, '
            'con varios testigos presentes en el lugar de los hechos.',
        estado: EstadoIncidente.AGENTE_EN_CAMINO,
        latitud: 10.391,
        longitud: -75.4794,
        denuncianteId: 'den-001',
        nombreCAI: 'CAI San José Centro Histórico',
      );

  for (final escala in [1.3, 2.0]) {
    group('Escala de texto ${escala}x', () {
      testWidgets('IncidenteCard no desborda con descripción y CAI largos',
          (tester) async {
        await tester.pumpWidget(_appConEscala(
          escala,
          Scaffold(
            body: IncidenteCard(
              incidente: incidenteConTextoLargo(),
              labelAccion: 'Marcar como atendido',
              onAccion: () {},
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('RoleHeader no desborda con título/subtítulo largos',
          (tester) async {
        await tester.pumpWidget(_appConEscala(
          escala,
          Scaffold(
            appBar: const RoleHeader(
              rol: Rol.OPERADOR_CAI,
              titulo: 'Panel de Operaciones — CAI Centro Histórico',
              subtitulo: 'María Fernanda Operadora Principal',
            ),
            body: const SizedBox(),
          ),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('LoginView (formulario + botón + link) no desborda',
          (tester) async {
        final authService = MockAuthService();
        final sesion = SesionViewModel(
            authService: authService, storage: FakeSecureStorage());
        await sesion.restaurarSesion();

        await tester.pumpWidget(
          ChangeNotifierProvider<SesionViewModel>.value(
            value: sesion,
            child: _appConEscala(
              escala,
              const SizedBox(),
              initialRoute: AppRoutes.loginDenunciante,
              routes: {
                AppRoutes.loginDenunciante: (_) => const LoginView(),
                AppRoutes.forgotPassword: (_) =>
                    const Scaffold(body: Text('forgot_password')),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'LoginView en estado de error (mensaje visible) tampoco desborda',
          (tester) async {
        final authService = MockAuthService();
        final sesion = SesionViewModel(
            authService: authService, storage: FakeSecureStorage());
        await sesion.restaurarSesion();
        when(() => authService.login(
              username: any(named: 'username'),
              password: any(named: 'password'),
            )).thenThrow(const ApiException(
          type: ApiExceptionType.unauthorized,
          message: 'Usuario o contraseña incorrectos. Verificá tus datos '
              'e intentá de nuevo.',
        ));

        await tester.pumpWidget(
          ChangeNotifierProvider<SesionViewModel>.value(
            value: sesion,
            child: _appConEscala(
              escala,
              const SizedBox(),
              initialRoute: AppRoutes.loginDenunciante,
              routes: {
                AppRoutes.loginDenunciante: (_) => const LoginView(),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // A escala grande el botón puede quedar fuera del viewport de
        // test (800x600 por defecto) dentro del SingleChildScrollView
        // — hay que asegurarse de que esté visible antes de tocarlo,
        // igual que scrollearía un dedo real en una pantalla chica.
        await tester.ensureVisible(find.text('Iniciar sesión'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, 'user');
        await tester.enterText(find.byType(TextField).last, 'pass');
        await tester.tap(find.text('Iniciar sesión'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Usuario o contraseña incorrectos'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}