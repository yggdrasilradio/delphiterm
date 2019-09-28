*=============================
*  DISK I/O
*=============================

*FILE BLOCK LAYOUT
FBTYP  EQU 11 FILE TYPE
FBASC  EQU 12 ASCII FLAG
FBBEG  EQU 13 BEGINING GRANULE
FBLCNT EQU 14 #BYTE LAST SECT

*------------------------------
*  SAVE TO DISK
*   ENTRY:  X-FILENAME
*           Y-START OF DATA
*           D-LENGTH
*
DSAVE
 STA $FFD8  SLOW DOWN CPU
 ORCC #$50  INTERRUPTS OFF
 PSHS Y,X,D
 LBSR XFNAM
 ADDD 4,S
 STD ENDPTR

*SEARCH FOR FILE
 LBSR DSERCH
 LBMI DS99
 BEQ DS2

*FILE MUST BE CREATED
 LBSR CREFIL
 LBMI DS99
 BEQ DS92
DS2

*WRITE FILE
 LDX 4,S
DS3
 LBSR DPOSFW
 LDB FSECT
 CMPB #9
 BLS DS4
 LDB #1
 STB FSECT
 LBSR GTGRAN
 BEQ DS93
 PSHS X
 LDX #ALCBUF
 LDA FGRAN
 STB A,X
 LDA #$C0
 STA B,X
 STB FGRAN
 PULS X
DS4
 LBSR DWRIT
 BMI DS99
 LEAX 256,X
 CMPX ENDPTR
 BLO DS3

*EMPTY REMAINDER OF FILE
 LEAX -256,X
 STX TEMP
 LDD ENDPTR
 SUBD TEMP
 LDX FPTR
 STD FBLCNT,X

DS5
 LDB FGRAN
 LDX #ALCBUF
 LEAX B,X
 LDA #$C0
 ADDA FSECT
DS6
 LDB ,X
 STA ,X
 TFR B,A
 ANDB #$F0
 CMPB #$C0
 BEQ DS7
 LDX #ALCBUF
 LEAX A,X
 LDA #$FF
 BRA DS6
DS7
 BSR DWTFB
 BRA DS99

*ERR0R- DISK FULL DURING CREATE
DS92
 LEAX TXDFUL,PCR
 LBSR PERROR
 BRA DS99

*ERR0R- DISK FULL DURING WRITE
DS93
*MAKE SURE WE GET ALL WE CAN
 LDB FGRAN
 LDX #ALCBUF
 LDA #$C9
 STA B,X
 LDX FPTR
 LDD #256
 STD FBLCNT,X
 BSR DWTFB
 LEAX TXDFUL,PCR
 LBSR PERROR

DS99
 LBSR MOTOFF
 STA $FFD9  SPEED UP CPU
 ANDCC #$E0 INTERRUPTS ON
 PULS D,X,Y,PC
*
TXDFUL FCC "ERROR: DISK FULL"
 FCB 13,10
 FCB 0
TXDER  FCC "ERROR: DISK ERROR"
 FCB 13,10
 FCB 0
*-------------------------------
* re-write file allocation table
* and directory entry
*
DWTFB
 LDA #17
 LDB #2
 LDX #ALCBUF
 LBSR DKWRIT
 BMI DWTFB9
 LDD FDKADR
 LDX #DIRBUF
 LBSR DKWRIT
DWTFB9
 RTS
*------------------------------
*  LOAD FROM DISK
*   ENTRY X-FILENAME
*         Y-START OF DATA
*         D-MAXIMUM COUNT
*   EXIT: D-ACTUAL COUNT
*
DLOAD
 STA $FFD8  SLOW DOWN CPU
 ORCC #$50  INTERRUPTS OFF
 PSHS Y,X,D
 LBSR XFNAM

*OPEN READ
 LBSR DSERCH
 BMI DLD9
 BNE DLD8

*READ UNTIL EOF
 TFR Y,X
DLD1
 LBSR DPOSFW
 BEQ DLD7
 LBSR DREAD
 BMI DLD9
 LEAX D,X
 TFR X,D
 SUBD 4,S
 ADDD #256
 CMPD ,S
 BLS DLD1

*FILE WON'T FIT
 PSHS X
 LEAX TXFULL,PCR
 LBSR PERROR
 PULS X

DLD7
 TFR X,D
 SUBD 4,S
 STD ,S
 BRA DLD9

