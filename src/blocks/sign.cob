*> --- RegisterBlock-Sign ---
IDENTIFICATION DIVISION.
PROGRAM-ID. RegisterBlock-Sign.

DATA DIVISION.
WORKING-STORAGE SECTION.
    01 INTERACT-PTR             PROGRAM-POINTER.
    COPY DD-TAGS.
    01 IDX-REGISTRY             BINARY-LONG UNSIGNED.
    01 IDX-TAG                  BINARY-LONG UNSIGNED.
    01 IDX-BLOCK                BINARY-LONG UNSIGNED.
    01 BLOCK-NAME               PIC X(64).
    01 BLOCK-MIN-STATE-ID       BINARY-LONG.
    01 BLOCK-MAX-STATE-ID       BINARY-LONG.
    01 BLOCK-STATE-ID           BINARY-LONG.

PROCEDURE DIVISION.
    SET INTERACT-PTR TO ENTRY "Callback-Interact"

    *> TODO hanging signs

    *> Iterate over "minecraft:signs" tag to find sign blocks
    *> TODO Make this simpler and reusable

    PERFORM VARYING IDX-REGISTRY FROM 1 BY 1 UNTIL IDX-REGISTRY > TAGS-REGISTRY-COUNT
        IF TAGS-REGISTRY-NAME(IDX-REGISTRY) = "minecraft:block"
            EXIT PERFORM
        END-IF
    END-PERFORM

    PERFORM VARYING IDX-TAG FROM 1 BY 1 UNTIL IDX-TAG > TAGS-REGISTRY-LENGTH(IDX-REGISTRY)
        IF TAGS-REGISTRY-TAG-NAME(IDX-REGISTRY, IDX-TAG) = "minecraft:signs"
            EXIT PERFORM
        END-IF
    END-PERFORM

    PERFORM VARYING IDX-BLOCK FROM 1 BY 1 UNTIL IDX-BLOCK > TAGS-REGISTRY-TAG-LENGTH(IDX-REGISTRY, IDX-TAG)
        *> TODO Avoid so many lookups
        CALL "Registries-Get-EntryName" USING "minecraft:block" TAGS-REGISTRY-TAG-ENTRY(IDX-REGISTRY, IDX-TAG, IDX-BLOCK) BLOCK-NAME
        CALL "Blocks-Get-StateIds" USING BLOCK-NAME BLOCK-MIN-STATE-ID BLOCK-MAX-STATE-ID
        PERFORM VARYING BLOCK-STATE-ID FROM BLOCK-MIN-STATE-ID BY 1 UNTIL BLOCK-STATE-ID > BLOCK-MAX-STATE-ID
            CALL "SetCallback-BlockInteract" USING BLOCK-STATE-ID INTERACT-PTR
        END-PERFORM
    END-PERFORM

    GOBACK.

    *> --- Callback-Interact ---
    IDENTIFICATION DIVISION.
    PROGRAM-ID. Callback-Interact.

    DATA DIVISION.
    WORKING-STORAGE SECTION.
        COPY DD-PLAYERS.
        01 IS-FRONT-TEXT            BINARY-CHAR UNSIGNED.
    LINKAGE SECTION.
        COPY DD-CALLBACK-BLOCK-INTERACT.

    PROCEDURE DIVISION USING LK-PLAYER LK-ITEM-NAME LK-POSITION LK-FACE LK-CURSOR.
        *> TODO handle waxed sign
        *> TODO handle back of sign

        MOVE LK-POSITION TO PLAYER-UPDATE-SIGN-POSITION(LK-PLAYER)

        MOVE 1 TO IS-FRONT-TEXT
        CALL "SendPacket-OpenSignEditor" USING PLAYER-CLIENT(LK-PLAYER) LK-POSITION IS-FRONT-TEXT

        GOBACK.

    END PROGRAM Callback-Interact.

END PROGRAM RegisterBlock-Sign.
