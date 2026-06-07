% este cliente se conecta al servidor de truco, se registra con un nombre y espera mensajes del servidor para jugar su turno. 
% El cliente también maneja la desconexión cuando el juego termina o el servidor cierra la conexión.
:- module(clientejuego, [main/0]).

:- use_module(library(http/websocket)).

% el main pide el nombre del jugador, se conecta al servidor y envía un mensaje de registro. 
% Luego, entra en un bucle para escuchar mensajes del servidor y responder a ellos según el tipo de mensaje recibido.
main :-
    format("Ingresa tu nombre: "),
    read(Nombre),
    format("Conectando a ws://localhost:8316/ws~n", []),
    http_open_websocket('ws://localhost:8316/ws', WebSocket, []),
    ws_send(WebSocket, prolog(join(Nombre))),
    escuchar_mensajes(WebSocket).

escuchar_mensajes(Stream) :-
    %format("Esperando mensajes...~n", []),
    ws_receive(Stream, Message, []),
    procesar_mensaje(Stream, Message).

procesar_mensaje(Stream, Message) :-
    (   Message.opcode == close ->
        format("Conexion cerrada por el servidor~n", [])
    
    % El servidor pide que elija accion
    ;   sub_string(Message.data, _, _, _, "Elija una opcion") ->
        format("~w~n", [Message.data]),
        escuchar_mensajes(Stream)  % espera el mensaje de cartas que viene despues
    
    % El servidor manda las cartas disponibles - aca el jugador elige para la primer mano
    ;   Message.data == "elige_accion" ->
        format("Tu eleccion (numero entre 1 y 4): ~n"),
        read(Eleccion),
        ws_send(Stream, prolog(Eleccion)),
        escuchar_mensajes(Stream)

    % El servidor manda las cartas disponibles - aca el jugador elige
    ;   Message.data == "elige_accion_sin_envido" ->
        format("Tu eleccion (numero entre 1 y 3): ~n"),
        read(Eleccion),
        ws_send(Stream, prolog(Eleccion)),
        escuchar_mensajes(Stream)

    % El servidor pide que tire una carta, lo recibe por mensaje que contiene "Que carta tira", el jugador ingresa la carta a tirar y se la manda al servidor
    ;   sub_string(Message.data, _, _, _, "Que carta tira") ->
        format("~w~n", [Message.data]),
        format("Tu carta [numero,palo]: "),
        read(Carta),
        ws_send(Stream, prolog(Carta)),
        escuchar_mensajes(Stream)

    % El servidor pide aceptar/rechazar envido o truco
    ;   sub_string(Message.data, _, _, _, "aceptar: y") ->
        format("~w~n", [Message.data]),
        read(Res),
        ws_send(Stream, prolog(Res)),
        escuchar_mensajes(Stream)

    % Cualquier otro mensaje, solo mostrar
    ;   format("~w~n", [Message.data]),
        escuchar_mensajes(Stream)
    ).


/*
% Ya no sirve
xprocesar_mensaje(Stream, Message) :-
    (   Message.data == "tu_turno" ->
        manejar_turno(Stream)
    ;   Message.data == "¡Juego terminado!" ->
        format("~w~n", [Message.data]),
        format("Desconectando...~n", []),
        ws_close(Stream, 1000, "Cliente terminando")
    ;   Message.opcode == close ->
        format("Conexión cerrada por el servidor~n", [])
    ;
        format("Mensaje: ~w~n", [Message]),
        escuchar_mensajes(Stream)
    ).


% Basura
manejar_turno(Stream) :-
    format("¡Es tu turno!~n", []),
    ws_receive(Stream, Opciones, [format(prolog)]),
    format("Opciones disponibles: ~w~n", [Opciones.data]),
    format("Elige una opción: "),
    read(Eleccion),
    ws_send(Stream, prolog(Eleccion)),
    format("Jugada enviada: ~w~n", [Eleccion]),
    escuchar_mensajes(Stream).
*/