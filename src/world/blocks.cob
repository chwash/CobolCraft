*> --- World-CheckBounds ---
IDENTIFICATION DIVISION.
PROGRAM-ID. World-CheckBounds.

DATA DIVISION.
WORKING-STORAGE SECTION.
    COPY DD-WORLD.
LINKAGE SECTION.
    01 LK-POSITION.
        02 LK-X                 BINARY-LONG.
        02 LK-Y                 BINARY-LONG.
        02 LK-Z                 BINARY-LONG.
    01 LK-RESULT                BINARY-CHAR UNSIGNED.

PROCEDURE DIVISION USING LK-POSITION LK-RESULT.
    IF LK-Y < -64 OR LK-Y > 319 THEN
        MOVE 1 TO LK-RESULT
    ELSE
        MOVE 0 TO LK-RESULT
    END-IF
    GOBACK.

END PROGRAM World-CheckBounds.

*> --- World-GetBlock ---
IDENTIFICATION DIVISION.
PROGRAM-ID. World-GetBlock.

DATA DIVISION.
WORKING-STORAGE SECTION.
    COPY DD-WORLD.
    COPY DD-CHUNK-REF.
    01 POS-CHUNK-X              BINARY-LONG.
    01 POS-CHUNK-Z              BINARY-LONG.
    01 CHUNK-INDEX              BINARY-LONG UNSIGNED.
    01 SECTION-INDEX            BINARY-LONG UNSIGNED.
    01 BLOCK-INDEX              BINARY-LONG UNSIGNED.
LINKAGE SECTION.
    01 LK-POSITION.
        02 LK-X                 BINARY-LONG.
        02 LK-Y                 BINARY-LONG.
        02 LK-Z                 BINARY-LONG.
    01 LK-BLOCK-ID              BINARY-LONG UNSIGNED.

PROCEDURE DIVISION USING LK-POSITION LK-BLOCK-ID.
    *> find the chunk
    DIVIDE LK-X BY 16 GIVING POS-CHUNK-X ROUNDED MODE IS TOWARD-LESSER
    DIVIDE LK-Z BY 16 GIVING POS-CHUNK-Z ROUNDED MODE IS TOWARD-LESSER
    CALL "World-FindChunkIndex" USING POS-CHUNK-X POS-CHUNK-Z CHUNK-INDEX
    IF CHUNK-INDEX = 0
        MOVE 0 TO LK-BLOCK-ID
        GOBACK
    END-IF
    SET ADDRESS OF CHUNK TO WORLD-CHUNK-POINTER(CHUNK-INDEX)
    *> compute the block index
    COMPUTE SECTION-INDEX = (LK-Y + 64) / 16 + 1
    COMPUTE BLOCK-INDEX = ((FUNCTION MOD(LK-Y + 64, 16)) * 16 + (FUNCTION MOD(LK-Z, 16))) * 16 + (FUNCTION MOD(LK-X, 16)) + 1
    MOVE CHUNK-SECTION-BLOCK(SECTION-INDEX, BLOCK-INDEX) TO LK-BLOCK-ID
    GOBACK.

END PROGRAM World-GetBlock.

*> --- World-SetBlock ---
IDENTIFICATION DIVISION.
PROGRAM-ID. World-SetBlock.

DATA DIVISION.
WORKING-STORAGE SECTION.
    01 WORLD-EVENT-BLOCK-BREAK  BINARY-LONG UNSIGNED        VALUE 2001.
    COPY DD-WORLD.
    COPY DD-CHUNK-REF.
    COPY DD-CLIENT-STATES.
    COPY DD-CLIENTS.
    COPY DD-SERVER-PROPERTIES.
    01 POS-CHUNK-X              BINARY-LONG.
    01 POS-CHUNK-Z              BINARY-LONG.
    01 CHUNK-INDEX              BINARY-LONG UNSIGNED.
    01 SECTION-INDEX            BINARY-LONG UNSIGNED.
    01 BLOCK-IN-CHUNK-INDEX     BINARY-LONG UNSIGNED.
    01 BLOCK-INDEX              BINARY-LONG UNSIGNED.
    01 PREVIOUS-BLOCK-ID        BINARY-LONG UNSIGNED.
    01 IS-SAME-BLOCK-TYPE       BINARY-CHAR UNSIGNED.
    01 CLIENT-ID                BINARY-LONG UNSIGNED.
LINKAGE SECTION.
    *> The client that performed the action, to avoid playing sounds/particles for them (optional)
    01 LK-CLIENT                BINARY-LONG UNSIGNED.
    01 LK-POSITION.
        02 LK-X                 BINARY-LONG.
        02 LK-Y                 BINARY-LONG.
        02 LK-Z                 BINARY-LONG.
    01 LK-BLOCK-ID              BINARY-LONG UNSIGNED.

