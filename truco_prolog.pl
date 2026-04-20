:- use_module(library(clpfd)).
:- use_module(library(random)).

palos([oro, espada, basto, copa]).

numeros([rey, caballo, sota, 7, 6, 5, 4, 3, 2, 1]).

crearJugador(Nombre, jugador(Nombre, [], [_])).

jugador(_, [_], [_]).

puntos_truco([_], [_]).

puntos_envido([_], [_]).

%jugadores([jugador(_, [_], [_]), jugador(_, [_], [_])]).

jugadores([jugador(j1,[[2, espada], [4, oro], [3, espada]],[_]), jugador(j2,[[caballo, copa], [3, copa], [1, copa]],[_])]).

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

estado(S0, S, S0, S).

carta([Numero,Palo]):-
    palos(ListaPalos),
    numeros(ListaNumeros),
    member(Numero, ListaNumeros),
    member(Palo, ListaPalos).

mezclar -->
    estado(S0, S),
    {
	select(stock(Cartas), S0, S1),
	random_permutation(Cartas, CartasMezcladas),
	S = [stock(CartasMezcladas)|S1]
    }.

truco -->
    crearJugadores([j1,j2]).
    %jugar_rondas.
    %envido,
    %envido,
    %realEnvido,
    %faltaEnvido,
    %truco,
    %retruco,
    %valeCuatro

jugar_rondas -->
    estado(S0, _),
    {select(jugadores([
            jugador(_,_,[PJ1]),
            jugador(_,_,[PJ2])
        ]), S0, _),
    (PJ1 #< 30, PJ2 #< 30)},
    jugar_ronda,
    jugar_rondas.

jugar_rondas -->
    estado(S, S),
    {select(jugadores([
            jugador(N1,_,[PJ1]),
            jugador(N2,_,[PJ2])
        ]), S, _),
    (PJ1 #> PJ2 ->
        format("El ganador es ~w con ~w puntos~n", [N1, PJ1])
    ;
        format("El ganador es ~w con ~w puntos~n", [N2, PJ2])
	)}.


jugar_ronda([]) --> [].
jugar_ronda([P|Ps]) -->
    estado(S, S),
    {	P = jugador(Nombre, CartasEnMano, _),
      	format("es el turno de ~a!~n", [Nombre]),
		format("cartas restantes: ~w~n", [CartasEnMano]),
     	format("OPCIONES: ~w tirar carta,~w cantar truco,
              ~w cantar envido, ~w irse al mazo ~n", [1,2,3,4]),
    	read(C)},
    buscar_opciones(C, Nombre, _),
    jugar_ronda(Ps).

buscar_opciones(C, N, P1) --> 
    {C #= 1}, tirar_carta(N, P1).

buscar_opciones(C, N, P1) --> 
    {C #= 2}, tirar_carta(N, P1).

buscar_opciones(C, N, P1) --> 
    {C #= 3}, tirar_carta(N, P1).

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
        maplist(crearJugador, Nombres, Jugadores),
      	stock(Cartas),
        S = [jugadores(Jugadores), stock(Cartas)|S0]
    },
    mezclar,
    repartir_una_carta,
    repartir_una_carta,
    repartir_una_carta.

repartir_una_carta -->
    estado(S0, S),
    {
        select(jugadores(Jugadores), S0, S1),
		select(stock(Cartas), S1, S2),
        repartir_una_carta(Jugadores, Jugadores1, Cartas, Cartas1),
        S = [jugadores(Jugadores1), stock(Cartas1)|S2]
    }.

repartir_una_carta([], [], Cs, Cs).
repartir_una_carta(Ps, Ps, [], []).
repartir_una_carta([P|Ps], [P1|Ps1], [C|Cs], Cs1) :-
    P = jugador(N, A, B),
    P1 = jugador(N, [C|A], B),
    repartir_una_carta(Ps, Ps1, Cs, Cs1).
  

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