*FILENAME NOT FOUND
DLD8
 ANDCC #$E0
 STA $FFD9  SPEED UP CPU
 LEAX TXNPTH,PCR
 LBSR PERROR
 CLR ,S
 CLR 1,S

 LBSR MOTOFF
 STA $FFD9  SPEED UP CPU
 ANDCC #$E0 INTERRUPTS ON
 PULS D,X,Y,PC

DLD9
 LBSR MOTOFF
 STA $FFD9  SPEED UP CPU
 ANDCC #$E0 INTERRUPTS ON
 PULS D,X,Y,PC
*
TXFULL  FCC "ERROR: MEMORY FULL"
 FCB 13,10
 FCB 0
TXNPTH  FCC "ERROR: FILE NOT FOUND"
 FCB 13,10
 FCB 0
*------------------------------
* TRANSLATE FILE NAME
* FROM FFFF/TXT TO "FFFF    TXT"
*  ENTRY: X-POINTER TO RAW FILENAME
*  EXIT:  X-POINTER TO FILENAME
*         CC-NON-ZERO=ERROR
*
XFNAM
 PSHS Y,D
 LDB UNIT default drive
 STB DRIVE
XF1
 LDB #11
 LDA #BLANK
 LDY #FILBUF
XF2
 STA ,Y+
 DECB
 BNE XF2
 CLR ,Y

 LDY #FILBUF
 LDA #9
XF3
 LDB ,X+
 BSR UNITCK
 CMPB #CR
 BEQ XF4
 CMPB #BLANK
 BEQ XF4
 CMPB #',
 BEQ XF4
 CMPB #'/
 BEQ XF5
 CMPB #'.
 BEQ XF5
 STB ,Y+
 DECA
 BNE XF3
XF4

*PUT IN DEFAULT EXTENSION
 LEAX DEFEXT,PCR

XF5
 LDA #4
 LDY #FILBUF
 LEAY 8,Y
XF6
 LDB ,X+
 BSR UNITCK
 CMPB #CR
 BEQ XF7
 CMPB #BLANK
 BEQ XF7
 CMPB #',
 BEQ XF7
 STB ,Y+
 DECA
 BNE XF6

XF7
 LDX #FILBUF
 PULS D,Y,PC
*
DEFEXT FCC "TXT "
*-------
* LOCAL TO CHECK FOR UNIT # IN FILENAME
*
UNITCK
 CMPB #':
 BNE C@
 LDB ,X+
 TST MEMSZ disallow drives A and B
 BEQ A@    if 128K
 CMPB #'A
 BEQ B@
 CMPB #'B
 BEQ B@
A@
 ANDB #7
B@
 STB DRIVE
 LDB ,X+
C@
 RTS
*-------
*
*DISK SEARCH FOR FILE
*
*ENTRY X-FILE NAME
*EXIT  B-STATUS(0-NORM, 1-NOHIT,
*               -1-DISK ERROR)
*           (OR CC-ZER0/NONZERO)
*      FPTR  - POINTER TO FILE BLOCK
*      FGRAN - STARTING GRANULE
DSERCH
 PSHS A,X,Y
 CLR FGRAN
 CLR FSECT
 LDA #17
 LDB #2
 LDX #ALCBUF
 LBSR DKREAD
 BMI DSRC10
 LDB #3
 PSHS B
*
*FOR EACH SECTOR
DSRCH1
 LDA #17
 STD FDKADR
 LDX #DIRBUF
 LBSR DKREAD
 BMI DSRCH9
 CLR FINDX
*
*FOR EACH ENTRY IN THE SECTOR
DSRCH2
 LDX #DIRBUF
 LDB FINDX
 ABX B,X
 STX FPTR
 LDY 2,S
 LDB #11
*
*FOR EACH BYTE IN THE ENTRY
DSRCH3
 LDA ,Y+
 CMPA ,X+
 BNE DSRCH5
*IF 0 OR -1, MATCH ON 1 CHAR
 TSTA
 BEQ DSRCH4
 INCA
 BEQ DSRCH4
 DECB
 BNE DSRCH3
*FILE NAME MATCH !!
DSRCH4
 LDX FPTR
 LDB FBBEG,X
 STB FGRAN
 CLRB
 BRA DSRCH9
