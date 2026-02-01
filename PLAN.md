# Plan de Implementación - FinanzApp

## Visión General
Web App de Finanzas Personales tipo SaaS, enfocada en la gestión inteligente de transacciones, presupuestos y análisis financiero visual.

## Fases de Desarrollo

### Fase 1: Fundamentos y Arquitectura (Actual)
- **Objetivo**: Establecer la base sólida del proyecto.
- [x] Definición de Arquitectura (Feature-based + Riverpod).
- [x] Estructura de carpetas.
- [x] Modelado de datos (Entidades Core).
- [ ] Configuración de dependencias (`pubspec.yaml`).
- [ ] Setup de Tema y Estilos globales (Google Fonts, Colores Mates).

### Fase 2: Configuración y Datos Maestros
- **Objetivo**: Permitir la configuración básica necesaria para registrar datos.
- [ ] CRUD de **Cuentas** (Bancos, Efectivo, Billeteras).
- [ ] CRUD de **Rubros/Categorías** (Árbol de categorías o lista plana con iconos).
- [ ] CRUD de **Reglas de Asignación** (Motor simple: "Si contiene 'Uber' -> Transporte").

### Fase 3: Gestión de Movimientos (Core)
- **Objetivo**: Ingreso y procesamiento de transacciones.
- [ ] Listado de Movimientos con filtros y buscador.
- [ ] Creación/Edición manual de movimientos.
- [ ] **Importación CSV**: Parsing de archivos bancarios.
- [ ] **Motor de Reglas**: Aplicación automática de categorías al importar.

### Fase 4: Presupuesto y Planificación
- **Objetivo**: Comparación Realidad vs. Planificación.
- [ ] Vista de Presupuesto (Tabla 12 meses).
- [ ] Edición de meses futuros (Forecast).
- [ ] Visualización de ejecución (Semáforos/Barras de progreso).

### Fase 5: Visualización y Dashboard
- **Objetivo**: Insights financieros.
- [ ] Dashboard Principal (KPIs: Ingreso, Gasto, Ahorro).
- [ ] Gráficos de evolución (fl_chart).
- [ ] Vista de Balance (Scroll horizontal infinito, tooltips).

### Fase 6: Autenticación y Seguridad
- **Objetivo**: Protección de datos multi-usuario.
- [ ] Integración Firebase Auth (Google + Email/Pass).
- [ ] Reglas de seguridad en Firestore (solo acceso a documentos propios).

## Arquitectura Técnica

### Stack
- **Frontend**: Flutter Web.
- **Backend as a Service**: Firebase (Firestore, Auth, Hosting).
- **State Management**: Riverpod (con Code Generation recomendada).

### Estructura de Directorios (Feature-based)
```
lib/
├── core/                   # Utilidades compartidas, theme, constants
├── features/
│   ├── auth/               # Login, Registro
│   ├── dashboard/          # KPIs, Gráficos
│   ├── transactions/       # Listado, Importación, Detalles
│   ├── budget/             # Presupuesto, Forecast
│   ├── settings/           # Cuentas, Rubros, Reglas
│   └── balance/            # Vista de tabla mensual
├── models/                 # Entidades compartidas
└── main.dart
```
