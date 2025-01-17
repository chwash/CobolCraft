IDENTIFICATION DIVISION.
PROGRAM-ID. RecvPacket-PlayerCommand.

DATA DIVISION.
WORKING-STORAGE SECTION.
    COPY DD-CLIENTS.
    COPY DD-PLAYERS.
    01 PLAYER-ID                BINARY-LONG.
    *> payload
    01 ENTITY-ID                BINARY-LONG.
    01 ACTION-ID                BINARY-LONG.
LINKAGE SECTION.
    01 LK-CLIENT                BINARY-LONG UNSIGNED.
    01 LK-BUFFER                PIC X ANY LENGTH.
    01 LK-OFFSET                BINARY-LONG UNSIGNED.

PROCEDURE DIVISION USING LK-CLIENT LK-BUFFER LK-OFFSET.
    MOVE CLIENT-PLAYER(LK-CLIENT) TO PLAYER-ID

    CALL "Decode-VarInt" USING LK-BUFFER LK-OFFSET ENTITY-ID
    CALL "Decode-VarInt" USING LK-BUFFER LK-OFFSET ACTION-ID

    EVALUATE ACTION-ID
        *> start sneaking
        WHEN 0
            MOVE 1 TO PLAYER-SNEAKING(PLAYER-ID)
        *> stop sneaking
        WHEN 1
            MOVE 0 TO PLAYER-SNEAKING(PLAYER-ID)
    END-EVALUATE

    GOBACK.

END PROGRAM RecvPacket-PlayerCommand.
