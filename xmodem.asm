* ASCII DEFINITIONS
SOH    EQU   $01
STX    EQU   $02
ACK    EQU   $06
NAK    EQU   $15
EOT    EQU   $04
CAN    EQU   $18

* RECEIVE DISK FILE VIA XMODEM
XMRECV
 STS XMRET
* banner
 LBSR XMPRT
 FCB 13
 FCC "X/YMODEM receive to disk:"
 FCB 13
 FCB 0
* clear xmodem data buffer
 LDD #0
 STD XMLEN
* open disk file
 LBSR FWOPEN
 TSTB
 LBNE XCFULL
* block = 1
 CLR BLOCK
 CLR BLOCK+1
 INC BLOCK+1
 CLR ERRS
* assume CRC checksum
 LDA #2
 STA XMCSZ
* send kickoff 'C'
 LDA #'C
 LBSR SEND
 LBSR RDBLOK
 BEQ XROK
* assume normal checksum
 LDA #1
 STA XMCSZ
* send kickoff NAK
 CLR BLOCK+1
 LDA #NAK
 LBSR SEND
* read block(s)
XMRL
 LDD BLOCK
 ADDD #1
 STD BLOCK
 LBSR RDBLOK
 TSTB okay?
 BEQ XROK
 CMPB #4 eot?
 BEQ XREOT
 CMPB #3 cancel?
 BEQ XRABT
* error
 INC ERRS
 LBSR PERR report error
 LDA ERRS
 CMPA #10  too many errors?
 LBGE XRABT
* try to recover
 LBSR SETTLE
 LDA #NAK
 LBSR SEND nak bad block
 LDD BLOCK
 SUBD #1
 STD BLOCK  back up a block
 BRA XMRL  try again
XROK
 CLR ERRS
 LBSR PERR report status
* derive filetype
 LDD BLOCK
 CMPD #1
 BNE XROK0
 LDB XMBUF
 LBSR FTYPE
* block okay
XROK0
 LBSR XMWDSK write buffer to disk
 LDA #ACK
 LBSR SEND ack good block
 BRA XMRL  go for more
XREOT
 LDA #ACK
 LBSR SEND ack eot
 LBSR XMPRT
 FCB 13
 FCC "X/YMODEM download completed"
 FCB 13
 FCB 0
 BRA Y@
XRABT
 LDA #CAN
 LBSR SEND cancel
 LBSR XMPRT
 FCB 13
 FCC "X/YMODEM download aborted"
 FCB 13
 FCB 0
 BRA XRXM
* Disk full on write
XWFULL
 LDB FGRAN
 LDX #ALCBUF
 LDA #$C0
 ADDA FSECT
 STA B,X
 LDX FPTR
 LDD #256
 STD FBLCNT,X
 LBSR DWTFB
* Disk full on create
XCFULL
 LBSR XMPRT
 FCB 13
 FCC "ERROR: DISK FULL"
 FCB 13
 FCB 0
 BRA ABORT
Y@
 LBSR FCLOS close disk file
* motor off
XRXM
 LBSR MOTOFF
 RTS

ABORT
 LBSR MOTOFF
 LDA #CAN
 LBSR SEND
 LBSR XMPRT
 FCB 13
 FCC "X/YMODEM transfer aborted"
 FCB 13
 FCB 0
 LDS XMRET
 RTS

* SEND DISK FILE VIA XMODEM
XMSEND
 STS XMRET
* banner
 LBSR XMPRT
 FCB 13
 FCC "X/YMODEM send from disk:"
 FCB 13
 FCB 0
* assume normal checksum
 LDA #1
 STA XMCSZ
* open file
 LBSR FROPEN
 TSTB
 LBNE Q@
* wait for kickoff ACK or 'C'
 LBSR XMGET
 LBCS ABORT
 CMPA #'C
 BNE T@
* set CRC checksum
 LDA #2
 STA XMCSZ