PROCEDURE DIVISION USING OPTIONAL LK-CLIENT LK-POSITION LK-BLOCK-ID.
    *> Find the chunk, section, and block indices
    DIVIDE LK-X BY 16 GIVING POS-CHUNK-X ROUNDED MODE IS TOWARD-LESSER
    DIVIDE LK-Z BY 16 GIVING POS-CHUNK-Z ROUNDED MODE IS TOWARD-LESSER
    CALL "World-FindChunkIndex" USING POS-CHUNK-X POS-CHUNK-Z CHUNK-INDEX
    IF CHUNK-INDEX = 0
        GOBACK
    END-IF
    SET ADDRESS OF CHUNK TO WORLD-CHUNK-POINTER(CHUNK-INDEX)

    COMPUTE SECTION-INDEX = (LK-Y + 64) / 16 + 1
    COMPUTE BLOCK-INDEX = ((FUNCTION MOD(LK-Y + 64, 16)) * 16 + (FUNCTION MOD(LK-Z, 16))) * 16 + (FUNCTION MOD(LK-X, 16)) + 1

    *> Skip if identical to the current block
    MOVE CHUNK-SECTION-BLOCK(SECTION-INDEX, BLOCK-INDEX) TO PREVIOUS-BLOCK-ID
    IF PREVIOUS-BLOCK-ID = LK-BLOCK-ID
        GOBACK
    END-IF

    *> Check whether the block is becoming air or non-air
    EVALUATE TRUE
        WHEN LK-BLOCK-ID = 0
            SUBTRACT 1 FROM CHUNK-SECTION-NON-AIR(SECTION-INDEX)
        WHEN PREVIOUS-BLOCK-ID = 0
            ADD 1 TO CHUNK-SECTION-NON-AIR(SECTION-INDEX)
    END-EVALUATE

    *> Set the block and mark the chunk as dirty
    MOVE LK-BLOCK-ID TO CHUNK-SECTION-BLOCK(SECTION-INDEX, BLOCK-INDEX)
    MOVE 1 TO CHUNK-DIRTY-BLOCKS

    *> If the block is changing to a different type (not just state), deallocate and remove any block entity
    IF PREVIOUS-BLOCK-ID NOT = 0
        CALL "Blocks-CompareBlockType" USING PREVIOUS-BLOCK-ID LK-BLOCK-ID IS-SAME-BLOCK-TYPE
        IF IS-SAME-BLOCK-TYPE = 0
            COMPUTE BLOCK-IN-CHUNK-INDEX = ((LK-Y + 64) * 16 + (FUNCTION MOD(LK-Z, 16))) * 16 + (FUNCTION MOD(LK-X, 16)) + 1
            IF CHUNK-BLOCK-ENTITY-ID(BLOCK-IN-CHUNK-INDEX) >= 0
                MOVE -1 TO CHUNK-BLOCK-ENTITY-ID(BLOCK-IN-CHUNK-INDEX)
                FREE CHUNK-BLOCK-ENTITY-DATA(BLOCK-IN-CHUNK-INDEX)
                SUBTRACT 1 FROM CHUNK-BLOCK-ENTITY-COUNT
            END-IF
        END-IF
    END-IF

    *> Notify clients
    PERFORM VARYING CLIENT-ID FROM 1 BY 1 UNTIL CLIENT-ID > MAX-CLIENTS
        IF CLIENT-STATE(CLIENT-ID) = CLIENT-STATE-PLAY
            CALL "SendPacket-BlockUpdate" USING CLIENT-ID LK-POSITION LK-BLOCK-ID
            *> play block break sound and particles
            IF (LK-CLIENT IS OMITTED OR CLIENT-ID NOT = LK-CLIENT) AND LK-BLOCK-ID = 0
                CALL "SendPacket-WorldEvent" USING CLIENT-ID WORLD-EVENT-BLOCK-BREAK LK-POSITION PREVIOUS-BLOCK-ID
            END-IF
        END-IF
    END-PERFORM

    GOBACK.

END PROGRAM World-SetBlock.

*> --- World-GetBlockEntity ---
IDENTIFICATION DIVISION.
PROGRAM-ID. World-GetBlockEntity.

DATA DIVISION.
WORKING-STORAGE SECTION.
    COPY DD-WORLD.
    COPY DD-CHUNK-REF.
    01 POS-CHUNK-X              BINARY-LONG.
    01 POS-CHUNK-Z              BINARY-LONG.
    01 CHUNK-INDEX              BINARY-LONG UNSIGNED.
    01 BLOCK-IN-CHUNK-INDEX     BINARY-LONG UNSIGNED.
