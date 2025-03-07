IDENTIFICATION DIVISION.
PROGRAM-ID. RecvPacket-ContainerClose.

DATA DIVISION.
WORKING-STORAGE SECTION.
    COPY DD-CLIENTS.
    COPY DD-PLAYERS.
    01 PLAYER-ID                BINARY-LONG.
    01 WINDOW-ID                BINARY-LONG.
    01 CLOSE-PTR                PROGRAM-POINTER.
LINKAGE SECTION.
    01 LK-CLIENT                BINARY-LONG UNSIGNED.
    01 LK-BUFFER                PIC X ANY LENGTH.
    01 LK-OFFSET                BINARY-LONG UNSIGNED.

PROCEDURE DIVISION USING LK-CLIENT LK-BUFFER LK-OFFSET.
    MOVE CLIENT-PLAYER(LK-CLIENT) TO PLAYER-ID

    CALL "Decode-VarInt" USING LK-BUFFER LK-OFFSET WINDOW-ID

    IF PLAYER-WINDOW-ID(PLAYER-ID) NOT = WINDOW-ID
        *> different window than expected - ignore
        GOBACK
    END-IF

    CALL "GetCallback-WindowClose" USING PLAYER-WINDOW-TYPE(PLAYER-ID) CLOSE-PTR
    IF CLOSE-PTR NOT = NULL
        CALL CLOSE-PTR USING PLAYER-ID
    END-IF

    MOVE 0 TO PLAYER-WINDOW-ID(PLAYER-ID)
    MOVE -1 TO PLAYER-WINDOW-TYPE(PLAYER-ID)

    GOBACK.

END PROGRAM RecvPacket-ContainerClose.
