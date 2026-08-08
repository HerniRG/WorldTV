# Playback platform plan

Plan vivo para mejorar la reproducción nativa en iPhone, iPad, tvOS y macOS.

## Estado

- Última actualización: 2026-08-08
- Fase activa: Fase 3 — sesión de reproducción compartida
- Estado general: planificado
- Nota: Las validaciones de tvOS están cerradas; la caída real de una fuente requiere una prueba determinista antes de continuar con la sesión compartida.

### Convención de estados

- `[ ]` Pendiente
- `[-]` En curso
- `[x]` Completado
- `[!]` Bloqueado o pendiente de una decisión externa

## Objetivos

- Aprovechar los controles y comportamientos nativos de cada plataforma.
- Mantener una única sesión de reproducción coherente entre UI, `AVPlayer` y ciclo de vida.
- Evitar que una acción del sistema cierre inesperadamente el reproductor.
- Recuperar correctamente reproducción, timeline, audio y metadatos tras background, suspensión o reconexión.
- Priorizar funciones útiles para el usuario antes que controles personalizados innecesarios.

## Fase 1 — Timeline y ciclo de vida de tvOS

Estado: `[-]`

### Problema

Después de que Apple TV permanezca en background o se reactive, el stream live continúa correctamente al pulsar Play, pero la hora mostrada en el timeline deja de actualizarse.

### Trabajo

- [x] Observar la transición de la aplicación a `active` en el reproductor.
- [x] Registrar temporalmente `currentTime`, `currentDate`, `duration`, `seekableTimeRanges`, `timeControlStatus`, `rate` y `timebase` al volver a active.
- [ ] Diferenciar si se congela solo la interfaz nativa o también el tiempo del `AVPlayerItem`.
- [ ] Añadir observación periódica del tiempo para diagnóstico y estado compartido.
- [ ] Revalidar el `AVPlayerItem` al volver de background sin reiniciar innecesariamente la emisión.
- [ ] Actualizar o reasignar el controlador nativo si el vídeo avanza pero el timeline no.
- [ ] Detectar streams live que no proporcionen una referencia temporal válida.
- [ ] Mantener el fallback de fuentes cuando el item realmente haya dejado de reproducir.

### Criterios de aceptación

- [x] El timeline vuelve a actualizarse después de 30 segundos en background.
- [x] El timeline vuelve a actualizarse después de varios minutos.
- [x] El comportamiento funciona tras despertar Apple TV.
- [x] El vídeo no se reinicia si el stream sigue vivo.
- [!] Si el stream ha muerto, se muestra buffering, fallback o error de forma coherente; requiere una fuente simulada o fixture determinista.

## Fase 2 — Navegación y controles nativos de tvOS

Estado: `[x]`

- [x] Hacer que Back cierre primero el panel de información.
- [x] Hacer que Back oculte después los controles del reproductor.
- [x] Salir del reproductor solo cuando la interfaz nativa esté limpia.
- [x] Evitar que el `.onExitCommand` del reproductor cierre prematuramente toda la presentación.
- [x] Migrar el panel a `customInfoViewControllers`.
- [x] Aplicar material visual nativo de tvOS al fondo del panel.
- [x] Mantener el selector de feeds como menú nativo.
- [!] No implementar zapping ni cambio rápido de canal; queda fuera del alcance decidido.
- [x] Verificar Siri Remote, scrubbing, pausa, avance y retroceso.
- [x] Verificar subtítulos, pistas de audio y Picture-in-Picture cuando el stream los soporte.
- [x] Activar explícitamente PiP nativo, la sesión de audio de vídeo y la restauración del controlador en tvOS.
- [x] Al iniciar PiP, cerrar la presentación del reproductor sin detener el `AVPlayer`.
- [x] Al finalizar PiP, restaurar la presentación del reproductor.

## Fase 3 — Sesión de reproducción compartida

Estado: `[-]`

- [x] Extraer una `PlaybackSession` compartida desde `PlayerViewModel`; la máquina de estados ya gobierna fuentes, estados y errores.
- [x] Centralizar reproducción, pausa, buffering, fuentes, errores y ciclo de vida entre `PlaybackSession` y el adaptador `PlaybackSessionDriver`.
- [x] Añadir estado temporal común: posición, fecha, live edge y rangos seekable.
- [x] Separar estado de emisión real (`streamState`) de estado visual del reproductor (`state`).
- [x] Gestionar observers y tareas con cancelación explícita mediante `PlaybackSessionDriver`.
- [x] Añadir tests deterministas para background, reactivación, cambio de fuente y streams live; ya están cubiertos reactivación, timeline live, buffering, fallback y agotamiento de fuentes.
- [!] Ejecutar integración del `PlaybackSessionDriver` con `AVPlayer` real; pendiente de un entorno Xcode con firma, permisos de ejecución y soporte de simulador/dispositivo.