* wait for K, if present
 LBSR XMGET
T@
* send block(s)
 CLR BLOCK
 CLR BLOCK+1
 CLR ERRS
* get sector(s) from disk
A@
 LBSR XMRDSK
* EOF?
B@
 LDD XMLEN
 BEQ X@
* send blocks
 LDX #XMBUF
C@
 LBSR WTBLOK
 LDD XMSIZ
 LEAX D,X
 LDD XMLEN
 SUBD XMSIZ
 STD XMLEN
 BNE C@
 BRA A@
* file eof
X@
 LBSR MOTOFF
 LBSR XMPRT
 FCB 13
 FCC "X/YMODEM upload completed"
 FCB 13
 FCB 0
 LDA #EOT
 LBSR SEND
 LBSR XMGET
 RTS
Q@
 LBSR MOTOFF
 LBSR XMPRT
 FCC "File not found"
 FCB 13
 FCB 0
 RTS

* Open disk file for read
* B: returned status
*   0 okay
*   1 error
*
FROPEN
 PSHS X
* normalize filename
 LDX #LINE
 LBSR XFNAM
* CPU slow, interrupts off
 STA $FFD8
 ORCC #$50
* search for file
 LBSR DSERCH
 LBMI E@
 LBNE E@
* CPU fast, interrupts on
 STA $FFD9
 ANDCC #$AF
* okay
 CLRB
 PULS X,PC
E@
* CPU fast, interrupts on
 STA $FFD9
 ANDCC #$AF
* error
 LDB #1
 PULS X,PC

* READ SECTOR FROM DISK FILE
* X: sector buffer
* D: # bytes in sector (0=EOF)
*
FREAD
 PSHS X
* CPU slow, interrupts off
 STA $FFD8
 ORCC #$50
 LBSR DPOSFW
 BEQ X@
 PSHS D
 LBSR DREAD
 LBMI ABORT
* clear unused bytes
 LDX 2,S
 LEAX 256,X
 LDD #256
 SUBD ,S
 CLRA
 INCB
B@
 DECB
 BEQ C@
 CLR ,-X
 BRA B@
*
C@
 PULS D
X@
* CPU fast, interrupts on
 STA $FFD9
 ANDCC #$AF
 ADDD #0
 PULS X,PC

* WRITE AN XMODEM BLOCK
* X: block buffer
*
WTBLOK
 PSHS X
 CLR ERRS
 LDD BLOCK
 ADDD #1
 STD BLOCK
A@
* send header
 LDD XMLEN
 CMPD #1024
 BHS S@
* 128 byte block
 LDD #128
 STD XMSIZ
 LDA #SOH
 LBSR SEND
 BRA T@
* 1024 byte block
S@
 LDD #1024
 STD XMSIZ
 LDA #STX
 LBSR SEND
T@
* send block number
 LDA BLOCK+1
 LBSR SEND
 LDA BLOCK+1
 COMA
 LBSR SEND
* display block number
 LBSR PBLOK
* send data
 LDX ,S
 LDY XMSIZ
 LBSR WTDATA
 LDA XMCSZ
 CMPA #1
 BEQ K@
* send CRC
 LDA CRC
 LBSR SEND
 LDA CRC+1
 LBSR SEND
 BRA Y@
* send checksum
K@
 LDA CKSUM
 LBSR SEND
* get response
Y@
 LBSR XMGET
 BCS E@
 CMPA #ACK
 BEQ O@
 CMPA #CAN
 LBEQ ABORT
 CMPA #EOT
 LBEQ ABORT
* error - try to recover
E@
 INC ERRS
 LBSR PERR
 LDA ERRS
 CMPA #10
 BLE A@ try again
* too many errors
 LBRA ABORT
* okay - return
O@
 CLR ERRS
 LBSR PERR
 PULS X,PC

