IDENTIFICATION DIVISION.
PROGRAM-ID. RecvPacket-Swing.

DATA DIVISION.
WORKING-STORAGE SECTION.
    COPY DD-CLIENTS.
    COPY DD-PLAYERS.
    COPY DD-SERVER-PROPERTIES.
    COPY DD-CLIENT-STATES.
    01 PLAYER-ID                BINARY-LONG.
    *> payload
    01 HAND-ENUM                BINARY-LONG.
    *> variables
    01 CLIENT-ID                BINARY-LONG UNSIGNED.
    01 ANIMATION                BINARY-CHAR UNSIGNED.
LINKAGE SECTION.
    01 LK-CLIENT                BINARY-LONG UNSIGNED.
    01 LK-BUFFER                PIC X ANY LENGTH.
    01 LK-OFFSET                BINARY-LONG UNSIGNED.

PROCEDURE DIVISION USING LK-CLIENT LK-BUFFER LK-OFFSET.
    MOVE CLIENT-PLAYER(LK-CLIENT) TO PLAYER-ID

    CALL "Decode-VarInt" USING LK-BUFFER LK-OFFSET HAND-ENUM

    *> hand enum: 0=main hand, 1=offhand
    IF HAND-ENUM = 1
        MOVE 3 TO ANIMATION
    ELSE
        MOVE 0 TO ANIMATION
    END-IF

    *> send an animation packet to each of the other players
    PERFORM VARYING CLIENT-ID FROM 1 BY 1 UNTIL CLIENT-ID > MAX-CLIENTS
        IF CLIENT-STATE(CLIENT-ID) = CLIENT-STATE-PLAY AND CLIENT-ID NOT = LK-CLIENT
            CALL "SendPacket-EntityAnimation" USING CLIENT-ID PLAYER-ID ANIMATION
        END-IF
    END-PERFORM

    GOBACK.

END PROGRAM RecvPacket-Swing.