## Fase 4 — iPhone

Estado: `[ ]`

- [x] Publicar el artwork del canal en los metadatos externos del `AVPlayerItem`, con el icono de la aplicación como fallback.
- [ ] Completar Picture-in-Picture.
- [ ] Configurar correctamente audio, AirPlay y background modes.
- [ ] Implementar restauración de la interfaz al salir de PiP.
- [ ] Añadir AirPlay y cambios de salida.
- [ ] Mantener reproducción durante rotación y fullscreen.
- [ ] Gestionar interrupciones de audio y recuperación.
- [ ] Gestionar desconexión de auriculares y cambios Bluetooth.
- [!] No implementar Now Playing, Lock Screen ni controles multimedia del sistema; la experiencia resultó problemática y queda fuera del alcance decidido.
- [!] No implementar comandos multimedia asociados a Now Playing.

## Fase 5 — iPad

Estado: `[ ]`

- [ ] Soportar PiP automático al salir de la aplicación.
- [ ] Validar Split View, Slide Over y cambios de tamaño.
- [ ] Permitir reproducción inline cuando aporte valor.
- [ ] Mantener AirPlay existente; no añadir Now Playing.
- [ ] Restaurar correctamente la interfaz después de PiP o multitarea.
- [ ] Añadir un mini reproductor persistente si no interfiere con la navegación.

## Fase 6 — Audio, AirPlay y controles del sistema

Estado: `[x]`

- [x] Ampliar `AudioSessionCoordinator` para observar interrupciones y cambios de ruta.
- [x] Configurar la categoría y el modo apropiados para vídeo.
- [x] Pausar al desconectar auriculares cuando el sistema lo indique.
- [x] Recuperar reproducción tras llamadas, Siri y alertas del sistema.
- [!] No publicar metadatos del canal mediante Now Playing; queda descartado.
- [!] No conectar `MPRemoteCommandCenter` con la sesión compartida; queda descartado.
- [ ] Probar AirPlay con Apple TV y dispositivos compatibles.

## Fase 7 — macOS

Estado: `[ ]`

- [ ] Completar fullscreen nativo con `AVPlayerView`.
- [ ] Añadir Picture-in-Picture si está disponible para la configuración objetivo.
- [ ] Añadir atajos de teclado y controles multimedia.
- [ ] Mantener selección de feed y metadatos.
- [ ] Recuperar reproducción tras suspensión o cambio de ventana.
- [ ] Evaluar una ventana de reproducción independiente.

## Fase 8 — Chromecast

Estado: `[ ]`

- [ ] Evaluar Google Cast SDK como integración separada de las capacidades Apple.
- [ ] Añadir permiso y explicación de red local.
- [ ] Añadir selector de dispositivos y botón Cast.
- [ ] Añadir mini controlador y control ampliado.
- [ ] Sincronizar reproducción, pausa, volumen y desconexión.
- [ ] Verificar streams que requieren `Referer` o `User-Agent`.
- [ ] Confirmar receptor compatible antes de iniciar la implementación.

## Validación por plataforma

- [ ] iPhone físico: PiP, AirPlay, bloqueo, auriculares, llamadas y rotación.
- [ ] iPad físico: PiP, Split View, Slide Over y cambio de tamaño.
- [ ] Apple TV físico: Back, panel de información, Siri Remote, background y timeline live.
- [ ] Mac: fullscreen, suspensión, atajos y cambio de ventana.
- [ ] Streams HLS live con y sin `EXT-X-PROGRAM-DATE-TIME`.
- [ ] Streams con buffering, caída de fuente y recuperación.

## Registro de cambios del plan

### 2026-08-08