*FILE NAME MISMATCH, KEEP TRYING
DSRCH5
 LDB FINDX
 ADDB #32
 STB FINDX
 BNE DSRCH2
 INC ,S
 LDB ,S
 CMPB #11
 BLE DSRCH1
*NO HIT
 LDB #1
DSRCH9
 LEAS 1,S
DSRC10
 PULS A,X,Y,PC
*-------
*
*DISK FILE WRITE
*
*ENTRY X-BUFFER
*EXIT  B-STATUS (0-NORM, -1-ERROR)
*
DWRIT
 PSHS X,D
 LDA FGRAN
 LDB FSECT
 LSRA
 BCC DWEVEN
DWODD
 ADDB #9
DWEVEN
 CMPA #16
 BLE DWBELO
DWABOV
 INCA
DWBELO
 LDX 2,S
 LBSR DKWRIT
 PULS X,D,PC
*-------
*DISK FILE READ
*
*ENTRY X-BUFFER
*EXIT  B-STATUS (0-NORM, -1-ERROR)
*
DREAD
 PSHS X,D
 LDA FGRAN
 LDB FSECT
 LSRA
 BCC DREVEN
DRODD
 ADDB #9
DREVEN
 CMPA #16
 BLE DRBELO
DRABOV
 INCA
DRBELO
 LDX 2,S
 LBSR DKREAD
 PULS X,D,PC
*---------
*
*POSITION FORWARD IN DISK FILE
*
* EXIT  D-# VALID BYTES (0=EOF)
*       CC- Z=END OF FILE
DPOSFW
 PSHS X

DP0
 INC FSECT
 LDA FGRAN
 LDX #ALCBUF
 LDB A,X
 LDA A,X
 ANDA #$F0
 CMPA #$C0
 BEQ DP3

*NOT THE LAST GRANULE
 LDA FSECT
 CMPA #9
 BHI DP2
 LDD #256
 BRA DP9

*ADVANCE GRANULE
DP2
 STB FGRAN
 CLR FSECT
 BRA DP9

*LAST GRANULE
DP3
 ANDB #$F
 CMPB FSECT
 BEQ DP5
 BLO DP6

*NOT LAST SECTOR
 LDD #256
 BRA DP9

*LAST SECTOR
DP5
 LDX FPTR
 LDD FBLCNT,X
 BRA DP9

*PAST LAST SECTOR
DP6
 LDD #0

DP9
 TST FSECT
 BEQ DP0
 ADDD #0
 PULS X,PC
*-------
*
*CREATE A NEW FILE
* ENTRY X-FILENAME
* EXIT CC-NON ZERO=DISK FULL
*
CREFIL
 PSHS Y,X,D
*FIND FREE DIRECTORY ENTRY
 LEAX ZERO,PCR
 LBSR DSERCH
 BMI CRE9
 BEQ CRE1
 LEAX MINONE,PCR
 LBSR DSERCH
 BMI CRE9
 BEQ CRE1
 LEAX TXDRFL,PCR
 LBSR PERROR
 CLRB
 BRA CRE9

CRE1
 LBSR GTGRAN
 BEQ CRE9

 STB FGRAN
 CLR FSECT
 LDX #ALCBUF
 LDA #$C0
 STA B,X

 LDX FPTR
 STB FBBEG,X

* derive file type
 LDB BUF
 LBSR FTYPE

 CLR FBLCNT,X
 CLR FBLCNT+1,X
 LDY 2,S
 LDB #11
CRE2
 LDA ,Y+
 STA ,X+
 DECB
 BNE CRE2
 LDB #1  (SET CC NOT=Z)

CRE9
 PULS D,X,Y,PC
*
TXDRFL FCC "ERROR: DIRECTORY FULL"
 FCB 13,10
 FCB 0
ZERO   FCB 0
MINONE FCB $FF

* derive file type
* B: 1st byte of file data
*
FTYPE
 PSHS D,X,Y,U
 LDX FPTR
 CLRA
 TFR D,Y

*binary or ascii file extension?
 LDD FILBUF+8
 CMPD #$5458 ".TXT" extension
 BEQ CRASC
 CMPD #$4249 ".BIN" extension
 BEQ CRBIN
 CMPD #$4152 ".ARC" extension
 BEQ CRBIN

*binary or ascii file?
 TFR Y,D
 TSTB
 BEQ CRBIN
 CMPB #$FF
 BEQ CRBASI

