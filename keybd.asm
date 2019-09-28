SCAN
 PSHS A,B,X

* START of button stuff
 LDA #$FF
 STA $FF02
*NOP        to cut down on video ripple
 LDA $FF00
 ORA #$F0
 CMPA #$FF
 BEQ SCAN1

* joystick button pushed
 LDB BUTTON
 BEQ EVENT
* pushed last time?
 CMPB #$FF
 LBNE SCAN99  yes
 STA BUTTON

* button event
* which one?
EVENT
 CMPA #$FE left button 1
 BNE A@
 LDB #'1
A@
 CMPA #$FD right button 1
 BNE B@
 LDB #'2
B@
 CMPA #$FB left button 2
 BNE C@
 LDB #'3
C@
 CMPA #$F7 right button 2
 BNE D@
 LDB #'4
D@
 LDX #LINE
 STB 6,X
 LDB #$0D
 STB 7,X
 LEAU BUTTXT,PCR
 LDD ,U++
 STD ,X++
 LDD ,U++
 STD ,X++
 LDD ,U++
 STD ,X++
 LDX #LINE
 INC SCRIPT
 LBSR XMTSEQ
 CLR SCRIPT
 LBRA SCAN99

BUTTXT
 FCC "BUTTON"
 
SCAN1
 STA BUTTON
* END of button stuff

* check if any key pressed
 CLR $FF02
 LDA $FF00
 ANDA #$7F
 CMPA #$7F
*LBEQ Z@
*  for column = 0 to 7
 CLR KCOL
A@
 LDA KCOL
 CMPA #8
 LBEQ Y@
*      get rollover table row
 LEAU KRT,PCR
 LDB KCOL
 LDA B,U
 STA RTCOL
*    get masks[col]
 LEAU MASKS,PCR
 LDB KCOL
 LDA B,U
*    invert
 COMA
*    put in $FF02
 STA $FF02
*    get out row data
 LDA $FF00
 STA RDATA
*    any keys for this row?
 ANDA #$7F
 CMPA #$7F
 BEQ X@
*    for row = 0 to 6
 CLR KROW
B@
 LDA KROW
 CMPA #7
 BEQ X@
*      get masks[row]
 LEAU MASKS,PCR
 LDB KROW
 LDA B,U
*      mask with row data
 TFR A,B
 ANDA RDATA
*      (now A will be zero if key
*      pressed, nonzero if not pressed)
*      pressed now?
 BNE C@
*      pressed now.  pressed last time?
*      compare to rollover table
 ANDB RTCOL
 BEQ C@
*      not pressed last time
*      get character from lookup table
 LEAX KEYTAB,PCR
 LDB KROW
 ASLB
 ASLB
 ASLB
 ORB KCOL
 CLRA
 LEAX D,X
 LDA ,X
* ignore SHIFT ALT CTRL
 CMPA #$FF
 BEQ C@
* do SHIFT chars
 LDB #55
 LBSR KEYTST
 BNE Q@
 LEAX 56,X
 BRA S@
* do CTRL chars
Q@
 LDB #52
 LBSR KEYTST
 BNE R@
 LEAX 56,X
 LEAX 56,X
 BRA S@
* do ALT chars
R@
 LDB #51
 LBSR KEYTST
 BNE S@
 LEAX 56,X
 LEAX 56,X
 LEAX 56,X
* check shift lock
S@
 LDA ,X
 CMPA #-2
 BNE K@
 LDA SHLOK
 INCA
 ANDA #1
 STA SHLOK
 BRA C@
* put character in kb buf
K@
 LDA ,X
 LDB KBPUT
 LDX #KEYBUF
 ABX
 LBSR SHLOCK
 STA ,X
 INCB
 STB KBPUT
C@
*    next row
 INC KROW
 BRA B@
X@
*    store row in rollover table
 LEAU KRT,PCR
 LDB KCOL
 LDA RDATA
 STA B,U
*  next column
 INC KCOL
 LBRA A@
*endif
Y@
Z@
SCAN99
 PULS A,B,X
 RTS

MASKS
 FCB $01,$02,$04,$08
 FCB $10,$20,$40,$80

* perform shift lock
SHLOCK
 TST SHLOK
 BEQ Z@
 CMPA #'a
 BLO Z@
 CMPA #'z
 BHI Z@
 ADDA #'A-'a
Z@
 RTS

KEYTAB FCC "@abcdefghijklmnopqrstuvwxyz"
 FCB $C,$A,$8,$9  (UP DWN LFT RIT)      
 FCC " 0123456789:;,-./"
 FCB $D    (ENTER)
 FCB $E2   (CLEAR)
 FCB $1B   (BREAK)
 FCB -1,-1 (ALT, CTRL)
 FCB $E0,$E1 (F1, F2)
 FCB -1 (SHIFT)

*AS ABOVE BUT SHIFTED
 FCC "@"
 FCC "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
 FCB $1C,$19,$18,$19 (UP DWN LFT RIT)
 FCC " "
 FCB -2
 FCC /!"#$%&'()*+<=>?/
 FCB $D    (ENTER)
 FCB $E3   (CLEAR)
 FCB $7F   (BREAK)
 FCB -1,-1 (ALT, CTRL)
 FCB -1,-1 (F1, F2)
 FCB -1 (SHIFT)

*AS ABOVE BUT CTRL
 FCB $00,$01,$02,$03,$04,$05,$06,$07
 FCB $08,$09,$0A,$0B,$0C,$0D,$0E,$0F
 FCB $10,$11,$12,$13,$14,$15,$16,$17
 FCB $18,$19,$1A
 FCB $C,$A,$8,$9  (UP DWN LFT RIT)      
*     sp  0   1   2
 FCB $20,-1,$7C,$60
*           3   4  5  6  7
 FCB $7E,-1,-1,-1,$5E

*     8   9
 FCB $5B,$5D,-1,-1,$7B,$5F,$7D,$5C
 FCB $D    (ENTER)
 FCB 0     (CLEAR)
 FCB $1B   (BREAK)
 FCB -1,-1 (ALT, CTRL)
 FCB -1,-1 (F1, F2)
 FCB -1 (SHIFT)

*AS ABOVE BUT ALT
 FCB $C0,$C1,$C2,$C3,$C4,$C5,$C6,$C7
 FCB $C8,$C9,$CA,$CB,$CC,$CD,$CE,$CF
 FCB $D0,$D1,$D2,$D3,$D4,$D5,$D6,$D7
 FCB $D8,$D9,$DA
 FCB -1,-1,-1,-1 (UP DWN LFT RIT)
 FCB -1,$B0,$B1,$B2,$B3,$B4,$B5,$B6,$B7

 FCB $B8,$B9,-1,-1,-1,-1,-1,-1
 FCB $DB   (ENTER)
 FCB -1    (CLEAR)
 FCB $DA   (BREAK) same as ALT-Z
 FCB -1,-1 (ALT, CTRL)
 FCB $E4,$E5 (F1, F2)
 FCB -1 (SHIFT)

KEYTST
 PSHS D,X
 LEAX MASKS,PCR
 TFR B,A
 LSRB
 LSRB
 LSRB
 ANDA #7
 LDA A,X
 COMA
 STA $FF02
 LDA $FF00
 ANDA B,X
 PULS X,D
 RTS