* WRITE A SPECIFIED NUMBER OF BYTES
* TO RS232
* X: buffer
* Y: length
*
WTDATA
 PSHS X,Y
 CLR CRC
 CLR CRC+1
 CLR CKSUM
 LEAY 1,Y
A@
 LEAY -1,Y
 BEQ X@
 LDA ,X+
 LBSR GETCRC
 LBSR SEND
 BRA A@
X@
 PULS X,Y,PC

* READ AN XMODEM BLOCK
* B: returned status
*   0 ok
*   1 timeout
*   2 block error (checksum)
*   3 cancel
*   4 eot
*
RDBLOK
* point to end of buffer
 LDD XMLEN
 LDX #XMBUF
 LEAX D,X
* assume 128 byte blocks
 LDD #128
 STD XMSIZ
* read header byte
RHB
 LDY #1
 LBSR RDDATA
* timeout?
 TSTB
 BNE B@
* display current block
 LBSR PBLOK
* check header byte
 LDA ,X
* EOT?
 CMPA #EOT
 BEQ E@
* CAN? 
 CMPA #CAN
 BEQ D@
* SOH?
 CMPA #SOH
 BEQ X@
* STX?
 CMPA #STX
 BNE C@
 LDD #1024
 STD XMSIZ
* read block number
X@
 LDY #2
 LBSR RDDATA
* timeout?
 TSTB
 BNE B@
* check block number
 LDA ,X
 COMA
 CMPA 1,X
 BNE C@
* read data
 LDY XMSIZ
 LBSR RDDATA
 TSTB
 BNE B@
* save data checksum
 LDD CRC
 STD XCRC
 LDA CKSUM
 STA XCKSUM
* read checksum
 CLRA
 LDB XMCSZ
 TFR D,Y
 LDX #XMBUF+1024
 LBSR RDDATA
 TSTB
 BNE B@
* checksum okay?
 LDA XMCSZ
 CMPA #1
 BEQ R@
* crc check
 LDD ,X
 CMPD XCRC
 BNE C@
 BRA A@
R@
* check checksum
 LDB ,X
 CMPB XCKSUM
 BNE C@
*return status
A@
 LDD XMSIZ  add in new data
 ADDD XMLEN
 STD XMLEN
 LDB #0 status: okay
 RTS
B@
 LDB #1 status: timeout
 RTS
C@
 LDB #2 status: block error (checksum)
 RTS
D@
 LDB #3 status: cancel
 RTS
E@
 LDB #4 status: eot
 RTS

* READ A SPECIFIED NUMBER OF BYTES
* FROM RS232
* X: buffer
* Y: requested length
* B: returned status
*   0 okay
*   1 timeout
*
RDDATA
 PSHS X
 CLR CRC   clear checksums
 CLR CRC+1
 CLR CKSUM
 LEAY 1,Y
A@
 LEAY -1,Y
 BEQ X@
 LBSR XMGET
 BCS B@
 LBSR GETCRC
 STA ,X+
 BRA A@
B@
 LDB #1 status: timeout error
 PULS X,PC
X@
 CLRB   status: okay
 PULS X,PC

* THIS ROUTINE PRINTS THE BLOCK COUNT
* AND THE NUMBER OF ERRORS ON THE
* SCREEN
PERR PSHS  D,X,Y,U
 LDA #13
 LBSR PUT  return
 LBSR XMPRT
 FCC "Block "
 FCB 0
 LDD BLOCK
 LBSR PRTNUM
 LDB ERRS
 BEQ NERS
* Errors to report
YERS
 LBSR XMPRT
 FCC ", "
 FCB 0
 LDB ERRS
 CLRA
 LBSR PRTNUM
 LBSR XMPRT
 FCC " Error(s)    "
 FCB 0
 BRA XPERR
NERS
* No errors to report
 LBSR XMPRT
 FCC " ...okay        "
 FCB 0
XPERR
 PULS D,X,Y,U,PC