- Corregido un crash de AppKit al actualizar el reproductor de macOS: `PlayerMouseTrackingView` eliminaba un `TrackingRectTag` no inicializado cuando la vista se actualizaba al cambiar de fuente; ahora usa únicamente `NSTrackingArea`.
- Añadido artwork al `AVPlayerItem` para la tarjeta de reproducción bloqueada de iPhone: se publica primero el icono de la aplicación y se sustituye por el logo del canal cuando termina de descargarse.
- Separado `PlaybackSessionDriver` de `PlayerViewModel` y ubicado en la capa de reproducción para aislar KVO, time observers, finalización y timeouts de la coordinación de UI; se mantiene un único flujo de eventos hacia `PlaybackSession`.
- Intentada una compilación local sin firma; el entorno no pudo crear el área de DerivedData y tampoco dispone de CoreSimulator operativo, por lo que la validación queda pendiente de un entorno Xcode funcional.

- Validado manualmente por el usuario en un Apple TV real que, tras volver de background después de usar otras aplicaciones, el directo continúa y el timeline vuelve a actualizarse sin reiniciar el vídeo.
- Validado manualmente por el usuario en un Apple TV real que, tras poner el dispositivo en reposo y despertarlo varios minutos después, recupera el directo y actualiza el timeline correctamente.
- Cerrada la Fase 1 de timeline y ciclo de vida de tvOS; la caída real de una fuente queda condicionada a una prueba determinista.
- La siguiente fase prioriza extraer la sesión compartida y preparar fixtures para buffering, caída de fuente, fallback y reactivación.
- Añadida una `PlaybackSession` determinista con tests de fallback, buffering, recuperación, retry y agotamiento de fuentes; integrada inicialmente en el fallback de `PlayerViewModel`.
- Integrados en `PlaybackSession` los estados de preparación, reproducción, buffering, pausa, finalización y error; `PlayerViewModel` traduce los eventos de `AVPlayer` y conserva la coordinación de UI.
- Renombrado el adaptador de AVPlayer a `PlaybackSessionDriver`, con un único flujo de eventos y cancelación explícita de KVO, finalización y timeouts.
- Añadida una muestra temporal periódica con posición, duración, fecha actual, rangos seekable y detección de directo; se cancela al sustituir o detener el item.
- Separados el estado real de la emisión y el estado visual del reproductor; el ciclo de vida usa `streamState` y la UI continúa consumiendo `state`.
- Añadido el evento de reactivación y un test determinista que conserva el estado, timeline live y fuente al volver a `active`.
- Cerrada la cobertura determinista de la sesión; la validación restante es exclusivamente la integración del driver con `AVPlayer` real.
- Cerrada la fase de navegación y controles nativos de tvOS: Back, panel, selector de feeds y salida ordenada quedan validados.
- Sincronizado el plan de audio con la configuración de vídeo, la recuperación de interrupciones y la pausa por desconexión de ruta ya implementadas.
- Reorientada la fase activa al diagnóstico del timeline live después de background.

- Creado el plan vivo de reproducción multiplataforma.
- Identificado como prioridad el timeline de tvOS después de background.
- Documentadas las fases de tvOS, iPhone, iPad, macOS, AirPlay, audio, Now Playing, PiP y Chromecast.
- Añadida instrumentación al volver a `active` para comparar el estado temporal antes y después de la reactivación.
- Las compilaciones locales del entorno no pudieron completarse por la ausencia de runtimes del simulador y fallos del sandbox de Xcode; la validación se realizó en dispositivos físicos.
- Corregido el Back de tvOS para que el reproductor nativo pueda cerrar primero el panel de información.
- Activada y validada la configuración nativa de PiP en tvOS.
- Preparado el flujo multiplataforma para devolver la app al contenido anterior durante PiP y restaurar el reproductor al finalizarlo.
- Validado por el usuario el Back nativo de tvOS y el flujo de PiP en iPhone/iPad y tvOS.
- Eliminada la instrumentación temporal del timeline antes del primer commit.
- Migrado el panel de información a `customInfoViewControllers` y aplicado `regularMaterial` nativo de tvOS.
- Validados los controles nativos restantes de tvOS; no se necesitan controles personalizados adicionales.
- Validado en dispositivo el cambio de salida de audio: conectar mantiene la reproducción y desconectar pausa el directo.
- Descartada la fase de Now Playing, Lock Screen y controles multimedia del sistema por problemas de restauración y artwork.
- Descartado el zapping o cambio rápido de canal por decisión de producto.

## Cómo mantener este documento

Al comenzar un bloque de trabajo:

1. Cambiar la fase correspondiente a `[-]`.
2. Añadir aquí cualquier decisión técnica relevante.
3. Marcar tareas y criterios de aceptación conforme se verifiquen.
4. Cambiar la fase a `[x]` solo después de probarla en la plataforma correspondiente.
5. Añadir una entrada al registro de cambios.
