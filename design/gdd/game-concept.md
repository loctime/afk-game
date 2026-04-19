# Game Design Document — AFK RPG
### Para desarrollador de Godot

---

## 1. Visión General

**AFK RPG** es un juego de rol automático (idle/AFK) en 2D donde el jugador no controla directamente al personaje en el combate. En cambio, el personaje pelea solo contra oleadas de enemigos mientras el jugador gestiona su progresión: sube de nivel, asigna estadísticas, equipa items y administra habilidades.

La experiencia central es **ver cómo tu personaje se vuelve más poderoso con el tiempo**, incluso cuando no estás jugando activamente.

**Plataforma objetivo:** Mobile y Desktop  
**Vista:** 2D lateral (side-view)  
**Género:** Idle RPG / AFK RPG  
**Tono visual:** Fantástico, colorido, con humor absurdo en los nombres de los enemigos

---

## 2. Loop de Gameplay

El ciclo principal del juego funciona así:

1. El personaje aparece en un escenario con fondo parallax
2. Los enemigos spawnean alrededor del personaje
3. El combate ocurre **automáticamente**, sin input del jugador
4. Al morir todos los enemigos, se avanza a la siguiente oleada
5. Al completar 9 oleadas, aparece la oleada de **Boss** (requiere confirmación del jugador para empezar)
6. Al derrotar al Boss, se avanza a la siguiente **Fase** y el ciclo reinicia
7. El jugador usa el oro y XP ganados para mejorar su personaje entre oleadas

El juego es jugable en modo pasivo (AFK): el personaje sigue peleando aunque el jugador no toque nada. Al volver después de tiempo offline, el jugador recibe recompensas acumuladas.

---

## 3. Pantallas y Navegación

La interfaz tiene una **barra de navegación inferior** con 4 secciones principales:

```
[ Personaje ] [ Inventario ] [ Mapa ] [ Configuración ]
```

Por encima de esta barra está la **vista del juego** (el campo de batalla) y el **HUD** con la información de combate en tiempo real.

### 3.1 Vista de Juego (Campo de Batalla)

Es la pantalla principal. Ocupa la mayor parte de la pantalla. Muestra:

- **Fondo con parallax** (varias capas que se mueven a distintas velocidades)
- **Sprite del jugador** (centrado o ligeramente a la izquierda)
- **Sprites de los enemigos** (aparecen alrededor del jugador, flotan suavemente)
- **Números de daño** que aparecen y desaparecen sobre los personajes
- **Efectos visuales de habilidades** (proyectiles, destellos, auras)
- **Barra de HP del enemigo** visible sobre cada uno
- **Indicadores de estado** (veneno, taunt, reflect)

### 3.2 HUD (Heads-Up Display)

Siempre visible sobre el campo de batalla. Contiene:

- **Barra de HP del jugador** con valor numérico
- **Barra de Mana del jugador** con valor numérico
- **Fase y Oleada actual** (ej: "Fase 3 — Oleada 7")
- **Iconos de habilidades** con sus cooldowns visibles (se oscurecen mientras están en cooldown)
- **Oro actual** del jugador
- **Indicadores de efectos de estado activos** sobre el jugador (ej: ícono de veneno parpadeando)

### 3.3 Panel de Personaje

Muestra toda la información del personaje y permite distribuir puntos de estadística:

- Nombre y nivel del personaje
- XP actual y XP necesaria para el próximo nivel (barra de progreso)
- **Cuatro estadísticas principales** con botones `+` para asignar puntos:
  - **Fuerza (STR):** Aumenta el daño del ataque básico
  - **Destreza (DEX):** Aumenta la velocidad de ataque
  - **Inteligencia (INT):** Aumenta el mana máximo y el daño mágico
  - **Vitalidad (VIT):** Aumenta el HP máximo y la defensa
- Puntos sin asignar disponibles (se ganan al subir de nivel)
- Stats totales calculados (incluyendo bonuses del equipamiento)