*ASCII file
CRASC
 LDB #1
 STB FBTYP,X file type = 1
 LDB #$FF
 STB FBASC,X ascii flag = $FF
 BRA XCRBIN

*Compressed BASIC file
CRBASI
 CLRB
 STB FBTYP,X file type = 0
 STB FBASC,X ascii flag = 0
 BRA XCRBIN

*BINARY file
CRBIN
 LDB #2
 STB FBTYP,X file type = 2
 CLRB
 STB FBASC,X ascii flag = 0

XCRBIN
 PULS D,X,Y,U,PC

*-------
*GET FREE GRANULE
* EXIT B-FREE GRANULE
*      CC-ZERO=DISK FULL
*
GTGRAN
 PSHS X
 LDX #ALCBUF
 CLRB
GTG1
 LDA B,X
 CMPA #$FF
 BEQ GTG2
 INCB
 CMPB NGRANS
 BNE GTG1

*DISK FULL
 CLRB
 BRA GTG9

*GOT FREE GRANULE
GTG2
 LDA #1  (SET CC=NON ZERO)
GTG9
 PULS X,PC
*-------
*
*DISK READ ROUTINE
*
*ENTRY  X-BUFAD
*       A-TRACK
*       B-SECTOR
*EXIT   B-STATUS (0-NORM, -1-ERROR)
DKREAD
 STA TRACK
 STB SECTOR
 STX BUFAD
 LDB #2
 BSR DISK
 BSR ERRTST
 RTS
*-----
*
*DISK WRITE ROUTINE
*
*ENTRY  X-BUFAD
*       A-TRACK
*       B-SECTOR
*EXIT   B-STATUS (0-NORM, -1-ERROR)
DKWRIT
 STA TRACK
 STB SECTOR
 STX BUFAD
 LDB #3
 BSR DISK
 BSR ERRTST
 RTS
*--------
*
*CHECK FOR DISK ERROR AND REPORT
*
ERRTST
 LDB STATUS
 BEQ ERRDUN
 LEAX TXDER,PCR
 LBSR PERROR
 LDB #-1
ERRDUN
 RTS
*
*--------------------------------------
*
* LOW LEVEL DISK I/O ROUTINE
*  ENTRY  PARAMETER BLOCK SET UP
*
DISK    PSHS    U,Y,X,B,A
*
        STB     CMND

* default grans (35 tracks)
 LDA #68
 STA NGRANS

* ramdisk?
 LDA DRIVE
 CMPA #'A
 LBEQ RDISK
 CMPA #'B
 LBEQ RDISK

* figure out # grans
 LDA DRIVE
 ANDA #3
 LDX #NTRAKS
 LDB A,X
 DECB
 ASLB
 STB NGRANS

* Use disk ROM?
*TST ROMFLG
*BEQ DISK0

* Use disk ROM:
*ORCC #$50 turn off interrupts
*CLR $FFD8 slow CPU
*CLR $FFDE enable ROMs
*LDU $C006 xfer params
*LDX #CMND
*LDD ,X++ cmd and unit
*STD ,U++
*LDD ,X++ track and sector
*STD ,U++
*LDD ,X++ buf adr
*ANDA #$1F map into proper MMU segment
*ORA #$60
*STD ,U++
*LDA ,X   status
*STA ,U

* map in correct MMU segment
*LDB BUFAD buffer address
*LSLB
*ROLA
*LSLB
*ROLA
*LSLB
*ROLA
*ANDA #3 A is segment #
*STA $FFA3 put in MMU
*STA $FFAB both maps

*JSR [$C004] call ROM
*CLR $FFDF disable ROMs
*LBSR INIMMU reinit MMU map
*CLR $FFD9 fast CPU
*ANDCC #$AF turn on interrupts
*LBRA DISK9

* Use DTERM disk driver
DISK0
        LDA     #$05
        STA     RETRY
DISK1   LDB     DRIVE
        LEAX    DRVTAB,PCR
        LDA     DKCOM
        ANDA    #$A8
        ORA     B,X
        ORA     #$20
        LDB     TRACK
        CMPB    #$16
        BCS     DISK2
        ORA     #$10
DISK2   TFR     A,B
        ORA     #$08
        STA     DKCOM
        STA     $FF40
        BITB    #$08
        BNE     DISK3
        LBSR    DLAY1
        LBSR    DLAY1
