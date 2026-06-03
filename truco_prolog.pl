:- use_module(library(clpfd)). % Libreria
:- use_module(library(random)). % Libreria 

palos([oro, espada, basto, copa]). 

numeros([rey, caballo, sota, 7, 6, 5, 4, 3, 2, 1]).

crearJugador(Nombre, jugador(Nombre, [], 0, WebSocket), WebSocket).

stock([[rey, oro], [rey, espada], [rey, basto], [rey, copa],
        [caballo, oro], [caballo, espada], [caballo, basto], [caballo, copa],
        [sota, oro], [sota, espada], [sota, basto], [sota, copa],
        [7, oro], [7, espada], [7, basto], [7, copa],
        [6, oro], [6, espada], [6, basto], [6, copa],
        [5, oro], [5, espada], [5, basto], [5, copa],
        [4, oro], [4, espada], [4, basto], [4, copa],
        [3, oro], [3, espada], [3, basto], [3, copa],
        [2, oro], [2, espada], [2, basto], [2, copa],
        [1, oro], [1, espada], [1, basto], [1, copa]]).

valor_truco(1,espada,1).
valor_truco(1,basto, 2).
valor_truco(7,espada, 3).
valor_truco(7,oro, 4).
valor_truco(3,_, 5).
valor_truco(2,_, 6).
valor_truco(1,oro, 7).
valor_truco(1,copa, 7).
valor_truco(rey,_, 8).
valor_truco(caballo,_, 9).
valor_truco(sota,_, 10).
valor_truco(7,basto, 11).
valor_truco(7,copa, 11).
valor_truco(6,_, 12).
valor_truco(5,_, 13).
valor_truco(4,_, 14).

valor_envido(rey, 0).
valor_envido(caballo, 0).
valor_envido(sota, 0).
valor_envido(7, 7).
valor_envido(6, 6).
valor_envido(5, 5).
valor_envido(4, 4).
valor_envido(3, 3).
valor_envido(2, 2).
valor_envido(1, 1).

estado(S0, S, S0, S). % estado(EntradaVisible, SalidaVisible, EntradaDCG, SalidaDCG).

truco(Jugadores) -->
    crearJugadores(Jugadores),
    jugar_rondas.

crearJugadores(Jugadores) -->
    estado(S0, S),
    {
    	S = [ronda(1, jugadores(Jugadores)),jugadores(Jugadores)|S0] % Almacena todos los jugadores con el stock
    }.

mezclar -->
    estado(S0, S), % Paso de estado S0 a S
    {
	stock(Cartas), % Llama al stock de cartas, obteniendo todas las cartas
	random_permutation(Cartas, CartasMezcladas), % Mezcla las cartas
	S = [stock(CartasMezcladas), envido(0,_), truco(1)|S0] % Añade el stock con las cartas mezcladas con S1 (sin stock(cartas))
    }. % Se actualiza con el mazo mezclado

repartir_una_carta --> % Se llamara 3 veces
    estado(S0, S),
    {
        select(jugadores(Jugadores), S0, S1), % Saca los jugadores de S0 y tiene una lista S1 sin esos jugadores
		select(stock(Cartas), S1, S2),
      	select(ronda(N,jugadores(_)), S2, S3),% Saca el stock de cartas mezclada(Ahora solo cartas por la unificacion)
        % de S1 (Lista actualizada) y queda S2 sin los jugadores y las cartas
        repartir_una_carta(Jugadores, Jugadores1, Cartas, Cartas1), % Reparte una vez la carta
        S = [ronda(N,jugadores(Jugadores1)), jugadores(Jugadores1), stock(Cartas1)|S3] % Actualiza el estado de los jugadores y el stock de cartas que disminuyo
    }.

repartir_una_carta([], [], Cs, Cs).
repartir_una_carta([P|Ps], [P1|Ps1], [C|Cs], Cs1) :- % (jugadorAntes, JugadorDespues, CartasAntes, CartasDespues)
    P = jugador(N, A, B, WS), % Afirma que P tiene forma de jugador, no es un igual sino una unificacion
    P1 = jugador(N, [C|A], B, WS), % Crea un nuemo jugador con P1 asignandole el mismo nombre, solo le agrega la carta
    repartir_una_carta(Ps, Ps1, Cs, Cs1). % Luego llama para hacer lo mismo con el otro jugador