### 3.4 Panel de Inventario y Equipamiento

Dividido en dos secciones visuales:

**Equipamiento (slots fijos):**  
Una grilla de 4 filas × 4-5 columnas con slots para cada pieza:

```
Fila 1: [ Pet ] [ Collar ] [ Casco ] [ Alas ]
Fila 2: [ Arma ] [ Pulsera ] [ Pecho ] [ Pulsera ] [ Escudo ]
Fila 3: [ Guantes ] [ Anillo ] [ Pantalón ] [ Anillo ] [ Botas ]
Fila 4: [ Artefacto 1 ] [ Artefacto 2 ]
```

Los slots vacíos se ven como recuadros con el ícono del tipo de item. Los equipados muestran el ícono del item con el color de su rareza en el borde.

**Inventario:**  
Lista o grilla debajo del equipamiento con todos los items que el jugador tiene pero no usa. Al tocar un item, puede:
- Equiparlo (si es del tipo correcto)
- Venderlo por oro
- Ver sus estadísticas

Hay un botón de **"Auto-equipar"** que equipa automáticamente la mejor pieza de cada slot.

### 3.5 Panel de Mapa

Muestra los mapas/zonas disponibles. Cada zona tiene un rango de oleadas y un estilo visual diferente. El jugador puede cambiar de zona (solo las desbloqueadas).

**Zonas planeadas:**
- Bosque — Zona inicial
- Cueva — Se desbloquea al avanzar
- Castillo — Zona avanzada
- (más zonas futuras)

### 3.6 Panel de Configuración

Opciones simples: volumen de música, volumen de efectos de sonido, selector de fondo visual, información de versión.

---

## 4. Sistema de Combate

### 4.1 Flujo General

El combate ocurre en rondas automáticas cada ciertos segundos. En cada ronda:

1. El jugador intenta usar una habilidad (ve la sección de Habilidades)
2. Si no puede usar ninguna habilidad especial, usa el **Ataque Básico**
3. El enemigo contraataca al jugador
4. Se muestran los números de daño y efectos visuales
5. Si el HP del enemigo llega a 0, muere y da recompensas
6. Si el HP del jugador llega a 0, ocurre un **Game Over**

### 4.2 Ataque Básico

- No tiene costo de mana
- No tiene cooldown
- El daño se basa en la Fuerza (STR) del jugador más el daño del arma equipada
- Es el ataque de respaldo cuando no hay habilidades disponibles

### 4.3 Habilidades Especiales

El jugador tiene un conjunto de habilidades equipadas. El sistema elige cuál usar automáticamente siguiendo estas prioridades:

1. **Si el HP del jugador está muy bajo (menos del 30%):** usa habilidad de curación si está disponible
2. **Si hay una habilidad de ataque con cooldown listo y mana suficiente:** la usa
3. **Si no hay nada disponible:** usa el Ataque Básico

Las habilidades tienen:
- **Tipo:** Ataque, Curación, Buff, Debuff
- **Costo de mana:** se descuenta al usarla
- **Cooldown:** tiempo de espera antes de poder usarla otra vez
- **Nivel:** las habilidades se pueden mejorar para aumentar su efecto

**Habilidades iniciales del juego:**

| Nombre | Tipo | Efecto |
|---|---|---|
| Ataque Básico | Ataque | Daño físico estándar |
| Bola de Fuego | Ataque | Daño mágico, proyectil de fuego |
| Fragmento de Hielo | Ataque | Daño mágico, proyectil de hielo |
| Rayo | Ataque | Daño mágico alto, impacto instantáneo |
| Curación | Curación | Restaura HP del jugador |

### 4.4 Mana y Regeneración

- El jugador tiene una barra de mana que se consume al usar habilidades
- El mana se regenera automáticamente con el tiempo (lentamente)
- La Inteligencia (INT) aumenta el mana máximo

