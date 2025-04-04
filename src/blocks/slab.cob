*> --- RegisterBlock-Slab ---
IDENTIFICATION DIVISION.
PROGRAM-ID. RegisterBlock-Slab.

DATA DIVISION.
WORKING-STORAGE SECTION.
    01 BLOCK-REGISTRY           BINARY-LONG.
    01 FACE-PTR                 PROGRAM-POINTER.
    01 BLOCK-COUNT              BINARY-LONG UNSIGNED.
    01 BLOCK-ID                 BINARY-LONG UNSIGNED.
    01 BLOCK-TYPE               PIC X(64).
    01 BLOCK-MINIMUM-STATE-ID   BINARY-LONG.
    01 BLOCK-MAXIMUM-STATE-ID   BINARY-LONG.
    01 STATE-ID                 BINARY-LONG.

PROCEDURE DIVISION.
    CALL "Registries-LookupRegistry" USING "minecraft:block" BLOCK-REGISTRY

    SET FACE-PTR TO ENTRY "Callback-Face"

    *> Loop over all blocks and register the callback for each matching block type
    CALL "Registries-EntryCount" USING BLOCK-REGISTRY BLOCK-COUNT
    PERFORM VARYING BLOCK-ID FROM 0 BY 1 UNTIL BLOCK-ID >= BLOCK-COUNT
        CALL "Blocks-GetType" USING BLOCK-ID BLOCK-TYPE
        IF BLOCK-TYPE = "minecraft:slab"
            CALL "Blocks-GetStateIds" USING BLOCK-ID BLOCK-MINIMUM-STATE-ID BLOCK-MAXIMUM-STATE-ID
            PERFORM VARYING STATE-ID FROM BLOCK-MINIMUM-STATE-ID BY 1 UNTIL STATE-ID > BLOCK-MAXIMUM-STATE-ID
                CALL "SetCallback-BlockFace" USING STATE-ID FACE-PTR
            END-PERFORM
            *> TODO set metadata
        END-IF
    END-PERFORM

    GOBACK.

    *> --- Callback-Face ---
    IDENTIFICATION DIVISION.
    PROGRAM-ID. Callback-Face.

    DATA DIVISION.
    WORKING-STORAGE SECTION.
        COPY DD-BLOCK-STATE REPLACING LEADING ==PREFIX== BY ==BLOCK==.
        01 PROPERTY-VALUE           PIC X(16).
    LINKAGE SECTION.
        COPY DD-CALLBACK-BLOCK-FACE.

    PROCEDURE DIVISION USING LK-BLOCK-STATE LK-FACE LK-RESULT.
        CALL "Blocks-ToDescription" USING LK-BLOCK-STATE BLOCK-DESCRIPTION
        CALL "Blocks-Description-GetValue" USING BLOCK-DESCRIPTION "type" PROPERTY-VALUE

        EVALUATE TRUE
            *> Double slabs are solid everywhere
            WHEN PROPERTY-VALUE = "double"
                MOVE 1 TO LK-RESULT
            *> Bottom slabs are solid at the bottom; top slabs at the top
            WHEN PROPERTY-VALUE = "bottom" AND LK-FACE = "down"
                MOVE 1 TO LK-RESULT
            WHEN PROPERTY-VALUE = "top" AND LK-FACE = "up"
                MOVE 1 TO LK-RESULT
            *> Otherwise, slabs aren't solid
            WHEN OTHER
                MOVE 0 TO LK-RESULT
        END-EVALUATE

        GOBACK.

    END PROGRAM Callback-Face.

END PROGRAM RegisterBlock-Slab.