DISK3   BSR     RDYCHK
        BNE     DISK4
        CLR     STATUS
        LEAX    OPTAB,PCR
        LDB     CMND
        LSLB    
        LEAX B,X
        LDD ,X
        JSR     D,X
DISK4   LDB     STATUS
        BEQ     DISK9

*ERROR IF RETRIES LEFT TRY AGAIN
        DEC     RETRY
        BEQ     DISK9
        BSR     DRSTOR
        BNE     DISK4
        BRA     DISK1

DISK9   PULS    A,B,X,Y,U,PC

OPTAB   FDB     DRSTOR-*,DNOP-*,DRD-*,DWT-*
DRVTAB  FCB     $01,$02,$04,$40
        FCB     $41,$42,$44,$01
*-----------------------------------
*
* RESTORE COMMAND
*
DRSTOR  LDX     #DKCOMS
        LDB     DRIVE
        ANDB    #3
        CLR     B,X
        LDB     DRIVE
*       LDA     #$03
 LDA RATE
 ANDA #3
        STA     $FF48
        EXG     A,A
        EXG     A,A
        BSR     RDYCHK
        BSR     DLAY2
        ANDA    #$10
        STA     STATUS
DNOP    RTS     
*-----------------------------------
*
*  WAIT FOR DRIVE TO BE READY
*
RDYCHK  LDX     #0
RDY1    LEAX    -1,X
        BEQ     RDY2
        LDA     $FF48
        BITA    #1
        BNE     RDY1
        BRA     RDY9

RDY2    BSR NOTRDY
RDY9    RTS     
*------------------------------------
*
*RETURN NOT READY STATUS
*
NOTRDY  LDA     #$D0
        STA     $FF48
        EXG     A,A
        EXG     A,A
        LDA     $FF48

*RETURN "NOT READY" STATUS
        LDA     #$80
        STA     STATUS
        RTS
*-------------------------------------
*
* DELAY ROUTINES
*
DLAY1   LDX     #0
        BRA     DLALUP
DLAY2   LDX     #$222E
DLALUP  LEAX    -1,X
        BNE     DLALUP
        RTS     
*------------------------------------
*
* DISK READ/WRITE
*


*
*READ ENTRY POINT
*
DRD     LDA     #$80
        BRA     DRDWT
*
*WRITE ENTRY POINT
*
DWT     LDA #$A0

*COMMON
DRDWT   PSHS    A
        LDX     #DKCOMS
        LDB     DRIVE
        ANDB    #3
        ABX     
        LDB     ,X
        STB     $FF49
        CMPB    TRACK
        BEQ     BD82C
        LDA     TRACK
        STA     $FF4B
        STA     ,X
*       LDA     #$17
 LDA RATE
 ANDA #3
 ORA #$14
        STA     $FF48
        EXG     A,A
        EXG     A,A
        BSR     RDYCHK
        BNE     BD82A
        BSR     DLAY2
        ANDA    #$18
        BEQ     BD82C
        STA     STATUS
BD82A   PULS    A
        BRA     DRW99

BD82C   LDA     SECTOR
        STA     $FF4A
        LDX     BUFAD
        LDA     $FF48
        LDA     DKCOM
        ORA     #$80
        PULS    B
        LDY     #0
        LDU     #$FF48
        COM     NMION
        ORCC    #$50
        STB     $FF48
        EXG     A,A
        EXG     A,A
        CMPB    #$80
        BEQ     BD875
        LDB     #$02
BD85B   BITB    ,U
        BNE     BD86B
        LEAY    -1,Y
        BNE     BD85B
BD863   CLR     NMION
*       ANDCC   #$AF   LEAVE EM OFF
        LBSR    NOTRDY
        BRA     DRW99

* sector write loop
BD86B   LDB     ,X+
        STB     $FF4B
        STA     $FF40
        BRA     BD86B

BD875   LDB     #$02
BD877   BITB    ,U
        BNE     BD881
        LEAY    -1,Y
        BNE     BD877
        BRA     BD863

* sector read loop
BD881   LDB     $FF4B
        STB     ,X+
        STA     $FF40
        BRA     BD881

NMIDUN
*       ANDCC   #$AF  LEAVE EM OFF
        LDA     $FF48
        ANDA    #$7C
        STA     STATUS
