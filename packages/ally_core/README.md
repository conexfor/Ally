# ally_core

Paquete Dart puro compartido por la app Flutter y el backend.

- `domain/`: enums, objetos de valor (`LocalDate`, `LocalTime`), reglas de repetición.
- `api/`: contratos JSON (DTOs) que intercambian app y backend.
- `scheduling/`: cálculo de próximas ocurrencias de alarmas recurrentes.
- `validation/`: reglas de validación compartidas (usuario, correo, contraseña...).
- `nlp/`: motor de lenguaje natural basado en reglas (`RuleBasedCommandInterpreter`).

Ver `docs/PARSER.md` en la raíz del repositorio.