### 4.5 Game Over y Revivir

Cuando el HP del jugador llega a 0:

1. El personaje reproduce animación de caída y muerte
2. Pausa breve
3. El jugador **revive automáticamente** en la primera oleada de la fase actual (no vuelve al inicio total)
4. Se recupera todo el HP

Ejemplo: si el jugador muere en la oleada 27 (Fase 3), revive en la oleada 21 (inicio de Fase 3).

---

## 5. Sistema de Oleadas y Fases

### 5.1 Estructura

Las oleadas se organizan en grupos de 10 llamados **Fases**:

```
Fase 1: Oleadas 1 → 9 → Boss (oleada 10)
Fase 2: Oleadas 11 → 19 → Boss (oleada 20)
Fase 3: Oleadas 21 → 29 → Boss (oleada 30)
... y así sucesivamente
```

### 5.2 Oleadas Normales (1-9, 11-19, etc.)

- Spawnean varios enemigos a la vez (la cantidad crece con el número de oleada, hasta un máximo)
- Al derrotar a todos los enemigos, la siguiente oleada comienza automáticamente después de una breve pausa
- Los enemigos son más fuertes a medida que avanza el número de oleada

### 5.3 Oleada de Boss (oleada 10, 20, 30...)

- Cuando se completa la oleada 9 (o 19, 29...), el juego **pausa** y muestra un aviso: "¡El Boss se acerca!"
- El jugador debe **confirmar manualmente** para iniciar la pelea contra el Boss
- Esto da tiempo al jugador para prepararse (equipar items, revisar stats)
- El Boss es un enemigo único, más grande, con mucho más HP y daño
- Al derrotar al Boss, se avanza a la siguiente Fase y se desbloquean recompensas

---

## 6. Sistema de Enemigos

### 6.1 Tipos de Comportamiento

Cada enemigo tiene un comportamiento que define cómo se mueve y sus características especiales:

| Comportamiento | Color tinte | Cómo se mueve | Efecto especial |
|---|---|---|---|
| **Melee** | Blanco (sin tinte) | Se acerca al jugador para atacar | Ninguno |
| **Aggressive** | Naranja | Se acerca rápido, hace más daño | Reflect: devuelve parte del daño recibido al jugador |
| **Tank** | Morado | Se mueve lento, tiene mucho HP | Taunt: el jugador lo prioriza obligatoriamente |
| **Ranged** | Verde | Mantiene distancia del jugador | Poison: tiene chance de envenenar al jugador |

### 6.2 Efectos de Estado

- **Veneno (Poison):** Aplica daño pequeño periódico al jugador durante varios segundos. Se elimina solo después de cierto tiempo o al terminar la oleada.
- **Taunt:** Si hay un enemigo con Taunt en el campo, el jugador lo ataca a él primero, ignorando a los demás.
- **Reflect:** Los enemigos Aggressive reflejan un porcentaje del daño recibido de vuelta al jugador.

### 6.3 Movimiento de Enemigos

Los enemigos se mueven flotando suavemente (efecto de hover/flotación vertical). Su movimiento horizontal depende del comportamiento:
- **Melee / Aggressive / Tank:** se acercan al jugador hasta llegar a su distancia preferida
- **Ranged:** mantienen distancia, se alejan si el jugador se acerca demasiado

### 6.4 Escalado

A medida que avanza el número de oleada, los enemigos disponibles cambian. Los enemigos más peligrosos solo aparecen a partir de cierto número de oleada. Hay 50 monstruos en el catálogo, cada uno con su nombre, comportamiento y tamaño.

**Tamaños de enemigos:**
- Pequeño, Mediano, Grande, Enorme

---

## 7. Sistema de Progresión del Personaje

### 7.1 Experiencia y Niveles

- Los enemigos dan XP al morir
- Al acumular suficiente XP, el personaje sube de nivel automáticamente
- Al subir de nivel:
  - Aumenta el HP máximo
  - Aumenta el mana máximo
  - Se reciben puntos de estadística para distribuir libremente