DRW99   RTS     
*------------------------------------
*
* NMI INTERUPT PROCESSOR
*
DONMI   LDA     NMION
        BEQ     NMIEND
        LEAX    NMIDUN,PCR
        STX     10,S
        CLR     NMION
NMIEND  RTI

* DIRECTORY 
DIR
 PSHS A,X,Y
 LBSR XMPRT
 FCB 13
 FCC "DISK DIRECTORY:"
 FCB 13
 FCB 13,0
* read file allocation table
 LDA #17
 LDB #2
 LDX #ALCBUF
 STA $FFD8  SLOW DOWN CPU
 ORCC #$50  INTERRUPTS OFF
 LBSR DKREAD
 BMI DIR10
 STA $FFD9  speed up
 ANDCC #$E0 interrupts on
 LBSR GFREE
 CMPB NGRANS
 LBEQ NFLS no files?
 LDB #3
 PSHS B
*
*FOR EACH SECTOR
DIR1
 LDA #17
 STD FDKADR
 LDX #DIRBUF
 STA $FFD8  SLOW DOWN CPU
 ORCC #$50  INTERRUPTS OFF
 LBSR DKREAD
 BMI DIR9
 STA $FFD9  speed up
 ANDCC #$E0 interrupts on
 CLR FINDX
*
*FOR EACH ENTRY IN THE SECTOR
DIR2
 LDX #DIRBUF
 LDB FINDX
 ABX B,X
 STX FPTR
*
*FOR EACH ENTRY
* x points to filename
 LBSR FNPUT
 LDA COL
 ADDA #11
 CMPA CMAX
 BLE DIR8A
 LBSR CRLF
DIR8A
 LDB FINDX
 ADDB #32
 STB FINDX
 BNE DIR2
 INC ,S
 LDB ,S
 CMPB #11
 BLE DIR1
DIR9
 LEAS 1,S
DIR10
 STA $FFD9 speed up CPU
 ANDCC #$E0 turn on interrupts
 LBSR CRLF
 LBSR CRLF
NFLS
 LBSR XMPRT
 FCC "Free grans: "
 FCB 0
 LBSR GFREE
 CLRA
 LBSR PRTNUM
 LBSR CRLF

* "Total grans:"
 LBSR XMPRT
 FCC "Total grans: "
 FCB 0
 CLRA
 LDB NGRANS
 LBSR PRTNUM
 LBSR CRLF

 LBSR MOTOFF
 PULS A,X,Y,PC

CRLF
 INC AUTOLF
 LDA #CR
 LBSR PUT
 DEC AUTOLF
 RTS

* Put out filename at X
FNPUT
 PSHS X
 TST ,X
 BLE XFNPUT

* put out filename
 LDA #8
 PSHS A
FNPL
 DEC ,S
 BLT XFNPL
 LDA ,X+
 CMPA #' 
 BEQ XFNPL
 LBSR PUT
 BRA FNPL

XFNPL
 PULS A
 STA TABPAD
 LDX ,S

*put out dot
 LDA #'.
 LBSR PUT

*put out extension
 LDA 8,X
 LBSR PUT
 LDA 9,X
 LBSR PUT
 LDA 10,X
 LBSR PUT

*put out blank padding at end
 LDA TABPAD
 ADDA #2
 PSHS A
FN2L
 DEC ,S
 BLT XFN2L
 LDA #' 
 LBSR PUT
 BRA FN2L
XFN2L
 PULS A

XFNPUT
 PULS X,PC

*------------------------------------
*TURN OFF MOTOR
*
MOTOFF
 CLR $FF40
 RTS

****** RAMDISK *****

* Format ramdisk
RDSKFM
* don't allow RAMdisks if 128K
 TST MEMSZ
 BEQ XRD
* do we have to format?
 LDA #'A
 STA DRIVE
 LDA #17
 STA TRACK
 LDA #18
 STA SECTOR
 LDX #BUF
 STX BUFAD
 LDB #2 read sector
 LBSR DISK
* check unique sector
 LEAX TITL80,PCR
 LDY #BUF
A@
 LDA ,X+
 BEQ XRD
 CMPA ,Y+
 BEQ A@

* format drive A
 LBSR T17

* Format drive B
 INC DRIVE
 LBSR T17

 LBSR XMPRT
 FCC "RAMdisks A and B formatted"
 FCB 13,0

XRD
 CLR DRIVE
 RTS

