:- use_module(library(clpfd)). % Libreria
:- use_module(library(random)). % Libreria 

palos([oro, espada, basto, copa]). 

numeros([rey, caballo, sota, 7, 6, 5, 4, 3, 2, 1]).

crearJugador(Nombre, jugador(Nombre, [], [_])).

jugador(_, [_], [_]).

puntos_truco([_], [_]).

puntos_envido([_], [_]).

jugadores([jugador(_, [_], 0), jugador(_, [_], 0)]).

% jugadores([jugador(j1,[[2, espada], [4, oro], [3, espada]],[_]), jugador(j2,[[caballo, copa], [3, copa], [1, copa]],[_])]).

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

carta([Numero,Palo]):-
    palos(ListaPalos),
    numeros(ListaNumeros),
    member(Numero, ListaNumeros),
    member(Palo, ListaPalos).

mezclar -->
    estado(S0, S), % Paso de estado S0 a S
    {
	select(stock(Cartas), S0, S1), % Saca el stock de cartas de S0 generando S1 sin ese stock
	random_permutation(Cartas, CartasMezcladas), % Mezcla las cartas
	S = [stock(CartasMezcladas)|S1] % Añade el stock con las cartas mezcladas con S1 (sin stock(cartas))
    }. % Se actualiza con el mazo mezclado

truco -->
    crearJugadores([j1,j2]).
    jugar_rondas.
    %envido,
    %envido,
    %realEnvido,
    %faltaEnvido,
    %truco,
    %retruco,
    %valeCuatro