jugar_rondas -->
    estado(S0, S0), % no me importa el estado de salida, solo me interesa el estado de entrada S0 para obtener los puntos de los jugadores
    mezclar, % Aca llama a mezclar las cartas
    repartir_una_carta, % Aca reparte solo una vez las cartas, por eso se llama 3 veces
    repartir_una_carta,
    repartir_una_carta,
    estado(S1, S2),
    {
    select(jugadores([jugador(_,_,PJ1, _), jugador(_,_,PJ2, _)]), S0, _), % Seleccione los jugadores macheando sus puntos de S0
    % y evalua el puntaje de ambos jugadores, si los puntajes son menores a 30, se sigue jugando, sino se termina el juego
    % cada jugador con su nombre, cartas en mano y puntos
    (PJ1 #< 30, PJ2 #< 30),
    catch(jugar_primer_mano(S1,S2), irse_al_mazo(S2), true) %para irse al mazo
    % jugar_primer_mano(S1,S2)
    },
    cambiar_ronda,
    jugar_rondas.

jugar_rondas --> % Caso donde se termina el juego, es decir, cuando alguno de los jugadores llega a 30 puntos o mas
    estado(S, S), % No cambia el estado, solo lo lee, osea cuando veamos estado(S,S) es porque no se va a modificar el estado, solo se va a leer
    {select(jugadores([jugador(N1,_,PJ1, Ws1),jugador(N2,_,PJ2, Ws2)]), S, _), % Seleccione los jugadores macheando sus puntos de S0
    % Condicional para determinar el ganador, el jugador con mas puntos es el ganador, y se muestra su nombre y puntaje
    (PJ1 #> PJ2 ->
        format(atom(Msg), "El ganador es ~w con ~w puntos", [N1, PJ1])
    ;
        format(atom(Msg), "El ganador es ~w con ~w puntos", [N2, PJ2])
	),
    ws_send(Ws1, text(Msg)),
    ws_send(Ws2, text(Msg))
    }.

cambiar_ronda -->
    estado(S0,S),
    {
    select(ronda(R, jugadores(Js)), S0, S1),
    select(jugadores([jugador(Nombre1, _, _, _),jugador(_, _, _, _)]), S1, S2),
    select(stock(_), S2, S3),
    select(envido(PuntosEnvido, GanadorEnvido), S3, S4),
    select(truco(PuntosTruco), S4, S5),
    Js = [jugador(Ganador, _, PG, WsG), jugador(Perdedor, _, PP, WsP)],
    R1 #= R + 1,
    
    (GanadorEnvido = Ganador ->
    PuntosGanador #= PG + PuntosTruco + PuntosEnvido,
    	PuntosPerdedor #= PP
	;
    PuntosGanador #= PG + PuntosTruco,
        PuntosPerdedor #= PP + PuntosEnvido
	),
    GanadorActualizado = jugador(Ganador, [], PuntosGanador, WsG),
    PerdedorActualizado = jugador(Perdedor, [], PuntosPerdedor, WsP),
    format(atom(MsgPuntaje), "Puntaje - ~w: ~w | ~w: ~w", [Ganador, PuntosGanador, Perdedor, PuntosPerdedor]),
    ws_send(WsG, text(MsgPuntaje)),
    ws_send(WsP, text(MsgPuntaje)),
    
    (	Ganador = Nombre1 ->  
    	S = [ronda(R1, jugadores([PerdedorActualizado, GanadorActualizado])),
      	jugadores([PerdedorActualizado, GanadorActualizado])| S5]
    ;   
    	S = [ronda(R1, jugadores([GanadorActualizado, PerdedorActualizado])),
      	jugadores([GanadorActualizado, PerdedorActualizado])| S5]
    )
    }.

jugar_primer_mano --> % P es el jugador actual, Ps es la lista de jugadores restantes
    estado(S0, S),
    {	
        select(ronda(NumeroRonda, jugadores([P1, P2])), S0, _), % Saca el estado con los jugadores de S0 generando S1 sin esos jugadores
        P1 = jugador(NombreP1, CartasEnManoP1, _, Ws1), % pattern matching para obtener el nombre y las cartas en mano del jugador actual
        P2 = jugador(NombreP2, CartasEnManoP2, _, Ws2),
      	% Aca se establece un turno y aparecen las opciones disponibles para el jugador, se muestra su nombre y las cartas que tiene en mano
    	%format("//////////RONDA N° ~w//////////~n", [NumeroRonda]),
        format(atom(MsgRonda), "//////////RONDA N° ~w//////////~n", [NumeroRonda]),
        ws_send(Ws1, text(MsgRonda)),
        ws_send(Ws2, text(MsgRonda)),
        ws_send(Ws2, text("Esta jugando sus cartas el jugador contrario...")),

        format(atom(MsgTurnoJ1), "Es su turno ~a! Elija una opcion: ~n 1. Cantar envido ~n 2. Cantar truco ~n 3. Jugar carta ~n 4. Irse al mazo~n", [NombreP1]),
        ws_send(Ws1, text(MsgTurnoJ1)),
      	format(atom(MsgCartasJ1), "cartas restantes: ~w", [CartasEnManoP1]),
        ws_send(Ws1, text(MsgCartasJ1)),
        ws_send(Ws1, text("elige_accion")),
    	cargar_accion_primer_mano(NombreP1, Ws1, S0, S2),

        ws_send(Ws1, text("Que carta tira? escribir de forma: [NUMERO,PALO]~n")),

      	cargarCarta_ws(CartasEnManoP1, C1, Ws1), % Se lee la opcion ingresada por el jugador, y se evalua con el DCG buscar_opciones
        
        format(atom(MsgTirarCartaJ1), "el jugador ~a tira la carta: ~w~n", [NombreP1, C1]),
        ws_send(Ws1, text(MsgTirarCartaJ1)),
        ws_send(Ws2, text(MsgTirarCartaJ1)),
        % para determinar que accion se va a realizar dependiendo de la opcion ingresada
        % la carta que quiere tirar, sus cartas en mano y se obtiene el nuevo estado del jugador despues de 
        % tirar la carta
        format(atom(MsgTurnoJ2), "Es su turno ~a! Elija una opcion: ~n 1. Cantar envido ~n 2. Cantar truco ~n 3. Jugar carta ~n 4. Irse al mazo~n", [NombreP2]),
      	format(atom(MsgCartasJ2), "cartas restantes: ~w", [CartasEnManoP2]),
        ws_send(Ws1, text("Esta jugando sus cartas el jugador contrario...")), % ← a Ws1, no Ws2
        ws_send(Ws2, text(MsgTurnoJ2)),
        ws_send(Ws2, text(MsgCartasJ2)),
        ws_send(Ws2, text("elige_accion")),
        cargar_accion_primer_mano(NombreP2, Ws2, S2, S3),

        ws_send(Ws2, text("Que carta tira? escribir de forma: [NUMERO,PALO]~n")),
    	
        cargarCarta_ws(CartasEnManoP2, C2, Ws2),
        
        format(atom(MsgTirarCartaJ2), "el jugador ~a tira la carta: ~w~n", [NombreP2, C2]),
        ws_send(Ws2, text(MsgTirarCartaJ2)),
        ws_send(Ws1, text(MsgTirarCartaJ2)),

        tirar_carta(P1, C1, P1Actualizado),
        tirar_carta(P2, C2, P2Actualizado),
        comparar_cartas(C1, C2, [P1Actualizado, P2Actualizado], ArregloJugadores, Ws1, Ws2), % Compara las cartas tiradas por ambos 
        % jugadores y determina quien gana la mano, se obtiene un arreglo con los jugadores actualizados
        S = [ronda(NumeroRonda, jugadores(ArregloJugadores))|S3] % Actualiza el estado con los jugadores actualizados despues de jugar la mano, se mantiene el resto del estado igual a S1
    },
    jugar_segunda_mano.

jugar_segunda_mano --> % P es el jugador actual, Ps es la lista de jugadores restantes
    estado(S, S2), % No cambia el estado, solo lo lee, osea cuando veamos estado(S,S) es porque no se va a modificar el estado, solo se va a leer
    {	
        member(ronda(_, jugadores([P1, P2])), S), % Verifica si 
        P1 = jugador(NombreP1, CartasEnManoP1, _, Ws1), % pattern matching para obtener el nombre y las cartas en mano del jugador actual
      	% Aca se establece un turno y aparecen las opciones disponibles para el jugador, se muestra su nombre y las cartas que tiene en mano
        P2 = jugador(NombreP2, CartasEnManoP2, _, Ws2),

		format(atom(MsgTurnoJ1), "es el turno de ~a! Elija una opcion: ~n 1. Cantar truco ~n 2. Jugar carta ~n 3. Irse al mazo~n", [NombreP1]),
        ws_send(Ws1, text(MsgTurnoJ1)),
        format(atom(MsgCartasJ1), "cartas restantes: ~w", [CartasEnManoP1]),
        ws_send(Ws1, text(MsgCartasJ1)),
        ws_send(Ws1, text("elige_accion")),

        ws_send(Ws2, text("Esta jugando sus cartas el jugador contrario...")),    
        
      	cargar_accion(NombreP1, Ws1, S, S1),
        
        ws_send(Ws1, text("Que carta tira? escribir de forma: [NUMERO,PALO]~n")),

      	cargarCarta_ws(CartasEnManoP1, C1, Ws1),% Se lee la opcion ingresada por el jugador, y se evalua con el DCG buscar_opciones
        format(atom(MsgTirarCartaJ1), "el jugador ~a tira la carta: ~w~n", [NombreP1, C1]),
        ws_send(Ws1, text(MsgTirarCartaJ1)),
        ws_send(Ws2, text(MsgTirarCartaJ1)),
        % para determinar que accion se va a realizar dependiendo de la opcion ingresada
        format(atom(MsgTurnoJ2), "es el turno de ~a! Elija una opcion: ~n 1. Cantar truco ~n 2. Jugar carta ~n 3. Irse al mazo~n", [NombreP2]),
        format(atom(MsgCartasJ2), "cartas restantes: ~w", [CartasEnManoP2]),
        
        ws_send(Ws1, text("Esta jugando sus cartas el jugador contrario...")), % ← a Ws1, no Ws2
        ws_send(Ws2, text(MsgTurnoJ2)),
        ws_send(Ws2, text(MsgCartasJ2)),
        ws_send(Ws2, text("elige_accion")),

        cargar_accion(NombreP2, Ws2, S1, S2),
        ws_send(Ws2, text("Que carta tira? escribir de forma: [NUMERO,PALO]~n")),

      	cargarCarta_ws(CartasEnManoP2, C2, Ws2),

        format(atom(MsgTirarCartaJ2), "el jugador ~a tira la carta: ~w~n", [NombreP2, C2]),
        ws_send(Ws2, text(MsgTirarCartaJ2)),
        ws_send(Ws1, text(MsgTirarCartaJ2)),

      	tirar_carta(P1, C1, P1Actualizado),
        tirar_carta(P2, C2, P2Actualizado),
        comparar_cartas(C1, C2, [P1Actualizado, P2Actualizado], [P1nuevo, P2nuevo], Ws1, Ws2) % Compara las cartas tiradas por ambos 
        % jugadores y determina quien gana la mano, se obtiene un arreglo con los jugadores actualizados
    },
    verificar_si_gano([P1Actualizado, P2Actualizado], [P1nuevo, P2nuevo]). % Verifica si gano la ronda despues de jugar la segunda mano, dependiendo de los resultados de ambas manos, se determina si se termina la ronda o se juega la tercera mano

% El primer parametro es el resultado de la primera mano y el segundo es el de la segunda mano
% Si son iguales es porque el mismo jugador P1 gano ambas manos, entonces se termina la ronda aca
verificar_si_gano([P1, P2], [P1, P2]) -->
    estado(S0, S),
    {
        select(ronda(N, _), S0, S1), % Saca el estado con los jugadores de S0 generando S1 sin esos jugadores
        P1 = jugador(NombreP1, _, _, Ws1),
        P2 = jugador(_, _, _, Ws2),
        format(atom(MsgGana), "~a gana esta ronda!", [NombreP1]),
        ws_send(Ws1, text(MsgGana)),
        ws_send(Ws2, text(MsgGana)),
        S = [ronda(N, jugadores([P1, P2]))|S1]
    }.

% El primer parametro es el resultado de la primera mano y el segundo es el de la segunda mano
% Si no son iguales es porque cada mano la gano un jugador distinto, entonces se juega la tercera
verificar_si_gano([_, _], [P1nuevo, P2nuevo]) -->
    estado(S0, S),
    {
        select(ronda(N, _), S0, S1), % Saca el estado con los jugadores de S0 generando S1 sin esos jugadores
        S = [ronda(N, jugadores([P1nuevo, P2nuevo]))|S1]
    },
    jugar_tercera_mano.

jugar_tercera_mano --> % P es el jugador actual, Ps es la lista de jugadores restantes
    estado(S0, S), % no modifica nada solo lee el estado actual
    {	
        select(ronda(NumeroRonda, jugadores([P1, P2])), S0, S1), % Saca los jugadores de S0 generando S1 sin esos jugadores
      	% Aca se establece un turno y aparecen las opciones disponibles para el jugador, se muestra su nombre y las cartas que tiene en mano
        P1 = jugador(NombreP1, CartasEnManoP1, _, Ws1),
    	P2 = jugador(NombreP2, CartasEnManoP2, _, Ws2),

    	format(atom(MsgTurnoP1), "es el turno de ~a! Elija una opcion: ~n 1. Cantar truco ~n 2. Jugar carta ~n 3. Irse al mazo~n", [NombreP1]),
        ws_send(Ws1, text(MsgTurnoP1)),
        format(atom(MsgCartasJ1), "cartas restantes: ~w", [CartasEnManoP1]),
        ws_send(Ws1, text(MsgCartasJ1)),
        ws_send(Ws1, text("elige_accion")),

        ws_send(Ws2, text("Esta jugando sus cartas el jugador contrario...")),

      	
        cargar_accion(NombreP1, Ws1, S1, S2),

        ws_send(Ws1, text("Que carta tira? escribir de forma: [NUMERO,PALO]~n")),

      	cargarCarta_ws(CartasEnManoP1, C1, Ws1),% Se lee la opcion ingresada por el jugador, y se evalua con el DCG buscar_opciones
        format(atom(MsgTirarCartaJ1), "el jugador ~a tira la carta: ~w~n", [NombreP1, C1]),
        ws_send(Ws1, text(MsgTirarCartaJ1)),
        ws_send(Ws2, text(MsgTirarCartaJ1)),
        % para determinar que accion se va a realizar dependiendo de la opcion ingresada
        format(atom(MsgTurnoJ2), "es el turno de ~a! Elija una opcion: ~n 1. Cantar truco ~n 2. Jugar carta ~n 3. Irse al mazo~n", [NombreP2]),
        

        format(atom(MsgCartasJ2), "cartas restantes: ~w", [CartasEnManoP2]),
        ws_send(Ws1, text("Esta jugando sus cartas el jugador contrario...")), % ← a Ws1, no Ws2
        ws_send(Ws2, text(MsgTurnoJ2)),
        ws_send(Ws2, text(MsgCartasJ2)),
        ws_send(Ws2, text("elige_accion")),

      	cargar_accion(NombreP2, Ws2, S2, S3),
        ws_send(Ws2, text("Que carta tira? escribir de forma: [NUMERO,PALO]~n")),
      	cargarCarta_ws(CartasEnManoP2, C2, Ws2),
        
        format(atom(MsgTirarCartaJ2), "el jugador ~a tira la carta: ~w~n", [NombreP2, C2]),
        ws_send(Ws2, text(MsgTirarCartaJ2)),
        ws_send(Ws1, text(MsgTirarCartaJ2)),

        tirar_carta(P1, C1, P1Actualizado),
        tirar_carta(P2, C2, P2Actualizado),
        comparar_cartas(C1, C2, [P1Actualizado, P2Actualizado], [Ganador,Perdedor], Ws1, Ws2), % Compara las cartas tiradas por ambos 
        % jugadores y determina quien gana la mano, se obtiene un arreglo con los jugadores actualizados, donde el primer elemento es el ganador y el segundo el perdedor
        Ganador = jugador(NombreGanador, [], _, _),
        format(atom(MsgGanador), "~a gana esta ronda!~n", [NombreGanador]),
        ws_send(Ws1, text(MsgGanador)),
        ws_send(Ws2, text(MsgGanador)),
        S = [ronda(NumeroRonda, jugadores([Perdedor, Ganador]))|S3]
    }.

accion_primer_mano(1, NombreAccion) -->
    estado(S0, S),
    {
        select(envido(0, _), S0, S1), % Saca el estado con el envido de S0 generando S1 sin ese estado
        S = [envido(0, NombreAccion)|S1]
    }, % Actualiza el estado con el nuevo envido cantado 
    envido_querido.

accion_primer_mano(1, _) -->
    estado(S0, S),
    {
        select(envido(PuntosEnvido, _), S0, _), % Saca el estado con el envido de S0 generando S1 sin ese estado
        PuntosEnvido #> 0, % Verifica que el envido ya haya sido cantado, para poder cantar un nuevo envido
        S = S0, % No se actualiza el estado porque no se puede cantar un nuevo envido, se mantiene el mismo estado
        select(ronda(_, jugadores([jugador(_,_,_,Ws1), jugador(_,_,_,Ws2)])), S0, _),
        ws_send(Ws1, text("No se puede cantar envido, ya fue cantado!")),
        ws_send(Ws2, text("No se puede cantar envido, ya fue cantado!"))
    }.

accion_primer_mano(2, NombreAccion) -->
    estado(S, S),
    {
        select(truco(1), S, _),
        % Antes
   		% format("El jugador ~a canta el truco!~n aceptar: Y rechazar: N", [NombreAccion]),
    	% read(Res)

        % Despues con WebSockets
        select(ronda(_, jugadores([jugador(NombreP1,_,_,WS1), jugador(_,_,_,WS2)])), S, _),
        format(atom(MsgTruco), "~a canta truco! aceptar: y rechazar: n", [NombreAccion]),
        ( NombreAccion = NombreP1 ->  
            ws_send(WS2, text(MsgTruco)),
            ws_send(WS1, text("Esta decidiendo si aceptar o rechazar el truco...")),
            ws_receive(WS2, MensajeRes, [format(prolog)])
        ;   
            ws_send(WS1, text(MsgTruco)),
            ws_send(WS2, text("Esta decidiendo si aceptar o rechazar el truco...")),
            ws_receive(WS1, MensajeRes, [format(prolog)])
        ),
        Res = MensajeRes.data
    },
    accion_truco_decision(Res, NombreAccion). % es basicamente quiero o no quiero el truco.

accion_primer_mano(2, NombreAccion) -->
    estado(S,S),
    {
       	select(truco(2), S, _),
   		select(ronda(_, jugadores([jugador(_,_,_,Ws1), jugador(_,_,_,Ws2)])), S, _),
        format(atom(MsgTruco), "El truco ya esta cantado jugador ~a!", [NombreAccion]),
        ws_send(Ws1, text(MsgTruco)),
        ws_send(Ws2, text(MsgTruco))
    }.
 
    
accion_primer_mano(3, _) --> [].

accion_primer_mano(4, NombreAccion) -->
    estado(S0, S),
    {
    	select(ronda(NumeroRonda, jugadores([jugador(J1,C1,PJ1, Ws1), jugador(J2,C2,PJ2, Ws2)])), S0, S1),
        format(atom(MsgMazo), "~a se va al mazo!", [NombreAccion]),
        ws_send(Ws1, text(MsgMazo)),
        ws_send(Ws2, text(MsgMazo)),
        ( NombreAccion = J1 ->
        Perdedor = jugador(J1,C1,PJ1, Ws1),
        Ganador = jugador(J2,C2,PJ2, Ws2)% caso 1: J1 se va al mazo
		;
    	Ganador = jugador(J1,C1,PJ1, Ws1),
        Perdedor = jugador(J2,C2,PJ2, Ws2)% caso 2: J2 se va al mazo
		),
        S = [ronda(NumeroRonda, jugadores([Ganador, Perdedor]))|S1],
    throw(irse_al_mazo(S))
    }.

accion_truco_decision(Res, _) -->
    estado(S0,S),
    {
    	Res = y,
      	select(ronda(_, jugadores([jugador(_,_,_,Ws1), jugador(_,_,_,Ws2)])), S0, _),
        ws_send(Ws1, text("QUIERO")),
        ws_send(Ws2, text("QUIERO")),
        select(truco(NivelTruco), S0, S1), % Saca el estado con el nivel de truco de S0 generando S1 sin ese estado
        NuevoNivelTruco #= NivelTruco + 1, % Aumenta el nivel de truco
        S = [truco(NuevoNivelTruco)|S1] % Actualiza el estado con el nuevo nivel de truco
    }.

accion_truco_decision(Res,NombreAccion) -->
    estado(S0,S),
    {
    	Res = n,
      	select(ronda(_, jugadores([jugador(_,_,_,Ws1), jugador(_,_,_,Ws2)])), S0, _),
        ws_send(Ws1, text("NO QUIERO")),
        ws_send(Ws2, text("NO QUIERO")),
        select(ronda(NumeroRonda, jugadores(Js)), S0, S1),
        (
            Js = [jugador(NombreAccion,_,_, Ws1), jugador(_,_,_, Ws2)]
        ;
            Js = [jugador(_,_,_, Ws1), jugador(NombreAccion,_,_, Ws2)]
        ),
        S = [ronda(NumeroRonda, jugadores(Js))|S1],
        throw(irse_al_mazo(S))
    }.  
    

accion(1, NombreAccion) -->
    estado(S, S),
    {
       	select(truco(2), S, _),
   		select(ronda(_, jugadores([jugador(_,_,_,Ws1), jugador(_,_,_,Ws2)])), S, _),
        format(atom(MsgTruco), "El truco ya esta cantado jugador ~a!", [NombreAccion]),
        ws_send(Ws1, text(MsgTruco)),
        ws_send(Ws2, text(MsgTruco))
    }.

accion(1, NombreAccion) -->
    estado(S, S),
    {
    select(truco(1), S, _),
    % Antes
    %format("El jugador ~a canta el truco!~n aceptar: Y rechazar: N", [NombreAccion]),
    %read(Res)
    
    % Despues con WebSockets
    select(ronda(_, jugadores([jugador(NombreP1,_,_,WS1), jugador(_,_,_,WS2)])), S, _),
    format(atom(MsgTruco), "~a canta truco! aceptar: y rechazar: n", [NombreAccion]),
    ( NombreAccion = NombreP1 ->  
        ws_send(WS2, text(MsgTruco)),
        ws_send(WS1, text("Esta decidiendo si aceptar o rechazar el truco...")),
        ws_receive(WS2, MensajeRes, [format(prolog)])
    ;   
        ws_send(WS1, text(MsgTruco)),
        ws_send(WS2, text("Esta decidiendo si aceptar o rechazar el truco...")),
        ws_receive(WS1, MensajeRes, [format(prolog)])
    ),
    Res = MensajeRes.data
    
    },
    accion_truco_decision(Res, NombreAccion).

accion(2, _) --> [].

accion(3, NombreAccion) -->
    estado(S0, S),
    {
        select(ronda(NumeroRonda, jugadores([jugador(J1,C1,PJ1,Ws1), jugador(J2,C2,PJ2,Ws2)])), S0, S1),
        format(atom(MsgMazo), "~a se va al mazo!", [NombreAccion]),
        ws_send(Ws1, text(MsgMazo)),
        ws_send(Ws2, text(MsgMazo)),
        ( NombreAccion = J1 ->
            Perdedor = jugador(J1,C1,PJ1,Ws1),
            Ganador  = jugador(J2,C2,PJ2,Ws2) % caso 1: J1 se va al mazo
        ;
            Ganador  = jugador(J1,C1,PJ1,Ws1),
            Perdedor = jugador(J2,C2,PJ2,Ws2)
        ),
        S = [ronda(NumeroRonda, jugadores([Ganador, Perdedor]))|S1],
        throw(irse_al_mazo(S))
    }.

envido_querido --> 
    estado(S0, S),
    {
        select(ronda(_, jugadores(Js)), S0, S1), % Saca el estado con los jugadores de S0 generando S1 sin esos jugadores
        select(envido(0, NombreCanto), S1, S2), % Saca el estado con el envido de S1 generando S2 sin ese estado
        Js = [jugador(NombreP1, CartasEnManoP1, _, WS1), jugador(NombreP2, CartasEnManoP2, _, WS2)],

        % ANTES
        % format("~a canta envido! ~n aceptar: Y ~n rechazar: N", [NombreCanto]),
        % read(Res),
    
        % DESPUES con WebSockets
        format(atom(MsgEnvido), "~a canta envido! aceptar: y rechazar: n", [NombreCanto]),
        % Se lo mandamos a AMBOS jugadores
        % Pero solo el que NO canto decide, entonces leemos del otro jugador
        ( NombreCanto = NombreP1 ->  
            ws_send(WS2, text(MsgEnvido)),
            ws_send(WS1, text("Esta decidiendo si aceptar o rechazar el envido...")),
            ws_receive(WS2, MensajeRes, [format(prolog)])  % decide P2
        ;   
            ws_send(WS1, text(MsgEnvido)),
            ws_send(WS2, text("Esta decidiendo si aceptar o rechazar el envido...")),
            ws_receive(WS1, MensajeRes, [format(prolog)])  % decide P1
        ),
        Res = MensajeRes.data,

        ( Res = y ->
    	sumarPuntos(CartasEnManoP1, PuntosEnvidoP1),
    	sumarPuntos(CartasEnManoP2, PuntosEnvidoP2),
        format(atom(MsgPE), "Puntos envido - ~a: ~w | ~a: ~w", [NombreP1, PuntosEnvidoP1, NombreP2, PuntosEnvidoP2]),
        ws_send(WS1, text(MsgPE)),
        ws_send(WS2, text(MsgPE)),
    	( PuntosEnvidoP1 >= PuntosEnvidoP2 ->
        	Ganador = NombreP1
    	;
        	Ganador = NombreP2
    	),
    	PuntosEnvido #= 2,
        format(atom(MsgGE), "~a gano el envido!", [Ganador]),
        ws_send(WS1, text(MsgGE)),
        ws_send(WS2, text(MsgGE))
		;
    	Res = n ->
    	PuntosEnvido #= 1,
    	Ganador = NombreCanto
		),
        S = [envido(PuntosEnvido, Ganador)|S2] % Actualiza el estado con el nuevo puntaje del jugador que canto envido
    }.

tirar_carta(Jugador, CartaUsada, NuevoEstadoJugador) :-
    Jugador = jugador(Nombre, CartasEnMano, Puntos, Ws), % Pattern matching para obtener el nombre, las cartas en mano y los puntos del jugador
    member(CartaUsada, CartasEnMano),
    select(CartaUsada, CartasEnMano, ManoActualizada), % Saca la carta usada de las cartas en mano del jugador
    NuevoEstadoJugador = jugador(Nombre, ManoActualizada, Puntos, Ws). % Crea un nuevo estado del jugador con las cartas actualizadas y los mismos puntos

% Esta parte compara las cartas, es el caso de que el jugador 1 gana o se emparda la mano
comparar_cartas([NumeroJ1, PaloJ1], [NumeroJ2, PaloJ2], [P1, P2], [P1, P2], Ws1, Ws2) :-
    valor_truco(NumeroJ1, PaloJ1, Valor1),
    valor_truco(NumeroJ2, PaloJ2, Valor2),
    Valor1 #=< Valor2,
    P1 = jugador(NombreGanador, _, _, _), 
    format(atom(MsgGana), "~a gana esta mano!", [NombreGanador]),
    ws_send(Ws1, text(MsgGana)),
    ws_send(Ws2, text(MsgGana)).

% Este caso es el caso de que el jugador 2 gana la mano
comparar_cartas([NumeroJ1, PaloJ1], [NumeroJ2, PaloJ2], [P1, P2], [P2, P1], Ws1, Ws2) :-
    valor_truco(NumeroJ1, PaloJ1, Valor1),
    valor_truco(NumeroJ2, PaloJ2, Valor2),
    Valor1 #> Valor2,
    P2 = jugador(NombreGanador, _, _, _),
    format(atom(MsgGana), "~a gana esta mano!", [NombreGanador]),
    ws_send(Ws1, text(MsgGana)),
    ws_send(Ws2, text(MsgGana)).
  
% Esta parte no la comente pero se entiende que es la parte de calcular el puntaje del envido,
% se obtiene las cartas de cada jugador y se calculan las combinaciones posibles 
% para obtener el puntaje maximo de envido
sumarPuntos([[Numero1,Palo1], [Numero2,Palo2], [Numero3,Palo3]], Z) :-
    combinaciones([[Numero1,Palo1], [Numero2,Palo2], [Numero3,Palo3]], X),maximo(X, Z).

combinaciones([[Numero1,_]],[Val]):-
    valor_envido(Numero1,Val).

combinaciones([[Num,Palo]|Cola], Resto):-
    suma([Num,Palo], Cola, Res),
    combinaciones(Cola,L1),
    append(L1,Res,Resto).

suma([Numero1,_],[],[Val]):-
    valor_envido(Numero1,Val).

suma([Numero1,Palo1], [[Numero2,Palo2]|Cola],[Res|Resto]):-
    Palo1 == Palo2,
    valor_envido(Numero1,X1),
    valor_envido(Numero2,X2),
    Res is 20 + X1 + X2,
    suma([Numero1,Palo1], Cola, Resto).

suma([Numero1,Palo1], [[_,Palo2]|Cola], Res):-
    Palo1 \= Palo2,
    suma([Numero1,Palo1], Cola, Res).

maximo([X], X).
maximo([Elem|Cola], Max) :-
    maximo(Cola, Resto),
    Max is max(Elem, Resto).

cargarCarta(CartasEnMano, Respuesta) :-
    format("cartas restantes: ~w~n", [CartasEnMano]),
    repetir(CartasEnMano, Respuesta).

repetir(CartasEnMano, Respuesta) :-
    read(Opcion),
    member(Opcion, CartasEnMano),
    Respuesta = Opcion.

repetir(CartasEnMano, Respuesta):-
    format("opcion invalida, ingrese nuevamente~n"),
    repetir(CartasEnMano, Respuesta).

cargar_accion_primer_mano(NombreP, Ws) --> 
    {repetirAccion_ws(Respuesta, Ws)},
    accion_primer_mano(Respuesta, NombreP).

cargar_accion(NombreP, Ws) -->
    {repetirAccion_ws(Respuesta, Ws)},
    accion(Respuesta, NombreP).

% Viejos lectores, no los borre por siacaso estan contenido en las lineas

% --------------------------------------------------------------------------
repetirAccion(Respuesta) :-
    read(Opcion),
    Opcion #< 5,
    Opcion #> 0,
    Respuesta = Opcion.

repetirAccion(Respuesta):-
    format("opcion invalida, ingrese nuevamente~n"),
    repetirAccion(Respuesta).

% --------------------------------------------------------------------------

% Parte del servidor para manejar los websockets

repetir_ws(CartasEnMano, Respuesta, Ws) :-
    ws_receive(Ws, Mensaje, [format(prolog)]),
    Opcion = Mensaje.data,
    ( member(Opcion, CartasEnMano)
    ->  Respuesta = Opcion
    ;   ws_send(Ws, text("opcion invalida, ingrese nuevamente")),
        repetir_ws(CartasEnMano, Respuesta, Ws)
    ).

repetirAccion_ws(Respuesta, Ws) :-
    ws_receive(Ws, Mensaje, [format(prolog)]),
    Opcion = Mensaje.data,
    ( integer(Opcion), Opcion > 0, Opcion < 5 ->  
        Respuesta = Opcion
    ;   
        ws_send(Ws, text("opcion invalida, ingrese nuevamente")),
        ws_send(Ws, text("elige_accion")),
        repetirAccion_ws(Respuesta, Ws)
    ).

cargarCarta_ws(CartasEnMano, Respuesta, Ws) :-
    format(atom(Msg), "cartas disponibles: ~w", [CartasEnMano]),
    ws_send(Ws, text(Msg)),
    repetir_ws(CartasEnMano, Respuesta, Ws).

