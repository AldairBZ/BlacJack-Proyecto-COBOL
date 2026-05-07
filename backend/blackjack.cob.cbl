       IDENTIFICATION DIVISION.
       PROGRAM-ID. BLACKJACK.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT OPTIONAL BRIDGE-FILE ASSIGN TO "DATA/BRIDGE.DAT"
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT OPTIONAL SHOE-FILE ASSIGN TO "DATA/SHOE.DAT"
               ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD BRIDGE-FILE.
       01 BRIDGE-RECORD        PIC X(220).
       FD SHOE-FILE.
       01 SHOE-RECORD          PIC X(640).

       WORKING-STORAGE SECTION.
       01 WS-STATE.
          05 WS-COMMAND        PIC X(10).
          05 WS-PLAYER         PIC X(20).
          05 WS-STATUS         PIC X(12).
          05 WS-P-CARDS        PIC X(50).
          05 WS-P-SCORE        PIC 99.
          05 WS-D-CARDS        PIC X(50).
          05 WS-D-SCORE        PIC 99.
          05 WS-CHIPS          PIC 9(6).
          05 WS-BET            PIC 9(6).
          05 WS-WINS           PIC 9(4).
          05 WS-GAMES          PIC 9(4).
          05 WS-MESSAGE        PIC X(24).
          05 WS-SHOE-REMAIN    PIC 9(3).
          05 WS-SHOE-TOTAL     PIC 9(3).
          05 FILLER            PIC X(24).

       01 WS-RANDOM            PIC 99.
       01 WS-RAND-IDX          PIC 9(3).
       01 WS-SUIT-RANDOM       PIC 9.
       01 WS-SEED              PIC 9(8).
       01 WS-CARD-VAL          PIC 99.
       01 WS-CARD-STR          PIC X(2).
       01 WS-CARD-FULL         PIC X(3).
       01 WS-P-ACES            PIC 9 VALUE 0.
       01 WS-D-ACES            PIC 9 VALUE 0.
       01 WS-P-PTR             PIC 99 VALUE 1.
       01 WS-D-PTR             PIC 99 VALUE 1.
       01 WS-I                 PIC 99.
       01 WS-BET-INPUT         PIC 9(7) VALUE 0.
       01 WS-CMD-PREFIX        PIC X(3).
       01 WS-SHOE-STATE.
          05 WS-SHOE-INDEX     PIC 9(3).
          05 WS-SHOE-CARDS     PIC X(624).
          05 FILLER            PIC X(13).
       01 WS-SHOE-TABLE.
          05 WS-SHOE-CARD OCCURS 312 TIMES PIC X(2).
       01 WS-SHOE-IDX          PIC 9(3).
       01 WS-SHOE-SWAP-IDX     PIC 9(3).
       01 WS-SHOE-POS          PIC 9(4).
       01 WS-SHOE-TMP          PIC X(2).
       01 WS-DECK              PIC 9.
       01 WS-RANK              PIC 99.
       01 WS-SUIT              PIC 9.
       01 WS-ACE-COUNT         PIC 99.
       01 WS-SUM               PIC 99.
       01 WS-RANK-CH           PIC X.

       PROCEDURE DIVISION.
       MAIN-PROCEDURE.
           ACCEPT WS-SEED FROM TIME.
           COMPUTE WS-RANDOM = FUNCTION RANDOM (WS-SEED).

           PERFORM READ-BRIDGE.
           PERFORM ENSURE-BASE-STATE.
           PERFORM PROCESS-COMMAND.
           PERFORM CALC-SCORES
           MOVE SPACES TO WS-COMMAND
           PERFORM WRITE-BRIDGE.
           STOP RUN.

       READ-BRIDGE.
           OPEN INPUT BRIDGE-FILE
           READ BRIDGE-FILE INTO WS-STATE
               AT END
                   MOVE SPACES TO WS-STATE
           END-READ
           CLOSE BRIDGE-FILE.

       WRITE-BRIDGE.
           OPEN OUTPUT BRIDGE-FILE
           WRITE BRIDGE-RECORD FROM WS-STATE
           CLOSE BRIDGE-FILE.

       ENSURE-BASE-STATE.
           IF WS-PLAYER = SPACES
               MOVE "PLAYER1" TO WS-PLAYER
           END-IF
           IF WS-CHIPS = 0
               MOVE 001000 TO WS-CHIPS
           END-IF
           IF WS-STATUS = SPACES
               MOVE "BETTING" TO WS-STATUS
           END-IF
           IF WS-MESSAGE = SPACES
               MOVE "PON TU APUESTA" TO WS-MESSAGE
           END-IF.

       PROCESS-COMMAND.
           MOVE WS-COMMAND(1:3) TO WS-CMD-PREFIX
           IF WS-CMD-PREFIX = "BET"
               PERFORM HANDLE-BET
           ELSE
               EVALUATE WS-COMMAND
                   WHEN "START     "
                       PERFORM HANDLE-START
                   WHEN "HIT       "
                       PERFORM HANDLE-HIT
                   WHEN "STAND     "
                       PERFORM HANDLE-STAND
                   WHEN "RESET     "
                       PERFORM HANDLE-RESET
                   WHEN "RESETALL  "
                       PERFORM HANDLE-RESET-ALL
                   WHEN OTHER
                       CONTINUE
               END-EVALUATE
           END-IF.

       HANDLE-BET.
           IF WS-STATUS NOT = "BETTING"
               MOVE "APUESTA CERRADA" TO WS-MESSAGE
               EXIT PARAGRAPH
           END-IF
           MOVE WS-COMMAND(4:7) TO WS-BET-INPUT
           IF WS-BET-INPUT = 0
               EXIT PARAGRAPH
           END-IF
           IF WS-CHIPS < WS-BET-INPUT
               MOVE "SIN SALDO" TO WS-MESSAGE
           ELSE
               SUBTRACT WS-BET-INPUT FROM WS-CHIPS
               ADD WS-BET-INPUT TO WS-BET
               MOVE "APUESTA ACEPTADA" TO WS-MESSAGE
           END-IF.

       HANDLE-START.
           IF WS-BET = 0
               MOVE "APUESTA PRIMERO" TO WS-MESSAGE
               EXIT PARAGRAPH
           END-IF
           PERFORM ENSURE-SHOE-READY
           MOVE "PLAYING" TO WS-STATUS
           MOVE "JUEGA TU MANO" TO WS-MESSAGE
           MOVE SPACES TO WS-P-CARDS
           MOVE SPACES TO WS-D-CARDS
           MOVE 0 TO WS-P-SCORE WS-D-SCORE WS-P-ACES WS-D-ACES
           MOVE 1 TO WS-P-PTR WS-D-PTR
           PERFORM DEAL-PLAYER 2 TIMES
           PERFORM DEAL-DEALER 2 TIMES
           PERFORM CALC-SCORES
           IF WS-P-SCORE = 21
               IF WS-D-SCORE = 21
                   PERFORM RESOLVE-PUSH
                   MOVE "BLACKJACK PUSH" TO WS-MESSAGE
               ELSE
                   PERFORM RESOLVE-PLAYER-WIN
                   MOVE "BLACKJACK" TO WS-MESSAGE
               END-IF
           END-IF.

       HANDLE-HIT.
           IF WS-STATUS NOT = "PLAYING"
               EXIT PARAGRAPH
           END-IF
           PERFORM CALC-P-PTR
           PERFORM DEAL-PLAYER
           PERFORM CALC-SCORES
           IF WS-P-SCORE > 21
               PERFORM RESOLVE-DEALER-WIN
               MOVE "TE PASASTE" TO WS-MESSAGE
           END-IF.

       HANDLE-STAND.
           IF WS-STATUS NOT = "PLAYING"
               EXIT PARAGRAPH
           END-IF
           PERFORM CALC-D-PTR
           PERFORM CALC-SCORES
           PERFORM UNTIL WS-D-SCORE >= 17
               PERFORM DEAL-DEALER
               PERFORM CALC-SCORES
           END-PERFORM
           IF WS-D-SCORE > 21
               PERFORM RESOLVE-PLAYER-WIN
               MOVE "CRUPIER BUST" TO WS-MESSAGE
           ELSE
               IF WS-P-SCORE > WS-D-SCORE
                   PERFORM RESOLVE-PLAYER-WIN
               ELSE
                   IF WS-P-SCORE < WS-D-SCORE
                       PERFORM RESOLVE-DEALER-WIN
                   ELSE
                       PERFORM RESOLVE-PUSH
                   END-IF
               END-IF
           END-IF.

       HANDLE-RESET.
           MOVE "BETTING" TO WS-STATUS
           MOVE 0 TO WS-BET
           MOVE SPACES TO WS-P-CARDS WS-D-CARDS
           MOVE 0 TO WS-P-SCORE WS-D-SCORE WS-P-ACES WS-D-ACES
           MOVE "PON TU APUESTA" TO WS-MESSAGE.

       HANDLE-RESET-ALL.
           MOVE 001000 TO WS-CHIPS
           PERFORM INIT-SHOE
           PERFORM HANDLE-RESET.

       RESOLVE-PLAYER-WIN.
           MOVE "PLAYER_WIN" TO WS-STATUS
           ADD 1 TO WS-WINS
           ADD 1 TO WS-GAMES
           COMPUTE WS-CHIPS = WS-CHIPS + (WS-BET * 2)
           MOVE 0 TO WS-BET
           MOVE "GANASTE" TO WS-MESSAGE.

       RESOLVE-DEALER-WIN.
           MOVE "DEALER_WIN" TO WS-STATUS
           ADD 1 TO WS-GAMES
           MOVE 0 TO WS-BET
           MOVE "PERDISTE" TO WS-MESSAGE.

       RESOLVE-PUSH.
           MOVE "PUSH" TO WS-STATUS
           ADD 1 TO WS-GAMES
           ADD WS-BET TO WS-CHIPS
           MOVE 0 TO WS-BET
           MOVE "EMPATE" TO WS-MESSAGE.

       DEAL-PLAYER.
           PERFORM GENERATE-CARD
           STRING WS-CARD-FULL DELIMITED BY SIZE
                  INTO WS-P-CARDS WITH POINTER WS-P-PTR.

       DEAL-DEALER.
           PERFORM GENERATE-CARD
           STRING WS-CARD-FULL DELIMITED BY SIZE
                  INTO WS-D-CARDS WITH POINTER WS-D-PTR.

       GENERATE-CARD.
           PERFORM LOAD-SHOE
           IF WS-SHOE-INDEX < 1 OR WS-SHOE-INDEX > 312
               PERFORM INIT-SHOE
               PERFORM LOAD-SHOE
           END-IF
           COMPUTE WS-SHOE-POS = ((WS-SHOE-INDEX - 1) * 2) + 1
           MOVE WS-SHOE-CARDS(WS-SHOE-POS:2) TO WS-CARD-STR
           ADD 1 TO WS-SHOE-INDEX
           PERFORM SAVE-SHOE
           PERFORM MAP-CARD-VALUE
           STRING WS-CARD-STR "," DELIMITED BY SIZE INTO WS-CARD-FULL.

       ENSURE-SHOE-READY.
           PERFORM LOAD-SHOE
           IF WS-SHOE-INDEX < 1 OR WS-SHOE-INDEX > 300
               PERFORM INIT-SHOE
           END-IF.

       LOAD-SHOE.
           OPEN INPUT SHOE-FILE
           READ SHOE-FILE INTO WS-SHOE-STATE
               AT END
                   MOVE 0 TO WS-SHOE-INDEX
           END-READ
           CLOSE SHOE-FILE.

       SAVE-SHOE.
           OPEN OUTPUT SHOE-FILE
           WRITE SHOE-RECORD FROM WS-SHOE-STATE
           CLOSE SHOE-FILE.

       INIT-SHOE.
           MOVE 1 TO WS-SHOE-IDX
           PERFORM VARYING WS-DECK FROM 1 BY 1 UNTIL WS-DECK > 6
               PERFORM VARYING WS-RANK FROM 1 BY 1 UNTIL WS-RANK > 13
                   PERFORM VARYING WS-SUIT FROM 1 BY 1 UNTIL WS-SUIT > 4
                       PERFORM BUILD-CARD-CODE
                       MOVE WS-CARD-STR TO WS-SHOE-CARD(WS-SHOE-IDX)
                       ADD 1 TO WS-SHOE-IDX
                   END-PERFORM
               END-PERFORM
           END-PERFORM
           PERFORM SHUFFLE-SHOE
           MOVE 1 TO WS-SHOE-INDEX
           PERFORM SERIALIZE-SHOE
           PERFORM SAVE-SHOE.

       BUILD-CARD-CODE.
           EVALUATE WS-RANK
               WHEN 1 MOVE "A" TO WS-CARD-STR(1:1)
               WHEN 2 MOVE "2" TO WS-CARD-STR(1:1)
               WHEN 3 MOVE "3" TO WS-CARD-STR(1:1)
               WHEN 4 MOVE "4" TO WS-CARD-STR(1:1)
               WHEN 5 MOVE "5" TO WS-CARD-STR(1:1)
               WHEN 6 MOVE "6" TO WS-CARD-STR(1:1)
               WHEN 7 MOVE "7" TO WS-CARD-STR(1:1)
               WHEN 8 MOVE "8" TO WS-CARD-STR(1:1)
               WHEN 9 MOVE "9" TO WS-CARD-STR(1:1)
               WHEN 10 MOVE "0" TO WS-CARD-STR(1:1)
               WHEN 11 MOVE "J" TO WS-CARD-STR(1:1)
               WHEN 12 MOVE "Q" TO WS-CARD-STR(1:1)
               WHEN 13 MOVE "K" TO WS-CARD-STR(1:1)
               WHEN OTHER MOVE "2" TO WS-CARD-STR(1:1)
           END-EVALUATE
           EVALUATE WS-SUIT
               WHEN 1 MOVE "C" TO WS-CARD-STR(2:1)
               WHEN 2 MOVE "D" TO WS-CARD-STR(2:1)
               WHEN 3 MOVE "H" TO WS-CARD-STR(2:1)
               WHEN 4 MOVE "S" TO WS-CARD-STR(2:1)
           END-EVALUATE.

       SHUFFLE-SHOE.
           PERFORM VARYING WS-SHOE-IDX FROM 312 BY -1 UNTIL WS-SHOE-IDX <= 1
               COMPUTE WS-RAND-IDX = (FUNCTION RANDOM * WS-SHOE-IDX) + 1
               MOVE WS-SHOE-CARD(WS-SHOE-IDX) TO WS-SHOE-TMP
               MOVE WS-SHOE-CARD(WS-RAND-IDX) TO WS-SHOE-CARD(WS-SHOE-IDX)
               MOVE WS-SHOE-TMP TO WS-SHOE-CARD(WS-RAND-IDX)
           END-PERFORM.

       SERIALIZE-SHOE.
           MOVE SPACES TO WS-SHOE-CARDS
           PERFORM VARYING WS-SHOE-IDX FROM 1 BY 1 UNTIL WS-SHOE-IDX > 312
               COMPUTE WS-SHOE-POS = ((WS-SHOE-IDX - 1) * 2) + 1
               MOVE WS-SHOE-CARD(WS-SHOE-IDX) TO WS-SHOE-CARDS(WS-SHOE-POS:2)
           END-PERFORM.

       MAP-CARD-VALUE.
           EVALUATE WS-CARD-STR(1:1)
               WHEN "A" MOVE 11 TO WS-CARD-VAL
               WHEN "0" MOVE 10 TO WS-CARD-VAL
               WHEN "J" MOVE 10 TO WS-CARD-VAL
               WHEN "Q" MOVE 10 TO WS-CARD-VAL
               WHEN "K" MOVE 10 TO WS-CARD-VAL
               WHEN "2" MOVE 2 TO WS-CARD-VAL
               WHEN "3" MOVE 3 TO WS-CARD-VAL
               WHEN "4" MOVE 4 TO WS-CARD-VAL
               WHEN "5" MOVE 5 TO WS-CARD-VAL
               WHEN "6" MOVE 6 TO WS-CARD-VAL
               WHEN "7" MOVE 7 TO WS-CARD-VAL
               WHEN "8" MOVE 8 TO WS-CARD-VAL
               WHEN "9" MOVE 9 TO WS-CARD-VAL
               WHEN OTHER MOVE 10 TO WS-CARD-VAL
           END-EVALUATE.

       ADJUST-PLAYER-ACES.
           CONTINUE.

       ADJUST-DEALER-ACES.
           CONTINUE.

       CALC-P-PTR.
           MOVE 1 TO WS-P-PTR
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 50
               IF WS-P-CARDS(WS-I:1) = SPACE
                   MOVE WS-I TO WS-P-PTR
                   EXIT PERFORM
               END-IF
           END-PERFORM.

       CALC-D-PTR.
           MOVE 1 TO WS-D-PTR
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > 50
               IF WS-D-CARDS(WS-I:1) = SPACE
                   MOVE WS-I TO WS-D-PTR
                   EXIT PERFORM
               END-IF
           END-PERFORM.

       CALC-SCORES.
           PERFORM CALC-PLAYER-SCORE
           PERFORM CALC-DEALER-SCORE
           COMPUTE WS-SHOE-REMAIN = 312 - (WS-SHOE-INDEX - 1)
           MOVE 312 TO WS-SHOE-TOTAL.

       CALC-PLAYER-SCORE.
           MOVE 0 TO WS-SUM WS-ACE-COUNT
           PERFORM VARYING WS-I FROM 1 BY 3 UNTIL WS-I > 50
               IF WS-P-CARDS(WS-I:1) = SPACE
                   EXIT PERFORM
               END-IF
               MOVE WS-P-CARDS(WS-I:1) TO WS-RANK-CH
               IF WS-RANK-CH = "A"
                   ADD 1 TO WS-ACE-COUNT
                   ADD 1 TO WS-SUM
               ELSE
                   IF WS-RANK-CH = "0" OR WS-RANK-CH = "J"
                       ADD 10 TO WS-SUM
                   ELSE
                       IF WS-RANK-CH = "Q" OR WS-RANK-CH = "K"
                           ADD 10 TO WS-SUM
                       ELSE
                           EVALUATE WS-RANK-CH
                               WHEN "2" ADD 2 TO WS-SUM
                               WHEN "3" ADD 3 TO WS-SUM
                               WHEN "4" ADD 4 TO WS-SUM
                               WHEN "5" ADD 5 TO WS-SUM
                               WHEN "6" ADD 6 TO WS-SUM
                               WHEN "7" ADD 7 TO WS-SUM
                               WHEN "8" ADD 8 TO WS-SUM
                               WHEN "9" ADD 9 TO WS-SUM
                               WHEN OTHER CONTINUE
                           END-EVALUATE
                       END-IF
                   END-IF
               END-IF
           END-PERFORM
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-ACE-COUNT
               IF WS-SUM + 10 <= 21
                   ADD 10 TO WS-SUM
               END-IF
           END-PERFORM
           MOVE WS-SUM TO WS-P-SCORE.

       CALC-DEALER-SCORE.
           MOVE 0 TO WS-SUM WS-ACE-COUNT
           PERFORM VARYING WS-I FROM 1 BY 3 UNTIL WS-I > 50
               IF WS-D-CARDS(WS-I:1) = SPACE
                   EXIT PERFORM
               END-IF
               MOVE WS-D-CARDS(WS-I:1) TO WS-RANK-CH
               IF WS-RANK-CH = "A"
                   ADD 1 TO WS-ACE-COUNT
                   ADD 1 TO WS-SUM
               ELSE
                   IF WS-RANK-CH = "0" OR WS-RANK-CH = "J"
                       ADD 10 TO WS-SUM
                   ELSE
                       IF WS-RANK-CH = "Q" OR WS-RANK-CH = "K"
                           ADD 10 TO WS-SUM
                       ELSE
                           EVALUATE WS-RANK-CH
                               WHEN "2" ADD 2 TO WS-SUM
                               WHEN "3" ADD 3 TO WS-SUM
                               WHEN "4" ADD 4 TO WS-SUM
                               WHEN "5" ADD 5 TO WS-SUM
                               WHEN "6" ADD 6 TO WS-SUM
                               WHEN "7" ADD 7 TO WS-SUM
                               WHEN "8" ADD 8 TO WS-SUM
                               WHEN "9" ADD 9 TO WS-SUM
                               WHEN OTHER CONTINUE
                           END-EVALUATE
                       END-IF
                   END-IF
               END-IF
           END-PERFORM
           PERFORM VARYING WS-I FROM 1 BY 1 UNTIL WS-I > WS-ACE-COUNT
               IF WS-SUM + 10 <= 21
                   ADD 10 TO WS-SUM
               END-IF
           END-PERFORM
           MOVE WS-SUM TO WS-D-SCORE.