LINKAGE SECTION.
    01 LK-POSITION.
        02 LK-X                 BINARY-LONG.
        02 LK-Y                 BINARY-LONG.
        02 LK-Z                 BINARY-LONG.
    01 LK-BLOCK-ENTITY.
        COPY DD-BLOCK-ENTITY REPLACING LEADING ==BLOCK-ENTITY== BY ==LK-BLOCK-ENTITY==.

PROCEDURE DIVISION USING LK-POSITION LK-BLOCK-ENTITY.
    MOVE -1 TO LK-BLOCK-ENTITY-ID
    SET LK-BLOCK-ENTITY-DATA TO NULL

    *> Find the chunk and block indices
    DIVIDE LK-X BY 16 GIVING POS-CHUNK-X ROUNDED MODE IS TOWARD-LESSER
    DIVIDE LK-Z BY 16 GIVING POS-CHUNK-Z ROUNDED MODE IS TOWARD-LESSER
    CALL "World-FindChunkIndex" USING POS-CHUNK-X POS-CHUNK-Z CHUNK-INDEX
    IF CHUNK-INDEX = 0
        GOBACK
    END-IF
    SET ADDRESS OF CHUNK TO WORLD-CHUNK-POINTER(CHUNK-INDEX)

    COMPUTE BLOCK-IN-CHUNK-INDEX = ((LK-Y + 64) * 16 + (FUNCTION MOD(LK-Z, 16))) * 16 + (FUNCTION MOD(LK-X, 16)) + 1

    IF CHUNK-BLOCK-ENTITY-ID(BLOCK-IN-CHUNK-INDEX) >= 0
        MOVE CHUNK-BLOCK-ENTITY-ID(BLOCK-IN-CHUNK-INDEX) TO LK-BLOCK-ENTITY-ID
        SET LK-BLOCK-ENTITY-DATA TO CHUNK-BLOCK-ENTITY-DATA(BLOCK-IN-CHUNK-INDEX)
    END-IF

    GOBACK.

END PROGRAM World-GetBlockEntity.

*> --- World-SetBlockEntity ---
IDENTIFICATION DIVISION.
PROGRAM-ID. World-SetBlockEntity.

DATA DIVISION.
WORKING-STORAGE SECTION.
    COPY DD-CALLBACKS.
    COPY DD-WORLD.
    COPY DD-CHUNK-REF.
    COPY DD-CLIENT-STATES.
    COPY DD-CLIENTS.
    COPY DD-SERVER-PROPERTIES.
    01 POS-CHUNK-X              BINARY-LONG.
    01 POS-CHUNK-Z              BINARY-LONG.
    01 CHUNK-INDEX              BINARY-LONG UNSIGNED.
    01 BLOCK-IN-CHUNK-INDEX     BINARY-LONG UNSIGNED.
    01 CLIENT-ID                BINARY-LONG UNSIGNED.
    01 ALLOCATE-PTR             PROGRAM-POINTER.
LINKAGE SECTION.
    01 LK-POSITION.
        02 LK-X                 BINARY-LONG.
        02 LK-Y                 BINARY-LONG.
        02 LK-Z                 BINARY-LONG.
    01 LK-BLOCK-ENTITY-ID       BINARY-LONG.

PROCEDURE DIVISION USING LK-POSITION LK-BLOCK-ENTITY-ID.
    *> Find the chunk and block indices
    DIVIDE LK-X BY 16 GIVING POS-CHUNK-X ROUNDED MODE IS TOWARD-LESSER
    DIVIDE LK-Z BY 16 GIVING POS-CHUNK-Z ROUNDED MODE IS TOWARD-LESSER
    CALL "World-FindChunkIndex" USING POS-CHUNK-X POS-CHUNK-Z CHUNK-INDEX
    IF CHUNK-INDEX = 0
        GOBACK
    END-IF
    SET ADDRESS OF CHUNK TO WORLD-CHUNK-POINTER(CHUNK-INDEX)

    COMPUTE BLOCK-IN-CHUNK-INDEX = ((LK-Y + 64) * 16 + (FUNCTION MOD(LK-Z, 16))) * 16 + (FUNCTION MOD(LK-X, 16)) + 1

    *> Deallocate and remove any existing block entity
    IF CHUNK-BLOCK-ENTITY-ID(BLOCK-IN-CHUNK-INDEX) >= 0
        FREE CHUNK-BLOCK-ENTITY-DATA(BLOCK-IN-CHUNK-INDEX)
        SUBTRACT 1 FROM CHUNK-BLOCK-ENTITY-COUNT
    END-IF

    *> Set the block entity ID and mark the chunk as dirty
    MOVE LK-BLOCK-ENTITY-ID TO CHUNK-BLOCK-ENTITY-ID(BLOCK-IN-CHUNK-INDEX)
    ADD 1 TO CHUNK-BLOCK-ENTITY-COUNT
    MOVE 1 TO CHUNK-DIRTY-BLOCKS

    *> Allocate memory for the block entity data
    SET ALLOCATE-PTR TO CB-PTR-BLOCK-ENTITY-ALLOCATE(LK-BLOCK-ENTITY-ID + 1)
    IF ALLOCATE-PTR NOT = NULL
        CALL ALLOCATE-PTR USING CHUNK-BLOCK-ENTITY-DATA(BLOCK-IN-CHUNK-INDEX)
    END-IF

    *> Notify clients
    PERFORM VARYING CLIENT-ID FROM 1 BY 1 UNTIL CLIENT-ID > MAX-CLIENTS
        IF CLIENT-STATE(CLIENT-ID) = CLIENT-STATE-PLAY
            CALL "SendPacket-BlockEntityData" USING CLIENT-ID LK-POSITION CHUNK-BLOCK-ENTITY(BLOCK-IN-CHUNK-INDEX)
        END-IF
    END-PERFORM

    GOBACK.

