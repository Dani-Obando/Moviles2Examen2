import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart'; // necesario para Tappable
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Flame.device.setPortrait();
  runApp(GameWidget(game: GameTemplate()));
}

class GameTemplate extends FlameGame
    with HasKeyboardHandlerComponents, HasCollisionDetection {
  late Ship shipPlayer;
  List<Square> squareEnemies = [];
  List<SpriteComponent> corazones = [];
  late Rect campoJuego;
  late RectangleComponent campoRojo;
  late TextComponent puntosTexto;

  int puntos = 100;
  int golpes = 0;
  int intentosRestantes = 30;
  bool juegoTerminado = false;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    final ancho = size.x * 0.4;
    final alto = size.y * 0.8;
    final left = (size.x - ancho) / 2;
    final top = (size.y - alto) / 2;
    campoJuego = Rect.fromLTWH(left, top, ancho, alto);

    campoRojo = RectangleComponent(
      position: Vector2(campoJuego.left, campoJuego.top),
      size: Vector2(campoJuego.width, campoJuego.height),
      paint: Paint()..color = Colors.blue.withOpacity(0.3),
    );
    add(campoRojo);

   

       puntosTexto = TextComponent(
      text: 'Puntos: $puntos',
      position: Vector2(campoJuego.left, campoJuego.top - 70),
      anchor: Anchor.topLeft,
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 18, color: Colors.white),
      ),
    );
    add(puntosTexto);

    final heartSprite = await loadSprite('hearth.png');
    for (int i = 0; i < 5; i++) {
      final heart = SpriteComponent(
        sprite: heartSprite,
        size: Vector2(24, 24),
        position: Vector2(campoJuego.left + i * 28, campoJuego.top - 40),
        anchor: Anchor.topLeft,
      );
      corazones.add(heart);
      add(heart);
    }


    shipPlayer = Ship(await loadSprite('triangle.png'), campoJuego);
    add(shipPlayer);

    for (int i = 0; i < 3; i++) {
      final square = Square(await loadSprite('square.png'), i, campoJuego);
      squareEnemies.add(square);
      add(square);
    }

    await FlameAudio.audioCache.loadAll(['ball.wav', 'explosion.wav']);
  }

void registrarGolpe() {
  golpes++;
  puntos -= 20;
  puntosTexto.text = 'Puntos: $puntos';

  if (golpes <= 5 && golpes > 0) {
    remove(corazones[5 - golpes]);
  }

  if (golpes > 4 || intentosRestantes <= 0) {
    terminarJuego();
  }
}

  void registrarIntento() {
    intentosRestantes--;
    puntosTexto.text = 'Puntos: $puntos';

    if (golpes > 5 || intentosRestantes <= 0) {
      terminarJuego();
    }
  }

  void terminarJuego() {
    juegoTerminado = true;

    add(TextComponent(
      text: """
Juego terminado
Golpes: $golpes
Puntos: $puntos
Estado: ${_estadoFinal()}
""",
      position: size / 2 - Vector2(0, 40),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 24, color: Colors.white),
      ),
    ));

    add(BotonReinicio());
  }

  void reiniciarJuego() async {
    puntos = 100;
    golpes = 0;
    intentosRestantes = 30;
    juegoTerminado = false;

    children.where((c) => c is! CameraComponent).toList().forEach(remove);
    await onLoad();
  }

 String _estadoFinal() {
  switch (puntos) {
    case 100:
      return "No te tocó ni el aire, excelente.";
    case 80:
      return "Muy bien jugado, casi perfecto.";
    case 60:
      return "Buena partida, se nota práctica.";
    case 40:
      return "Te defendiste, pero te faltó poco.";
    case 20:
      return "Llegaste raspando... cuidado.";
    default:
      return "No sirves para esto.";
  }
}

}

class BotonReinicio extends TextComponent
    with TapCallbacks, GestureHitboxes, HasGameRef<GameTemplate> {
  BotonReinicio()
      : super(
          text: "[ Volver a jugar ]",
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: const TextStyle(fontSize: 18, color: Colors.lightBlue),
          ),
        );

  @override
  Future<void> onLoad() async {
    position = gameRef.size / 2 + Vector2(0, 30);
    add(RectangleHitbox()); // Para detectar el clic
  }

  @override
  void onTapDown(TapDownEvent event) {
    gameRef.reiniciarJuego();
  }
}


class Ship extends SpriteComponent
    with HasGameReference<GameTemplate>, CollisionCallbacks {
  final double velocidad = 300;
  final Rect campo;
  bool leftPressed = false;
  bool rightPressed = false;
  bool upPressed = false;
  bool downPressed = false;

  Ship(Sprite sprite, this.campo) {
    this.sprite = sprite;
    size = Vector2(50.0, 50.0);
    anchor = Anchor.center;
    position = Vector2(campo.left + campo.width / 2, campo.top + campo.height / 2);
    add(RectangleHitbox());

    add(KeyboardListenerComponent(keyDown: {
      LogicalKeyboardKey.keyA: (_) => leftPressed = true,
      LogicalKeyboardKey.keyD: (_) => rightPressed = true,
      LogicalKeyboardKey.keyW: (_) => upPressed = true,
      LogicalKeyboardKey.keyS: (_) => downPressed = true,
    }, keyUp: {
      LogicalKeyboardKey.keyA: (_) => leftPressed = false,
      LogicalKeyboardKey.keyD: (_) => rightPressed = false,
      LogicalKeyboardKey.keyW: (_) => upPressed = false,
      LogicalKeyboardKey.keyS: (_) => downPressed = false,
    }));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.juegoTerminado) return;

    double nextX = position.x;
    double nextY = position.y;

    if (leftPressed) nextX -= velocidad * dt;
    if (rightPressed) nextX += velocidad * dt;
    if (upPressed) nextY -= velocidad * dt;
    if (downPressed) nextY += velocidad * dt;

    if (nextX >= campo.left + width / 2 && nextX <= campo.right - width / 2) {
      position.x = nextX;
    }
    if (nextY >= campo.top + height / 2 && nextY <= campo.bottom - height / 2) {
      position.y = nextY;
    }
  }
}

class Square extends SpriteComponent
    with HasGameReference<GameTemplate>, CollisionCallbacks {
  final int id;
  final Rect campo;
  double velocidad = 0;

  Square(Sprite sprite, this.id, this.campo) {
    this.sprite = sprite;
    size = Vector2(40.0, 40.0);
    anchor = Anchor.center;
    add(RectangleHitbox());
  }

  @override
  Future<void> onMount() async {
    super.onMount();
    resetPosition();
  }

  void resetPosition() {
    final random = Random();
    double x = random.nextDouble() * (campo.width - width) + campo.left;
    position = Vector2(x, campo.top);
    velocidad = (100 + random.nextInt(500)).toDouble();
    game.registrarIntento();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.juegoTerminado) return;
    position.y += velocidad * dt;
    if (position.y > campo.bottom) {
      resetPosition();
    }
  }

  @override
  void onCollision(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Ship) {
      FlameAudio.play('explosion.wav');
      game.registrarGolpe();
      resetPosition();
    }
  }
}