* THIS ROUTINE PRINTS THE BLOCK COUNT
PBLOK PSHS  D,X,Y,U
 LDA #13
 LBSR PUT  return
 LBSR XMPRT
 FCC "Block "
 FCB 0
 LDD BLOCK
 LBSR PRTNUM
 LDB ERRS    errors?
 BNE YERS
 LBSR XMPRT
 FCC "                "
 FCB 0
 PULS D,X,Y,U,PC

* THIS ROUTINE WAITS FOR A BYTE
* TO COME IN THE RS232 PORT
* FOR APPROX 10 SECONDS.
* IF BYTE RECEIVED, CARRY CLEAR
* AND CHAR IN A, ELSE CARRY SET

XMGET
 PSHS X,Y
 LDX #$FFFF timeout = 10 secs
XA
 PSHS B
 LBSR RECV   BYTE READY?
 PULS B
 BNE XB     IF BYTE
 LBSR BRKCK  break pressed?
 LBEQ ABORT  ABORT
 LEAX -1,X   DEC COUNTER
 BNE XA     IF NOT LIMIT 
 ORCC #1     SET CARRY
 PULS X,Y,PC   AND RETURN
XB
 ANDCC #$FE   CLEAR CARRY
 PULS X,Y,PC   AND RETURN

TBL10
 FDB 10000
 FDB 1000
 FDB 100
 FDB 10
 FDB 1
 FDB 0

* PRINT NUMBER ROUTINE
* D=NUMBER
PRTNUM
 PSHS D,X,Y,U
* strip sign bit
 ANDA #$7F
* push on stack
 LEAS -1,S
 PSHS D
* zero suppress
 LDX #1
* value is zero?
 CMPD #0
 BEQ PRTN5
* init scale table ptr
 LEAU TBL10,PCR

* calculate digit
PRTN0
 LDA #'0
 STA 2,S
PRTN1
 LDD ,S
 SUBD ,U
 BLT PRTN2
 INC 2,S
 STD ,S
 BRA PRTN1
PRTN2

* output digit
 LDA 2,S
 CMPA #'0
 BEQ PRTN3
* nonzero digit
 LBSR PUT
 LDX #0
 BRA PRTN4
* zero digit
PRTN3
 CMPX #0
 BNE PRTN4
* not leading zero
 LBSR PUT
* next power of 10
PRTN4
 LEAU 2,U
 LDD ,U
 BNE PRTN0
 BRA PRTNX

* special zero logic
PRTN5
 LDA #'0
 LBSR PUT
 
* release stack and return
PRTNX
 LEAS 3,S
 PULS D,X,Y,U,PC

* LBSR XMPRT
* FCC /DATA/
* FCB 0
* (CONTINUE PGM)
XMPRT
 PULS X
 INC AUTOLF
XMPA
 LDA ,X+
 BEQ XMPB
 LBSR PUT
 LBSR XR
 BRA XMPA
XMPB
 DEC AUTOLF
 TFR X,PC

* Open file
* B: returned status
*   0: okay
*   1: error
FWOPEN
* CPU slow, interrupts off
 STA $FFD8
 ORCC #$50
* normalize filename
 LDX #LINE
 LBSR XFNAM
* does file exist?
 LBSR DSERCH
 LBMI E@
 BNE A@
* delete existing file
 LDA FILBUF
 CMPA #'* don't delete ALL files!
 BEQ A@
 LBSR RMFILE
* create file
A@
 LDX #FILBUF
 LBSR CREFIL
 BMI E@
 BNE X@
E@
* error
 STA $FFD9
 ANDCC #$AF
 LDB #1 status: error
 RTS
X@
* CPU fast, interrupts on
 STA $FFD9
 ANDCC #$AF
 CLRB   status: okay
 RTS

* File write - sector
* X: buffer address
* B: returned status
*   0: okay
*   1: error
*
FWRIT
 PSHS X
* CPU slow, interrupts off
 STA $FFD8
 ORCC #$50