- La XP necesaria para el próximo nivel escala con el nivel actual

### 7.2 Estadísticas

El personaje tiene 4 estadísticas principales que el jugador puede mejorar manualmente:

- **Fuerza (STR):** Cada punto aumenta el daño del ataque básico
- **Destreza (DEX):** Cada punto aumenta ligeramente la velocidad de ataque
- **Inteligencia (INT):** Cada punto aumenta el mana máximo
- **Vitalidad (VIT):** Cada punto aumenta el HP máximo y reduce el daño recibido

El total de estadísticas es la suma de las stats base del personaje + los bonuses de todo el equipamiento.

---

## 8. Sistema de Items y Equipamiento

### 8.1 Tipos de Items

| Slot | Tipo | Stats posibles |
|---|---|---|
| Pet | Mascota | Cualquier stat |
| Collar | Necklace | INT, DEX |
| Casco | Helmet | VIT, defensa |
| Alas | Wings | DEX, INT |
| Arma | Weapon | Daño, STR |
| Pulsera x2 | Bracelet | INT, DEX |
| Pecho | Chest | VIT, defensa |
| Escudo | Shield | VIT, defensa |
| Guantes | Gloves | DEX |
| Anillo x2 | Ring | INT, STR |
| Pantalón | Pants | VIT |
| Botas | Boots | DEX |
| Artefacto x2 | Artifact | Todas las stats |

### 8.2 Rareza de Items

Cada item tiene una rareza que determina su color de borde/indicador y qué tan buenos son sus stats:

| Rareza | Color | Probabilidad de drop |
|---|---|---|
| Common | Gris | Muy alta |
| Rare | Azul | Media |
| Epic | Morado | Baja |
| Legendary | Dorado | Muy baja |

Los items de mayor rareza tienen multiplicadores más altos en sus estadísticas.

### 8.3 Obtención de Items

- Los enemigos tienen una **probabilidad de drop** al morir (no todos dropean)
- Las oleadas de niveles más altos pueden dropear items con mejores stats
- Los items dropeados son aleatorios en tipo y rareza (con los pesos de rareza correspondientes)
- Los items se van acumulando en el inventario

### 8.4 Venta de Items

El jugador puede vender items del inventario para obtener oro. El oro se usa para futuras funcionalidades (mejoras, crafting, etc.)

---

## 9. Sistema de Recompensas Offline

Cuando el jugador cierra el juego y vuelve después de un tiempo:

- Se calcula cuánto tiempo pasó desde la última sesión
- Se simula el progreso que hubiera hecho el personaje en ese tiempo (con una eficiencia reducida respecto al juego en vivo)
- Se le entregan las recompensas acumuladas: oro y XP
- Hay un límite máximo de horas que se pueden acumular offline

---

## 10. Animaciones del Personaje

El personaje (un alien) tiene las siguientes animaciones:

| Estado | Animación | Cuándo se usa |
|---|---|---|
| Idle | Reposo, respiración suave | Cuando no hay combate activo |
| Run/Attack | Animación de ataque | Al atacar o usar habilidad |
| Hit | Recibe golpe | Cuando el enemigo ataca |
| Fall | Cayendo | Primeros frames del game over |
| Dead | Muerto en el piso | Game over |
| Blink | Parpadeo | Efecto visual ocasional |

Las transiciones entre animaciones son rápidas (no hay blend suave obligatorio, puede ser corte directo).

---

## 11. Efectos Visuales de Combate

Cada habilidad y ataque tiene su propio efecto visual. A continuación los efectos que deben existir:

