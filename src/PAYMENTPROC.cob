       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAYMENTPROC.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ACC-FILE ASSIGN TO 'data/ACCOUNTS.TXT'
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT TRANS-FILE ASSIGN TO 'data/TRANSACTIONS.TXT'
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT OUT-FILE ASSIGN TO 'output/APPROVED.TXT'
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT ERR-FILE ASSIGN TO 'output/REJECTED.TXT'
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT REP-FILE ASSIGN TO 'output/REPORT.TXT'
               ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD ACC-FILE.
       01 ACC-REC        PIC X(80).

       FD TRANS-FILE.
       01 TRANS-REC      PIC X(80).

       FD OUT-FILE.
       01 OUT-REC        PIC X(80).

       FD ERR-FILE.
       01 ERR-REC        PIC X(80).

       FD REP-FILE.
       01 REP-REC        PIC X(80).

       WORKING-STORAGE SECTION.
       01 WS-EOF          PIC X VALUE 'N'.
       01 WS-REJECT-FLG   PIC X VALUE 'N'.
       
       01 WS-MAX-DEBIT    PIC 9(6) VALUE 500.
       01 WS-ALLOW-CREDIT PIC X VALUE 'Y'.

       01 WS-TOTAL        PIC 9(6) VALUE 0.
       01 WS-APPROVED     PIC 9(6) VALUE 0.
       01 WS-REJECTED     PIC 9(6) VALUE 0.
       
       01 WS-TXN-DATA.
          05 T-ID         PIC X(6).
          05 T-TYPE       PIC X(10).
          05 T-AMOUNT     PIC 9(6).
       01 WS-MSG          PIC X(30).

       01 ACCOUNT-TABLE.
          05 ACC-ENTRY OCCURS 1000 TIMES INDEXED BY ACC-IDX.
             10 TAB-ACC-ID   PIC X(6).
             10 TAB-ACC-BAL  PIC 9(9).
       01 WS-ACC-COUNT    PIC 9(4) VALUE 0.

       PROCEDURE DIVISION.

       MAIN-PROCEDURE.
           OPEN INPUT ACC-FILE TRANS-FILE
                OUTPUT OUT-FILE ERR-FILE REP-FILE
           
           PERFORM LOAD-ACCOUNTS
           
           MOVE 'N' TO WS-EOF
           PERFORM UNTIL WS-EOF = 'Y'
               READ TRANS-FILE
                   AT END MOVE 'Y' TO WS-EOF
                   NOT AT END
                       PERFORM PROCESS-TRANSACTION
               END-READ
           END-PERFORM

           PERFORM WRITE-REPORT
           CLOSE ACC-FILE TRANS-FILE OUT-FILE ERR-FILE REP-FILE
           STOP RUN.

       LOAD-ACCOUNTS.
           PERFORM UNTIL WS-EOF = 'Y'
               READ ACC-FILE
                   AT END MOVE 'Y' TO WS-EOF
                   NOT AT END
                       ADD 1 TO WS-ACC-COUNT
                       UNSTRING ACC-REC DELIMITED BY ALL SPACES
                           INTO TAB-ACC-ID(WS-ACC-COUNT)
                                TAB-ACC-BAL(WS-ACC-COUNT)
               END-READ
           END-PERFORM.

       PROCESS-TRANSACTION.
           ADD 1 TO WS-TOTAL
           MOVE 'N' TO WS-REJECT-FLG
           MOVE SPACES TO WS-MSG
           
           UNSTRING TRANS-REC DELIMITED BY ALL SPACES
               INTO T-ID, T-TYPE, T-AMOUNT

           IF T-TYPE = "DEBIT" AND T-AMOUNT > WS-MAX-DEBIT
               MOVE "EXCEEDS MAX DEBIT" TO WS-MSG
               MOVE 'Y' TO WS-REJECT-FLG
           END-IF

           IF T-TYPE = "CREDIT" AND WS-ALLOW-CREDIT = 'N'
               MOVE "CREDITS NOT ALLOWED" TO WS-MSG
               MOVE 'Y' TO WS-REJECT-FLG
           END-IF

           IF WS-REJECT-FLG = 'N'
               SET ACC-IDX TO 1
               SEARCH ACC-ENTRY
                   AT END 
                       MOVE "ACCOUNT NOT FOUND" TO WS-MSG
                       MOVE 'Y' TO WS-REJECT-FLG
                   WHEN TAB-ACC-ID(ACC-IDX) = T-ID
                       IF T-TYPE = "DEBIT" AND 
                          T-AMOUNT > TAB-ACC-BAL(ACC-IDX)
                           MOVE "INSUFFICIENT FUNDS" TO WS-MSG
                           MOVE 'Y' TO WS-REJECT-FLG
                       END-IF
               END-SEARCH
           END-IF

           IF WS-REJECT-FLG = 'Y'
               PERFORM WRITE-ERROR
           ELSE
               PERFORM WRITE-APPROVAL
           END-IF.

       WRITE-APPROVAL.
           ADD 1 TO WS-APPROVED
           MOVE SPACES TO OUT-REC
           STRING "APPROVED: " T-ID " AMT: " T-AMOUNT 
               DELIMITED BY SIZE INTO OUT-REC
           WRITE OUT-REC.

       WRITE-ERROR.
           ADD 1 TO WS-REJECTED
           MOVE SPACES TO ERR-REC
           STRING "REJECTED: " T-ID " REASON: " WS-MSG
               DELIMITED BY SIZE INTO ERR-REC
           WRITE ERR-REC.

       WRITE-REPORT.
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