jugar_rondas -->
    estado(S0, _), % no me importa el estado de salida, solo me interesa el estado de entrada S0 para obtener los puntos de los jugadores
    {select(jugadores(Js), S0, _), % Seleccione los jugadores macheando sus puntos de S0
    % y evalua el puntaje de ambos jugadores, si los puntajes son menores a 30, se sigue jugando, sino se termina el juego
    Js = [jugador(_,_,PJ1), jugador(_,_,PJ2)], % Asegura que Js tenga la forma de una lista con dos jugadores, cada jugador con su nombre, cartas en mano y puntos
    (PJ1 #< 30, PJ2 #< 30)},
    jugar_ronda(Js), 
    jugar_rondas.

jugar_rondas --> % Caso donde se termina el juego, es decir, cuando alguno de los jugadores llega a 30 puntos o mas
    estado(S, S), % No cambia el estado, solo lo lee, osea cuando veamos estado(S,S) es porque no se va a modificar el estado, solo se va a leer
    {select(jugadores([jugador(N1,_,PJ1),jugador(N2,_,PJ2)]), S, _), % Seleccione los jugadores macheando sus puntos de S0
    % Condicional para determinar el ganador, el jugador con mas puntos es el ganador, y se muestra su nombre y puntaje
    (PJ1 #> PJ2 ->
        format("El ganador es ~w con ~w puntos~n", [N1, PJ1])  
    ;
        format("El ganador es ~w con ~w puntos~n", [N2, PJ2])
	)}.


jugar_ronda([]) --> []. % caso base, cuando no hay jugadores, se termina la ronda
jugar_ronda([P|Ps]) --> % P es el jugador actual, Ps es la lista de jugadores restantes
    estado(S, S), % no modifica nada solo lee el estado actual
    {	P = jugador(Nombre, CartasEnMano, _), % pattern matching para obtener el nombre y las cartas en mano del jugador actual
      	% Aca se establece un turno y aparecen las opciones disponibles para el jugador, se muestra su nombre y las cartas que tiene en mano
        format("es el turno de ~a!~n", [Nombre]),
		format("cartas restantes: ~w~n", [CartasEnMano]),
     	format("OPCIONES: ~w tirar carta,~w cantar truco,
              ~w cantar envido, ~w irse al mazo ~n", [1,2,3,4]),
    	read(C) % Se lee la opcion ingresada por el jugador, y se evalua con el DCG buscar_opciones
        % para determinar que accion se va a realizar dependiendo de la opcion ingresada
    },
    buscar_opciones(C, Nombre, _),
    jugar_ronda(Ps).

buscar_opciones(C, Nombre, P1) --> 
    {C #= 1}, tirar_carta(Nombre, P1).

buscar_opciones(C, Nombre, P1) --> 
    {C #= 2}, tirar_carta(Nombre, P1).

buscar_opciones(C, Nombre, P1) --> 
    {C #= 3}, tirar_carta(Nombre, P1).

buscar_opciones(C, _, _) --> % N y P1
    {C #= 4}.

quitar_carta(P0, C, P) :-
    P0 = jugador(N, C0, W),
    select(C, C0, C1),
    P = jugador(N, C1, W).

tirar_carta(N1, P1) -->
    estado(S,S),
    	{select(P, jugadores, S, _),
        P = jugador(N1, CartasEnMano, _),
		format("cartas restantes: ~w~n", [CartasEnMano]),
    	read(C1),
      	member(C1, CartasEnMano),
        format("el jugador ~a tira la carta: ~w~n", [N1, CartasEnMano]),
        quitar_carta(N1, C1, P1)}.

tirar_carta(Ps, Cs, PJs) --> tirar_carta(Ps, Cs, PJs).
    
crearJugadores(Nombres) -->
    estado(S0, S),
    {
        maplist(crearJugador, Nombres, Jugadores), % “aplicá crearJugador a cada elemento de Nombres 
        % y generá Jugadores donde es una lista de jugador(Nombre, [], [_]).
      	stock(Cartas), % Llama al stock de cartas, obteniendo todas las cartas
        S = [jugadores(Jugadores), stock(Cartas)|S0] % Almacena todos los jugadores con el stock
    },
    mezclar, % Aca llama a mezclar las cartas
    repartir_una_carta, % Aca reparte solo una vez las cartas, por eso se llama 3 veces
    repartir_una_carta,
    repartir_una_carta.

repartir_una_carta --> % Se llamara 3 veces
    estado(S0, S),
    {
        select(jugadores(Jugadores), S0, S1), % Saca los jugadores de S0 y tiene una lista S1 sin esos jugadores
		select(stock(Cartas), S1, S2), % Saca el stock de cartas mezclada(Ahora solo cartas por la unificacion)
        % de S1 (Lista actualizada) y queda S2 sin los jugadores y las cartas
        repartir_una_carta(Jugadores, Jugadores1, Cartas, Cartas1), % Reparte una vez la carta
        S = [jugadores(Jugadores1), stock(Cartas1)|S2] % Actualiza el estado de los jugadores y el stock de cartas que disminuyo
    }.

repartir_una_carta([], [], Cs, Cs).
repartir_una_carta(Ps, Ps, [], []). %  ????
repartir_una_carta([P|Ps], [P1|Ps1], [C|Cs], Cs1) :- % (jugadorAntes, JugadorDespues, CartasAntes, CartasDespues)
    P = jugador(N, A, B), % Afirma que P tiene forma de jugador, no es un igual sino una unificacion
    P1 = jugador(N, [C|A], B), % Crea un nuemo jugador con P1 asignandole el mismo nombre, solo le agrega la carta
    repartir_una_carta(Ps, Ps1, Cs, Cs1). % Luego llama para hacer lo mismo con el otro jugador
  
% Esta parte no la comente pero se entiende que es la parte de calcular el puntaje del envido,
% se obtiene las cartas de cada jugador y se calculan las combinaciones posibles 
% para obtener el puntaje maximo de envido
sumarPuntos(Z) -->
    [[Numero1,Palo1], [Numero2,Palo2], [Numero3,Palo3]],
    {combinaciones([[Numero1,Palo1], [Numero2,Palo2], [Numero3,Palo3]], X),maximo(X, Z)}.

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