END PROGRAM World-SetBlockEntity.

*> --- World-NotifyChanged ---
*> Mark a block as changed in the world (e.g. due to block entity data change), which ensures the chunk is saved,
*> and notifies clients of the change.
IDENTIFICATION DIVISION.
PROGRAM-ID. World-NotifyChanged.

DATA DIVISION.
WORKING-STORAGE SECTION.
    COPY DD-WORLD.
    COPY DD-CHUNK-REF.
    COPY DD-CLIENT-STATES.
    COPY DD-CLIENTS.
    COPY DD-SERVER-PROPERTIES.
    01 POS-CHUNK-X              BINARY-LONG.
    01 POS-CHUNK-Z              BINARY-LONG.
    01 CHUNK-INDEX              BINARY-LONG UNSIGNED.
    01 CHUNK-BLOCK-INDEX        BINARY-LONG UNSIGNED.
    01 SECTION-INDEX            BINARY-LONG UNSIGNED.
    01 SECTION-BLOCK-INDEX      BINARY-LONG UNSIGNED.
    01 BLOCK-ID                 BINARY-LONG UNSIGNED.
    01 CLIENT-ID                BINARY-LONG UNSIGNED.
LINKAGE SECTION.
    01 LK-POSITION.
        02 LK-X                 BINARY-LONG.
        02 LK-Y                 BINARY-LONG.
        02 LK-Z                 BINARY-LONG.

PROCEDURE DIVISION USING LK-POSITION.
    DIVIDE LK-X BY 16 GIVING POS-CHUNK-X ROUNDED MODE IS TOWARD-LESSER
    DIVIDE LK-Z BY 16 GIVING POS-CHUNK-Z ROUNDED MODE IS TOWARD-LESSER
    CALL "World-FindChunkIndex" USING POS-CHUNK-X POS-CHUNK-Z CHUNK-INDEX
    IF CHUNK-INDEX = 0
        GOBACK
    END-IF
    SET ADDRESS OF CHUNK TO WORLD-CHUNK-POINTER(CHUNK-INDEX)

    MOVE 1 TO CHUNK-DIRTY-BLOCKS

    COMPUTE CHUNK-BLOCK-INDEX = ((LK-Y + 64) * 16 + (FUNCTION MOD(LK-Z, 16))) * 16 + (FUNCTION MOD(LK-X, 16)) + 1
    COMPUTE SECTION-INDEX = (LK-Y + 64) / 16 + 1
    COMPUTE SECTION-BLOCK-INDEX = ((FUNCTION MOD(LK-Y + 64, 16)) * 16 + (FUNCTION MOD(LK-Z, 16))) * 16 + (FUNCTION MOD(LK-X, 16)) + 1
    MOVE CHUNK-SECTION-BLOCK(SECTION-INDEX, SECTION-BLOCK-INDEX) TO BLOCK-ID

    PERFORM VARYING CLIENT-ID FROM 1 BY 1 UNTIL CLIENT-ID > MAX-CLIENTS
        IF CLIENT-STATE(CLIENT-ID) = CLIENT-STATE-PLAY
            CALL "SendPacket-BlockUpdate" USING CLIENT-ID LK-POSITION BLOCK-ID
            CALL "SendPacket-BlockEntityData" USING CLIENT-ID LK-POSITION CHUNK-BLOCK-ENTITY(CHUNK-BLOCK-INDEX)
        END-IF
    END-PERFORM

    GOBACK.

END PROGRAM World-NotifyChanged.