* position forward
 LDX #XMBUF
 LDD XMLEN
 LEAX D,X
 LBSR DPOSFW
 LDB FSECT
 CMPB #9
 BLS A@
* allocate another granule
 LDB #1
 STB FSECT
 LBSR GTGRAN
 BEQ E@
 LDX #ALCBUF
 LDA FGRAN
 STB A,X
 LDA #$C0
 STA B,X
 STB FGRAN
A@
* write sector
 LDX ,S
 LBSR DWRIT
 BMI E@
* CPU fast, interrupts on
 STA $FFD9
 ANDCC #$AF
* status: good
 CLRB
 PULS X,PC
E@
* CPU fast, interrupts on
 STA $FFD9
 ANDCC #$AF
* status: error
 LDB #1
 PULS X,PC

* File close
* B: returned status
*   0: okay
*   1: error
*
FCLOS
* slow CPU, interrupts off
 STA $FFD8
 ORCC #$50
* flush sector(s) to disk
 LBSR XMWDSK
* partial sector?
 LDD XMLEN
 BEQ A@
* flush partial sector
 LBSR FWRIT
 LDD XMLEN
 BRA C@
* no partial sector
A@
 LDD #256
* update last sector count
C@
 LDX FPTR
 STD FBLCNT,X
* update last granule
 LDB FGRAN
 LDX #ALCBUF
 LEAX B,X
 LDA #$C0
 ADDA FSECT
 STA ,X
* rewrite file block
 LBSR DWTFB
* CPU fast, interrupts on
 STA $FFD9
 ANDCC #$AF
 CLRB
 RTS

* check for BREAK key
* A: 0 if pressed
*
BRKCK
 PSHS D,X,Y,U
 LDB #50 break pressed?
 LBSR KEYTST
 BNE A@
 LBSR GET yes, eat break
 INC AUTOLF
 LDA #$0D
 LBSR PUT echo CRLF
 DEC AUTOLF
 CLRA return "eq" status
A@
 PULS D,X,Y,U,PC

* WAIT FOR INCOMING LINE TO SETTLE
SETTLE
 PSHS X
C@
 LDX #$2000 timeout = 1 sec
A@
 LBSR RECV   byte ready?
 BNE C@      ignore incoming bytes
 LBSR BRKCK  break pressed?
 LBEQ ABORT
 LEAX -1,X   timeout?
 BNE A@      if not, keep looking
 PULS X,PC   exit on timeout

*** checksum and CRC calculations ***
* A: char

GETCRC PSHS D save A,B regs
 LDB CKSUM
 ADDB ,S
 STB CKSUM
 LDB #8       counter
 PSHS B
 EORA CRC  OR in current char
 STA CRC   save value
 LDB CRC+1 get CRC in D reg
A@
 LSLB
 ROLA
 BCC B@
 EORA #$10
 EORB #$21
B@
 STD CRC save value
 DEC ,S  done 8 times?
 BNE A@  if not
 LEAS 1,S
 PULS D,PC

* write xmodem buffer to disk
XMWDSK
 LDX #XMBUF
A@
 LDD XMLEN
 CMPD #256
 BLO X@
* write a sector
 LBSR FWRIT
 LEAX 256,X
 LDD XMLEN
 SUBD #256
 STD XMLEN
 BRA A@
X@
 RTS

* read disk to xmodem buffer
XMRDSK
 LDD #0
 STD XMLEN
 LDX #XMBUF
A@
* clear sector
 TFR X,Y
 CLRA
B@
 CLR ,X+
 DECA
 BNE B@
* read sector
C@
 TFR Y,X
 LBSR FREAD
 BEQ X@
* adjust length to sector boundary
 LDD #256
* add in length
 LEAX D,X
 ADDD XMLEN
 STD XMLEN
* if ymodem, get more
 LDA XMCSZ
 CMPA #1
 BEQ X@
 LDD XMLEN
 CMPD #1024
 BLO A@
X@
 RTS

