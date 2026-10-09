/// Política de privacidad servida en `/privacy` (enlace requerido por Google
/// Play). Describe los datos que trata realmente la app.
///
/// Si cambian los datos que trata la app (permisos, proveedores), actualiza
/// este texto, la fecha y la sección «Seguridad de los datos» de Google Play.
const privacyPolicyHtml = '''
<p class="hint">Última actualización: 9 de octubre de 2026</p>

<h2>Responsable</h2>
<p>Conexfor ("nosotros"), Perú. Contacto: <a href="mailto:conexfor@gmail.com">conexfor@gmail.com</a>. Tratamos tus datos conforme a la Ley N.° 29733 de Protección de Datos Personales del Perú y su reglamento.</p>

<h2>Qué datos tratamos y para qué</h2>
<ul>
  <li><b>Cuenta</b>: nombre visible, nombre de usuario, correo electrónico, teléfono (opcional), foto de perfil (opcional), zona horaria e idioma. Para identificarte, que tus contactos te encuentren y mostrar las alarmas en tu hora local.</li>
  <li><b>Inicio de sesión con Google o Apple</b> (opcional): recibimos un identificador de la cuenta y, si el proveedor lo comparte, tu correo y nombre. No recibimos tu contraseña.</li>
  <li><b>Contraseña</b>: se guarda solo como hash (bcrypt); nunca en texto plano.</li>
  <li><b>Contactos y grupos</b>: las conexiones que aceptas, los permisos que concedes a cada contacto y los grupos a los que perteneces.</li>
  <li><b>Alarmas</b>: título, mensaje, fecha, hora, recurrencia, destinatarios y tus respuestas (confirmada, pospuesta, descartada).</li>
  <li><b>Mensajes al asistente</b>: el texto que escribes al asistente y sus respuestas, para que puedas revisar tu historial. Se interpretan con reglas propias; no se envían a servicios de inteligencia artificial ni a terceros.</li>
  <li><b>Micrófono y voz</b> (opcional, solo si usas el asistente por voz):
    <ul>
      <li><b>Activación con «Hey Ally»</b>: si la activas en <i>Configuración → Asistente por voz</i> (está desactivada por defecto), la app escucha el micrófono en segundo plano, con una notificación visible mientras lo hace, para detectar la palabra clave. Esa detección se hace <b>completamente en tu teléfono</b>: el audio no se graba, no se guarda y no se envía a nosotros ni a terceros. Puedes desactivarla en cualquier momento.</li>
      <li><b>Dictado de órdenes</b>: cuando dices una orden (tras «Hey Ally» o al tocar el botón del micrófono), el audio lo transcribe el <b>servicio de reconocimiento de voz de tu teléfono</b> (por ejemplo, el de Google), que puede procesarlo en sus servidores según su propia política de privacidad. Nosotros recibimos solo el texto resultante, que se trata como un mensaje al asistente.</li>
      <li><b>Respuestas habladas</b>: se generan con el motor de texto a voz de tu teléfono.</li>
    </ul>
  </li>
  <li><b>Cámara</b> (opcional): solo para escanear códigos QR de invitación. Las imágenes se procesan en el teléfono y no se guardan ni se envían.</li>
  <li><b>Fotos</b> (opcional): la imagen que eliges como foto de perfil se sube al servidor para mostrarla a tus contactos.</li>
  <li><b>Huella o rostro</b> (opcional): si activas el bloqueo de la app, la verificación la hace el sistema del teléfono. No recibimos ni guardamos datos biométricos.</li>
  <li><b>Dispositivos</b>: nombre y tipo del dispositivo, plataforma, versión de la app, zona horaria y token de notificaciones push, para enviarte avisos y elegir dónde suena cada alarma.</li>
  <li><b>Datos técnicos</b>: dirección IP y registros del servidor para seguridad y prevención de abusos.</li>
</ul>

<h2>Quién ve tus datos</h2>
<ul>
  <li>Tus contactos y miembros de tus grupos ven tu nombre, usuario y foto.</li>
  <li>Quien crea una alarma para ti ve tu respuesta solo si se lo permites ("Permitir ver confirmación").</li>
  <li>Los destinatarios de una alarma ven las respuestas de los demás solo si quien la creó lo permite.</li>
  <li>Nadie puede encontrarte por correo o teléfono salvo escribiendo el dato exacto.</li>
</ul>

<h2>Proveedores</h2>
<ul>
  <li>El servicio de reconocimiento de voz de tu teléfono (por ejemplo, Google), solo si dictas órdenes por voz.</li>
  <li>Google Firebase Cloud Messaging, para entregar notificaciones push (recibe el token del dispositivo y el contenido del aviso).</li>
  <li>Proveedor de correo, para enviar enlaces de verificación y de recuperación de contraseña.</li>
  <li>Proveedor de alojamiento del servidor y la base de datos.</li>
</ul>
<p>No vendemos tus datos ni los usamos para publicidad.</p>

<h2>Seguridad</h2>
<p>Las comunicaciones van cifradas (HTTPS). Las sesiones usan tokens de corta duración, guardados en el almacenamiento seguro del teléfono. Cada operación verifica que tengas permiso sobre los datos.</p>

<h2>Conservación y eliminación</h2>
<p>Conservamos tus datos mientras tengas la cuenta. Puedes eliminarla en cualquier momento desde <b>Perfil → Configuración → Eliminar mi cuenta</b>: se borran tu perfil, tus alarmas, tus grupos y tus mensajes del asistente. También puedes solicitarlo escribiendo a <a href="mailto:conexfor@gmail.com">conexfor@gmail.com</a>. Atenderemos tu solicitud en un plazo máximo de 30 días.</p>

<h2>Tus derechos</h2>
<p>Puedes acceder, corregir o eliminar tus datos desde la app o escribiendo a <a href="mailto:conexfor@gmail.com">conexfor@gmail.com</a>.</p>

<h2>Menores</h2>
<p>La app no está dirigida a menores de 13 años.</p>

<h2>Cambios</h2>
<p>Si cambiamos esta política lo indicaremos en esta página con una nueva fecha.</p>
''';
