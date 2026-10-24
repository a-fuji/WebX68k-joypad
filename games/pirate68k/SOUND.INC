* Original 16-note FM motif. IOCS _OPMSET, channel 7, one sine carrier.
* No timer/vector hooks and no resident music driver are installed.
musicinit:
        movem.l d0-d7/a0,-(sp)
        lea     voice,a0
        moveq   #24,d7
voicewrite:
        moveq   #0,d1
        moveq   #0,d2
        move.b  (a0)+,d1
        move.b  (a0)+,d2
        moveq   #$68,d0
        trap    #15
        dbra    d7,voicewrite
        clr.w   musicstep(a6)
        movem.l (sp)+,d0-d7/a0
        rts
musicupdate:
        movem.l d0-d7/a0,-(sp)
        move.l  frame(a6),d0
        and.w   #7,d0
        cmp.w   #6,d0
        beq     musicoff
        tst.w   d0
        bne     musicdone
        move.w  musicstep(a6),d3
        and.w   #15,d3
        lea     melody,a0
        moveq   #0,d2
        move.b  (a0,d3.w),d2
        moveq   #$2f,d1
        moveq   #$68,d0
        trap    #15
        moveq   #8,d1
        moveq   #15,d2
        moveq   #$68,d0
        trap    #15
        addq.w  #1,musicstep(a6)
        bra     musicdone
musicoff:
        moveq   #8,d1
        moveq   #7,d2
        moveq   #$68,d0
        trap    #15
musicdone:
        movem.l (sp)+,d0-d7/a0
        rts
musicstop:
        movem.l d0-d2,-(sp)
        moveq   #8,d1
        moveq   #7,d2
        moveq   #$68,d0
        trap    #15
        movem.l (sp)+,d0-d2
        rts
voice:
        dc.b $27,$c7,$47,$01,$4f,$01,$57,$01,$5f,$01
        dc.b $67,$25,$6f,$7f,$77,$7f,$7f,$7f
        dc.b $87,$1f,$8f,$1f,$97,$1f,$9f,$1f
        dc.b $a7,$00,$af,$00,$b7,$00,$bf,$00
        dc.b $c7,$00,$cf,$00,$d7,$00,$df,$00,$e7,$0f
        dc.b $ef,$0f,$f7,$0f,$ff,$0f
melody:
        dc.b $40,$44,$47,$49,$47,$44,$42,$40
        dc.b $45,$49,$4c,$50,$4c,$49,$47,$44
        .even
