import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/core/app_radius.dart';
import 'package:CallSos/core/app_spacing.dart';
import 'package:CallSos/core/app_text_styles.dart';
import 'package:CallSos/core/colores_app.dart';

/// EPIC-01 (Design System) — tests de sanidad de los tokens, no de UI
/// (ninguna vista los consume todavía). El objetivo principal es
/// resguardar el hallazgo #6 de la auditoría UX/UI: que la paleta por
/// rol nunca vuelva a colisionar (hoy AGENTE y COMANDO comparten
/// color) sin que un test lo note.
void main() {
  group('AppColors — paleta por rol', () {
    test('los 4 acentos de rol son todos distintos entre sí', () {
      final acentos = {
        AppColors.acentoDenunciante,
        AppColors.acentoAgente,
        AppColors.acentoOperadorCai,
        AppColors.acentoComando,
      };

      // Si dos roles compartieran color, el Set tendría menos de 4
      // elementos — exactamente el bug que esta paleta resuelve.
      expect(acentos.length, 4);
    });

    test('los 4 colores originales de marca no cambiaron de valor', () {
      // EPIC-01 amplía este archivo pero NO debe alterar la identidad
      // de marca ya validada — este test es la guarda de esa promesa.
      expect(AppColors.blancoVerde, const Color(0xfff6ffe3));
      expect(AppColors.verdeClaro, const Color(0xff7ead1f));
      expect(AppColors.verdeOscuro, const Color(0xff1e9a20));
      expect(AppColors.negroTexto, const Color(0xFF1B2A3B));
    });

    test('acentoDenunciante se conserva igual a verdeOscuro', () {
      expect(AppColors.acentoDenunciante, AppColors.verdeOscuro);
    });

    test('los 4 semánticos son todos distintos entre sí', () {
      final semanticos = {
        AppColors.error,
        AppColors.warning,
        AppColors.success,
        AppColors.info,
      };
      expect(semanticos.length, 4);
    });
  });

  group('AppRadius', () {
    test('la escala es estrictamente ascendente: sm < md < lg < pill', () {
      expect(AppRadius.sm, lessThan(AppRadius.md));
      expect(AppRadius.md, lessThan(AppRadius.lg));
      expect(AppRadius.lg, lessThan(AppRadius.pill));
    });

    test('cada BorderRadius helper usa el radio correspondiente', () {
      expect(AppRadius.borderSm.topLeft.x, AppRadius.sm);
      expect(AppRadius.borderMd.topLeft.x, AppRadius.md);
      expect(AppRadius.borderLg.topLeft.x, AppRadius.lg);
      expect(AppRadius.borderPill.topLeft.x, AppRadius.pill);
    });
  });

  group('AppSpacing', () {
    test('la escala es estrictamente ascendente', () {
      const escala = [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ];
      for (var i = 1; i < escala.length; i++) {
        expect(escala[i], greaterThan(escala[i - 1]));
      }
    });

    test('cada gap tiene el mismo alto y ancho que su constante numérica', () {
      expect(AppSpacing.gapMd.height, AppSpacing.md);
      expect(AppSpacing.gapMd.width, AppSpacing.md);
    });
  });

  group('AppTextStyles', () {
    test('la escala de fontSize es estrictamente ascendente', () {
      const escala = [
        AppTextStyles.etiqueta,
        AppTextStyles.cuerpoPequeno,
        AppTextStyles.cuerpo,
        AppTextStyles.tituloMediano,
        AppTextStyles.tituloGrande,
        AppTextStyles.display,
      ];
      for (var i = 1; i < escala.length; i++) {
        expect(escala[i].fontSize, greaterThan(escala[i - 1].fontSize!));
      }
    });

    test('el TextTheme expone exactamente los mismos estilos que las constantes',
        () {
      const theme = AppTextStyles.textTheme;
      expect(theme.displayLarge, AppTextStyles.display);
      expect(theme.titleLarge, AppTextStyles.tituloGrande);
      expect(theme.titleMedium, AppTextStyles.tituloMediano);
      expect(theme.bodyLarge, AppTextStyles.cuerpo);
      expect(theme.bodyMedium, AppTextStyles.cuerpoPequeno);
      expect(theme.labelSmall, AppTextStyles.etiqueta);
    });
  });
}