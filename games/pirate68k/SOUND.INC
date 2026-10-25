* Z-MUSIC v2: MaidLand-style TRAP #3, external replaceable ZMD/SE/ZPD.
* BGM uses FM1..7; one-track FM effects interrupt FM8. PCM is monophonic.
        .include AUDIO.INC
MUSIC_MAX equ 32768
SE_MAX equ 1024
musicinit:
        movem.l d1-d7/a0-a5,-(sp)
        movea.l $8c.w,a0
        cmpa.l  #8,a0
        blo     nodriver
        subq.l  #8,a0
        cmp.l   #'ZmuS',(a0)+
        bne     nodriver
        cmp.w   #'iC',(a0)+
        bne     nodriver
        cmp.w   #$3000,(a0)
        bhs     nodriver
        move.w  (a0),soundversion
        lea     soundfiles,a4
        lea     soundbuffers,a5
        moveq   #9,d7
soundload:
        movea.l (a4)+,a0
        move.l  a0,soundpath
        move.w  #0,-(sp)
        move.l  a0,-(sp)
        dc.w    $ff3d
        addq.l  #6,sp
        tst.l   d0
        bmi     soundloadfail
        move.w  d0,d6
        move.l  #MUSIC_MAX,d5
        cmp.w   #4,d7
        bhs     soundread
        move.l  #SE_MAX,d5
soundread:
        move.l  d5,d0
        addq.l  #1,d0
        move.l  d0,-(sp)
        move.l  (a5),-(sp)
        move.w  d6,-(sp)
        dc.w    $ff3f
        lea     10(sp),sp
        move.l  d0,d4
        move.w  d6,-(sp)
        dc.w    $ff3e
        addq.l  #2,sp
        cmp.l   #8,d4
        blt     soundloadfail
        cmp.l   d5,d4
        bgt     soundloadfail
        movea.l (a5)+,a0
        cmp.w   #4,d7
        blo     soundsecheck
        lea     zmdsignature,a1
        moveq   #6,d1
soundheader:
        cmpm.b  (a0)+,(a1)+
        bne     soundloadfail
        dbra    d1,soundheader
        bra     soundloaded
soundsecheck:
        cmp.w   #1,(a0)
        bne     soundloadfail
soundloaded:
        dbra    d7,soundload
        move.w  #1,soundready
        moveq   #0,d0
        bsr     musicplay
        moveq   #0,d0
        movem.l (sp)+,d1-d7/a0-a5
        rts
nodriver:
        lea     drivererror,a0
        bra     soundfailure
soundloadfail:
        lea     fileerror,a0
soundfailure:
        move.l  a0,-(sp)
        dc.w    $ff09
        addq.l  #4,sp
        move.l  soundpath,d0
        beq     soundfailed
        move.l  d0,-(sp)
        dc.w    $ff09
        addq.l  #4,sp
        pea     soundnewline
        dc.w    $ff09
        addq.l  #4,sp
soundfailed:
        moveq   #-1,d0
        movem.l (sp)+,d1-d7/a0-a5
        rts
* d0=0 tone initializer,1 title,2 stage1,3 stage2,4 clear,5 game over.
musicplay:
        movem.l d0-d4/a0-a1,-(sp)
        tst.w   soundready
        beq     musicdone
        move.w  d0,soundbgm
        bsr     musicstop
        lsl.w   #2,d0
        lea     soundbuffers,a0
        movea.l (a0,d0.w),a1
        addq.l  #7,a1
        moveq   #0,d2
        moveq   #$11,d1
        trap    #3
        bsr     soundresult
        addq.w  #1,soundbgmcalls
musicdone:
        movem.l (sp)+,d0-d4/a0-a1
        rts
musicstop:
        movem.l d0-d4/a0,-(sp)
        tst.w   soundready
        beq     musicstopped
        moveq   #-1,d2
        moveq   #-1,d3
        move.l  #$ffff,d4
        moveq   #$0a,d1
        trap    #3
musicstopped:
        movem.l (sp)+,d0-d4/a0
        rts
* d0=0 shot,1 hit,2 player hurt,3 bomb; raw SE starts at track count.
soundfm:
        movem.l d0-d3/a0-a1,-(sp)
        tst.w   soundready
        beq     soundfmdone
        move.w  d0,soundlastfm
        lsl.w   #2,d0
        lea     soundbuffers+24,a0
        movea.l (a0,d0.w),a1
        moveq   #8,d2
        moveq   #$12,d1
        trap    #3
* se_play has no return-value contract; only BGM calls return error codes.
        addq.w  #1,soundfmcalls
soundfmdone:
        movem.l (sp)+,d0-d3/a0-a1
        rts
* d0=registered ZPD note number, same mode as MaidLand se_play.
soundpcm:
        movem.l d0-d3/a0-a1,-(sp)
        tst.w   soundready
        beq     soundpcmdone
        move.w  d0,soundlastpcm
        move.l  d0,d2
        move.l  #PCM_MODE,d3
        moveq   #$14,d1
        trap    #3
        addq.w  #1,soundpcmcalls
soundpcmdone:
        movem.l (sp)+,d0-d3/a0-a1
        rts
soundresult:
        move.l  d0,soundlastresult
        tst.l   d0
        beq     soundresultdone
        addq.w  #1,sounderrors
soundresultdone:
        rts
        .data
        .even
soundfiles:
        dc.l tonefile,titlefile,stage1file,stage2file,clearfile,overfile
        dc.l shotfile,hitfile,hurtfile,bombfile
soundbuffers:
        dc.l tonebuf,titlebuf,stage1buf,stage2buf,clearbuf,overbuf
        dc.l shotbuf,hitbuf,hurtbuf,bombbuf
tonefile: dc.b 'AUDIO\TONE.ZMD',0
titlefile: dc.b 'AUDIO\TITLE.ZMD',0
stage1file: dc.b 'AUDIO\STAGE1.ZMD',0
stage2file: dc.b 'AUDIO\STAGE2.ZMD',0
clearfile: dc.b 'AUDIO\CLEAR.ZMD',0
overfile: dc.b 'AUDIO\OVER.ZMD',0
shotfile: dc.b 'AUDIO\SHOT.SE',0
hitfile: dc.b 'AUDIO\HIT.SE',0
hurtfile: dc.b 'AUDIO\HURT.SE',0
bombfile: dc.b 'AUDIO\BOMB.SE',0
drivererror: dc.b 'Z-MUSIC v2 required. Start with GO.BAT.',13,10,0
fileerror: dc.b 'Cannot load AUDIO file (missing, invalid or too large): ',0
soundnewline: dc.b 13,10,0
zmdsignature: dc.b $10,'ZmuSiC'
        .bss
        .even
soundstate: ds.b 8
soundready: ds.w 1
soundversion: ds.w 1
soundbgm: ds.w 1
soundbgmcalls: ds.w 1
soundfmcalls: ds.w 1
soundpcmcalls: ds.w 1
soundlastfm: ds.w 1
soundlastpcm: ds.w 1
sounderrors: ds.w 1
soundlastresult: ds.l 1
soundpath: ds.l 1
tonebuf: ds.b MUSIC_MAX+2
titlebuf: ds.b MUSIC_MAX+2
stage1buf: ds.b MUSIC_MAX+2
stage2buf: ds.b MUSIC_MAX+2
clearbuf: ds.b MUSIC_MAX+2
overbuf: ds.b MUSIC_MAX+2
shotbuf: ds.b SE_MAX+2
hitbuf: ds.b SE_MAX+2
hurtbuf: ds.b SE_MAX+2
bombbuf: ds.b SE_MAX+2
        .text
