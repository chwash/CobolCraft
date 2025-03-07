IDENTIFICATION DIVISION.
PROGRAM-ID. SendPacket-FinishConfiguration.

DATA DIVISION.
WORKING-STORAGE SECTION.
    COPY DD-PACKET REPLACING IDENTIFIER BY "configuration/clientbound/minecraft:finish_configuration".
    *> buffer used to store the packet data
    01 PAYLOAD          PIC X(1).
    01 PAYLOADLEN       BINARY-LONG UNSIGNED    VALUE 0.
LINKAGE SECTION.
    01 LK-CLIENT        BINARY-LONG UNSIGNED.

PROCEDURE DIVISION USING LK-CLIENT.
    COPY PROC-PACKET-INIT.
    CALL "SendPacket" USING LK-CLIENT PACKET-ID PAYLOAD PAYLOADLEN
    GOBACK.

END PROGRAM SendPacket-FinishConfiguration.