- **Ataque básico:** Proyectil o destello simple que va del jugador al enemigo
- **Bola de Fuego:** Proyectil de fuego que viaja hacia el enemigo, explota al impacto
- **Fragmento de Hielo:** Proyectil de hielo/cristal, con un efecto de congelamiento al impactar
- **Rayo:** Flash instantáneo de electricidad entre el jugador y el enemigo (no viaja, aparece directo)
- **Curación:** Aura o partículas verdes/doradas alrededor del jugador
- **Daño recibido (jugador):** Número rojo flotante que aparece y sube
- **Daño hecho (a enemigo):** Número blanco o amarillo flotante
- **Ataque de enemigo Melee:** Destello de impacto en la posición del enemigo
- **Ataque de enemigo Ranged:** Proyectil que va del enemigo al jugador
- **Ataque de enemigo Tank:** Impacto pesado/shockwave desde el enemigo
- **Ataque de enemigo Aggressive:** Proyectil o carga rápida hacia el jugador
- **Flash de daño en enemigo:** El sprite del enemigo se vuelve blanco brevemente al recibir daño

---

## 12. Fondos y Escenarios

El juego incluye **4 fondos parallax** diferentes, cada uno con múltiples capas que se mueven a distintas velocidades para dar sensación de profundidad. El jugador puede elegir qué fondo quiere usar desde la configuración (es una preferencia visual, no cambia el gameplay).

Los fondos están disponibles como sprites con capas separadas (Capa 1 = más lejana / más lenta, Capa 5 = más cercana / más rápida).

---

## 13. Assets Disponibles

Todos estos assets ya existen y pueden usarse directamente:

**Personaje:**
- Sprite sheet del alien con todas las animaciones
- Frames individuales por animación (IDLE, RUN, HIT, JUMP, BLINK, FALL, DEAD)

**Enemigos:**
- 50 íconos de monstruos (Icon1.png a Icon50.png)
- Cada uno es un sprite estático que se anima con flotación

**Habilidades:**
- 50 íconos de habilidades (Icon1.png a Icon50.png)
- Usados en los slots de habilidades del HUD

**Fondos:**
- 4 fondos con 5 capas parallax cada uno

---

## 14. Features Futuras (Roadmap)

Estas son las funcionalidades planeadas para versiones futuras. El sistema base debe estar pensado para que estas puedan agregarse:

### Sistema de Mascotas
- Las mascotas se capturan o dropean como items
- Se equipa en el slot "Pet" del equipamiento
- La mascota aparece visualmente en el campo de batalla ayudando al jugador
- Las mascotas tienen su propia progresión y pueden evolucionar

### Más Habilidades
- Desbloquear nuevas habilidades al subir de nivel o al encontrar items especiales
- El jugador elige cuáles 3-5 habilidades tiene activas

### Múltiples Mapas
- Cada mapa tiene sus propios enemigos, fondos y mecánicas de oleadas
- Los mapas se desbloquean progresando

### Sistema de Crafting
- Combinar items para crear equipamiento mejor
- Mejorar items existentes con materiales

### Guilds y Social
- Unirse a clanes con otros jugadores
- Raids cooperativos automáticos
- Rankings globales

### Dungeons Automáticos
- Mazmorras especiales con recompensas únicas
- Se completan en AFK con bonuses especiales

---

## 15. Notas para el Desarrollador

- El juego debe funcionar bien en **pantallas móviles** (orientación vertical principal)
- El loop AFK es clave: el juego debe seguir "corriendo" (al menos simular progreso) cuando está minimizado o cerrado
- Los números de balance (HP de enemigos, daño, escalado por oleada, etc.) son completamente ajustables — el código actual es una referencia, no una restricción
- La UI debe ser legible con un solo vistazo: el jugador tiene que entender su estado de un golpe de vista
- Los efectos visuales no necesitan ser complejos, pero sí deben dar satisfacción al ver el combate
- El humor en los nombres de los monstruos es intencional y parte del estilo del juego

---

*Documento generado como referencia de diseño para la implementación en Godot.*  
*Los valores numéricos específicos quedan a criterio del desarrollador.*