       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAYMENTPROC.
       AUTHOR. Matheus Pina.
       
       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CONFIG-FILE ASSIGN TO 'data/CONFIG.TXT'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-CONFIG.
           SELECT ACC-FILE ASSIGN TO 'data/ACCOUNTS.TXT'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-ACC.
           SELECT TRANS-FILE ASSIGN TO 'data/TRANSACTIONS.TXT'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-TRANS.
           SELECT OUT-FILE ASSIGN TO 'output/APPROVED.TXT'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-OUT.
           SELECT ERR-FILE ASSIGN TO 'output/REJECTED.TXT'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-ERR.
           SELECT REP-FILE ASSIGN TO 'output/REPORT.TXT'
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS FS-REP.

       DATA DIVISION.
       FILE SECTION.
       FD  CONFIG-FILE.
       01  CONFIG-REC        PIC X(80).

       FD  ACC-FILE.
       01  ACC-REC           PIC X(80).

       FD  TRANS-FILE.
       01  TRANS-REC         PIC X(80).

       FD  OUT-FILE.
       01  OUT-REC           PIC X(80).

       FD  ERR-FILE.
       01  ERR-REC           PIC X(80).

       FD  REP-FILE.
       01  REP-REC           PIC X(80).

       WORKING-STORAGE SECTION.
      * --- FILE STATUS VARIABLES ---
       01  FS-CONFIG         PIC X(2).
           88 CONFIG-OK      VALUE '00'.
       01  FS-ACC            PIC X(2).
           88 ACC-OK         VALUE '00'.
       01  FS-TRANS          PIC X(2).
           88 TRANS-OK       VALUE '00'.
       01  FS-OUT            PIC X(2).
           88 OUT-OK         VALUE '00'.
       01  FS-ERR            PIC X(2).
           88 ERR-OK         VALUE '00'.
       01  FS-REP            PIC X(2).
           88 REP-OK         VALUE '00'.

      * --- SYSTEM FLAGS ---
       01  WS-FLAGS.
           05 WS-EOF-FLAG    PIC X VALUE 'N'.
              88 END-OF-FILE VALUE 'Y'.
           05 WS-REJECT-FLG  PIC X VALUE 'N'.
              88 TXN-REJECTED VALUE 'Y'.
              88 TXN-APPROVED VALUE 'N'.

      * --- CONFIGURATION PARAMS ---
       01  WS-SYS-CONFIG.
           05 WS-MAX-DEBIT   PIC 9(6) VALUE 0.
           05 WS-ALLOW-CREDIT PIC X VALUE 'N'.
           05 WS-CONF-KEY    PIC X(20).
           05 WS-CONF-VAL    PIC X(20).

      * --- COUNTERS & TOTALS ---
       01  WS-COUNTERS.
           05 WS-TOTAL       PIC 9(6) VALUE 0.
           05 WS-APPROVED    PIC 9(6) VALUE 0.
           05 WS-REJECTED    PIC 9(6) VALUE 0.
       
      * --- TRANSACTION BUFFER ---
       01  WS-TXN-DATA.
           05 T-ID           PIC X(6).
           05 T-TYPE         PIC X(10).
           05 T-AMOUNT-STR   PIC X(6).
           05 T-AMOUNT       PIC 9(6).
       01  WS-MSG            PIC X(30).

      * --- IN-MEMORY DATA STRUCTURES ---
       01  ACCOUNT-TABLE.
           05 ACC-ENTRY OCCURS 1 TO 1000 TIMES 
              DEPENDING ON WS-ACC-COUNT
              ASCENDING KEY IS TAB-ACC-ID
              INDEXED BY ACC-IDX.
              10 TAB-ACC-ID  PIC X(6).
              10 TAB-ACC-BAL PIC 9(9).
       01  WS-ACC-COUNT      PIC 9(4) VALUE 0.

       PROCEDURE DIVISION.

       0000-MAIN-PROCEDURE.
           PERFORM 1000-INIT-FILES
           PERFORM 2000-LOAD-CONFIG
           PERFORM 3000-LOAD-ACCOUNTS
           
           MOVE 'N' TO WS-EOF-FLAG
           PERFORM 4000-PROCESS-TRANSACTIONS 
               UNTIL END-OF-FILE
               
           PERFORM 8000-WRITE-REPORT
           PERFORM 9000-CLEANUP
           STOP RUN.

       1000-INIT-FILES.
           OPEN INPUT CONFIG-FILE ACC-FILE TRANS-FILE
           OPEN OUTPUT OUT-FILE ERR-FILE REP-FILE
           
           IF NOT ACC-OK OR NOT TRANS-OK
               DISPLAY "CRITICAL ERROR: FAILED TO OPEN I/O FILES."
               DISPLAY "ACC-FS: " FS-ACC " TRANS-FS: " FS-TRANS
               STOP RUN
           END-IF.

       2000-LOAD-CONFIG.
           MOVE 'N' TO WS-EOF-FLAG
           PERFORM UNTIL END-OF-FILE
               READ CONFIG-FILE
                   AT END 
                       SET END-OF-FILE TO TRUE
                   NOT AT END
                       UNSTRING CONFIG-REC DELIMITED BY "="
                           INTO WS-CONF-KEY WS-CONF-VAL
                       EVALUATE WS-CONF-KEY
                           WHEN "MAX_DEBIT"
                               COMPUTE WS-MAX-DEBIT = 
                                   FUNCTION NUMVAL(WS-CONF-VAL)
                           WHEN "ALLOW_CREDIT"
                               MOVE WS-CONF-VAL TO WS-ALLOW-CREDIT
                       END-EVALUATE
               END-READ
           END-PERFORM.

       3000-LOAD-ACCOUNTS.
           MOVE 'N' TO WS-EOF-FLAG
           PERFORM UNTIL END-OF-FILE
               READ ACC-FILE
                   AT END 
                       SET END-OF-FILE TO TRUE
                   NOT AT END
                       IF WS-ACC-COUNT >= 1000
                           DISPLAY "CRITICAL: ACC TABLE OVERFLOW."
                           STOP RUN
                       END-IF
                       ADD 1 TO WS-ACC-COUNT
                       UNSTRING ACC-REC DELIMITED BY ALL SPACES
                           INTO TAB-ACC-ID(WS-ACC-COUNT)
                                T-AMOUNT-STR
                       COMPUTE TAB-ACC-BAL(WS-ACC-COUNT) = 
                           FUNCTION NUMVAL(T-AMOUNT-STR)
               END-READ
           END-PERFORM.
           
       4000-PROCESS-TRANSACTIONS.
           READ TRANS-FILE
               AT END 
                   SET END-OF-FILE TO TRUE
               NOT AT END
                   ADD 1 TO WS-TOTAL
                   SET TXN-APPROVED TO TRUE
                   MOVE SPACES TO WS-MSG
                   PERFORM 5000-VALIDATE-AND-APPLY
           END-READ.

       5000-VALIDATE-AND-APPLY.
           UNSTRING TRANS-REC DELIMITED BY ALL SPACES
               INTO T-ID T-TYPE T-AMOUNT-STR

      * --- defensive validation ---
           IF T-AMOUNT-STR = SPACES
               MOVE "MISSING AMOUNT" TO WS-MSG
               SET TXN-REJECTED TO TRUE
               PERFORM 7000-WRITE-ERROR
               EXIT PARAGRAPH
           ELSE
               COMPUTE T-AMOUNT = FUNCTION NUMVAL(T-AMOUNT-STR)
           END-IF

      * --- Business Logic Validation ---
           IF T-TYPE = "DEBIT" AND T-AMOUNT > WS-MAX-DEBIT
               MOVE "EXCEEDS MAX DEBIT" TO WS-MSG
               SET TXN-REJECTED TO TRUE
           END-IF

           IF T-TYPE = "CREDIT" AND WS-ALLOW-CREDIT = 'N'
               MOVE "CREDITS NOT ALLOWED" TO WS-MSG
               SET TXN-REJECTED TO TRUE
           END-IF

      * --- Account Lookup & Balance Check ---
           IF TXN-APPROVED
               SEARCH ALL ACC-ENTRY
                   AT END
                       MOVE "ACCOUNT NOT FOUND" TO WS-MSG
                       SET TXN-REJECTED TO TRUE
                   WHEN TAB-ACC-ID(ACC-IDX) = T-ID
                       IF T-TYPE = "DEBIT" AND 
                          T-AMOUNT > TAB-ACC-BAL(ACC-IDX)
                           MOVE "INSUFFICIENT FUNDS" TO WS-MSG
                           SET TXN-REJECTED TO TRUE
                       ELSE
                           IF T-TYPE = "DEBIT"
                               SUBTRACT T-AMOUNT FROM 
                                   TAB-ACC-BAL(ACC-IDX)
                           ELSE
                               ADD T-AMOUNT TO 
                                   TAB-ACC-BAL(ACC-IDX)
                           END-IF
                       END-IF
               END-SEARCH
           END-IF

           IF TXN-REJECTED
               PERFORM 7000-WRITE-ERROR
           ELSE
               PERFORM 6000-WRITE-APPROVAL
           END-IF.

       6000-WRITE-APPROVAL.
           ADD 1 TO WS-APPROVED
           MOVE SPACES TO OUT-REC
           STRING "APPROVED: " T-ID " AMT: " T-AMOUNT
               DELIMITED BY SIZE INTO OUT-REC
           WRITE OUT-REC
           IF NOT OUT-OK
               DISPLAY "I/O ERROR ON APPROVAL WRITE."
           END-IF.

       7000-WRITE-ERROR.
           ADD 1 TO WS-REJECTED
           MOVE SPACES TO ERR-REC
           STRING "REJECTED: " T-ID " REASON: " WS-MSG
               DELIMITED BY SIZE INTO ERR-REC
           WRITE ERR-REC
           IF NOT ERR-OK
               DISPLAY "I/O ERROR ON ERROR WRITE."
           END-IF.

       8000-WRITE-REPORT.
           MOVE SPACES TO REP-REC
           STRING "TOTAL TRANSACTIONS: " WS-TOTAL
               DELIMITED BY SIZE INTO REP-REC
           WRITE REP-REC
           
           MOVE SPACES TO REP-REC
           STRING "TOTAL APPROVED:     " WS-APPROVED
               DELIMITED BY SIZE INTO REP-REC
           WRITE REP-REC
           
           MOVE SPACES TO REP-REC
           STRING "TOTAL REJECTED:     " WS-REJECTED
               DELIMITED BY SIZE INTO REP-REC
           WRITE REP-REC.

       9000-CLEANUP.
           CLOSE CONFIG-FILE ACC-FILE TRANS-FILE 
                 OUT-FILE ERR-FILE REP-FILE.