* write $FF's to track 17
* (effectively nuking the entire disk)
T17
* create sector full of $FF's
 LDX #ALCBUF
 STX BUFAD
 LDD #$00FF
A@
 STB ,X+
 DECA
 BNE A@
* write $FF's to FAT
 LDA #17
 STA TRACK
 LDA #2
 STA SECTOR
 LDB #3
 LBSR DISK
* clear directory entries
 LDA #2
 STA SECTOR
B@
 INC SECTOR
 LDX #DIRBUF
 STX BUFAD
 LDB #2 read sector
 LBSR DISK
 LDX #DIRBUF
 CLR ,X clear directory entries
 CLR 32,X
 CLR 64,X
 CLR 96,X
 CLR 128,X
 CLR 160,X
 CLR 192,X
 CLR 224,X
 LDB #3 write sector
 LBSR DISK
 LDA SECTOR
 CMPA #11
 BNE B@

* write copyright message in sector 18
 LDA DRIVE
 CMPA #'A don't do it for floppies
 BLO A@
 LDA #18
 STA SECTOR
 LEAX TITL80,PCR
 STX BUFAD
 LDB #3
 LBSR DISK
A@
 RTS

* low level ramdisk handler
RDISK
 LBSR TSX
 LDY BUFAD
 LDB CMND
* 0 restore
* 1 nop
* 2 read
* 3 write
 CMPB #2
 LBLO ERD
 BEQ RDSKRD
 CMPB #3
 BHI ERD

* Ram disk write sector
* from buffer to ramdisk
 CLRA
 PSHS A
A@
 LDA #$60 force map 0
 STA $FF91
 LDB ,Y+  from buffer
 INCA     force map 1
 STA $FF91
 STB ,X+  to ramdisk
 DEC ,S
 BNE A@
 PULS A
 BRA ERD

* Ram disk read sector
* from ramdisk to buffer
RDSKRD
 CLRA
 PSHS A
A@
 LDA #$61  force map 1
 STA $FF91
 LDB ,X+   from ramdisk
 DECA
 STA $FF91 force map 0
 STB ,Y+   to buffer
 DEC ,S
 BNE A@
 PULS A

* end ramdisk
ERD
 LDA #$30
 STA $FFAB restore map 1
 LBSR REMAP
 CLR STATUS
 PULS U,Y,X,B,A
 RTS

* Translate track/sector to X
*
TSX
 LDA TRACK
 LDB #18
 MUL
 PSHS D
 CLRA
 LDB SECTOR
 DECB
 ADDD ,S++
 PSHS B page
 LSRA
 RORB
 LSRA
 RORB
 LSRA
 RORB
 LSRA
 RORB
 LSRA
 RORB
* B now contains segment
 LDA DRIVE
 CMPA #'A
 BEQ A@
 ADDB #20 drive B
A@
 STB $FFAB
 PULS A page
 ANDA #$1F
 CLRB
 LDX #BUF
 LEAX D,X
 RTS

* derive free grans
* (read file allocation table first)
* exits with free grans in B
GFREE
 PSHS X
 LDX #ALCBUF
 CLRB
 LDA NGRANS
 INCA
 PSHS A
A@
 DEC ,S
 BEQ X@
 LDA ,X+
 CMPA #$FF
 BNE A@
 INCB
 BRA A@
X@
 PULS A
 PULS X,PC

* ERASE FILE
RMFILE
 STA $FFD8 slow down CPU
 ORCC #$50 turn off interrupts
 LDA ,X
 CMPA #'* wildcard?
 BNE  RM1

* remove all files
 LBSR T17 wipe out track 17
 LBRA RMC

* remove one file
RM1
 LBSR DSERCH get directory entry
* found file?
 BNE NRMF
* zero 1st byte in filename
 LDX FPTR
 CLR ,X
* release granules
 LDB FGRAN
A@
 LDX #ALCBUF
 LEAX B,X
 LDB ,X
 CLR ,X
 DEC ,X
 TSTB
 BGE A@
* rewrite directory entry
* rewrite file allocation table
RMC
 LBSR DWTFB
 BRA XRMF
NRMF
 LEAX TXNPTH,PCR
 LBSR PERROR
XRMF
 LBSR MOTOFF
 STA $FFD9 speed up CPU
 ANDCC #$E0 interrupts on
 RTS

