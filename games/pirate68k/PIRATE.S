* KAI ZOKU OU GAME / original 68000 fan-game implementation.
* HAS060 -> HLK + XSP2lib. Hardware sprites over indexed backgrounds.
* All mutable state is relative to a6; see STATE.INC for debugger offsets.
        .include STATE.INC
        .text
start:
        lea     state,a6
        move.l  #'P68K',(a6)
        move.l  #'STAT',4(a6)
        move.w  #-1,mode(a6)
        clr.l   -(sp)
        dc.w    $ff20
        addq.l  #4,sp
        move.l  d0,oldsp(a6)
        move.l  #'P68K',soundstate
        move.l  #'SND!',soundstate+4
        bsr     musicinit
        tst.l   d0
        bmi     soundstartupfailed
        moveq   #-1,d1
        moveq   #$10,d0
        trap    #15
        move.w  d0,oldmode(a6)
        moveq   #14,d1
        moveq   #$10,d0
        trap    #15
        moveq   #$1f,d0
        trap    #15
        move.w  #$90,d0
        trap    #15
        bsr     title
        moveq   #1,d0
        bsr     musicplay
        moveq   #$7f,d0
        trap    #15
        move.l  d0,lasttick(a6)
loop:
        moveq   #$7f,d0
        trap    #15
        move.l  d0,d1
        sub.l   lasttick(a6),d1
        cmp.l   #5,d1
        blo     loop
        move.l  d0,lasttick(a6)
        bsr     input
        btst    #7,keys+1(a6)
        bne     exit
        btst    #6,edges+1(a6)
        bne     newgame
        tst.w   mode(a6)
        beq     menu
        cmp.w   #1,mode(a6)
        bne     ending
        bsr     update
        bsr     render
        bsr     flip
        bra     loop
menu:
        btst    #4,edges+1(a6)
        bne     newgame
        bra     loop
ending:
        btst    #4,edges+1(a6)
        bne     newgame
        bra     loop
newgame:
        bsr     gameplayvideo
        move.w  #1,mode(a6)
        move.w  #1,stage(a6)
        clr.l   score(a6)
        clr.l   frame(a6)
        clr.w   shots(a6)
        clr.w   bombsused(a6)
        move.w  #3,life(a6)
        bsr     stageinit
        bra     loop
stageinit:
        move.w  #128,px(a6)
        move.w  #212,py(a6)
        move.w  #2,bombs(a6)
        clr.w   kills(a6)
        clr.w   wave(a6)
        clr.w   bosshp(a6)
        clr.w   flash(a6)
        clr.w   cooldown(a6)
        move.w  #40,invul(a6)
        move.w  #128,bossx(a6)
        move.w  #2,bossdx(a6)
        lea     enemies(a6),a0
        move.w  #95,d0
clearentities:
        clr.w   (a0)+
        dbra    d0,clearentities
        bsr     background
        moveq   #1,d0
        add.w   stage(a6),d0
        bsr     musicplay
        rts

* _BITSNS senses held keys, unlike buffered DOS input. Keyboard + JOYGET OR.
input:
        move.w  keys(a6),previous(a6)
        clr.w   keys(a6)
        moveq   #7,d1
        moveq   #4,d0
        trap    #15
        btst    #3,d0
        beq     noleft
        bset    #2,keys+1(a6)
noleft:
        btst    #4,d0
        beq     noup
        bset    #0,keys+1(a6)
noup:
        btst    #5,d0
        beq     noright
        bset    #3,keys+1(a6)
noright:
        btst    #6,d0
        beq     nodown
        bset    #1,keys+1(a6)
nodown:
        moveq   #5,d1
        moveq   #4,d0
        trap    #15
        btst    #2,d0
        beq     noz
        bset    #4,keys+1(a6)
noz:
        btst    #3,d0
        beq     nox
        bset    #5,keys+1(a6)
nox:
        moveq   #2,d1
        moveq   #4,d0
        trap    #15
        btst    #4,d0
        beq     nor
        bset    #6,keys+1(a6)
nor:
        moveq   #0,d1
        moveq   #4,d0
        trap    #15
        btst    #1,d0
        beq     noesc
        bset    #7,keys+1(a6)
noesc:
        moveq   #0,d1
        moveq   #$3b,d0
        trap    #15
        not.b   d0
        and.w   #$6f,d0
        move.w  d0,d1
        and.w   #15,d0
        or.w    d0,keys(a6)
        btst    #5,d1
        beq     joy2
        bset    #4,keys+1(a6)
joy2:
        btst    #6,d1
        beq     inputdone
        bset    #5,keys+1(a6)
inputdone:
        move.w  previous(a6),d0
        not.w   d0
        and.w   keys(a6),d0
        move.w  d0,edges(a6)
        bsr     flushkeys
        rts
update:
        addq.l  #1,frame(a6)
        tst.w   invul(a6)
        beq     noinvul
        subq.w  #1,invul(a6)
noinvul:
        tst.w   flash(a6)
        beq     noflash
        subq.w  #1,flash(a6)
noflash:
        move.w  keys(a6),d0
        btst    #0,d0
        beq     movedown
        cmp.w   #48,py(a6)
        ble     movedown
        subq.w  #3,py(a6)
movedown:
        btst    #1,d0
        beq     moveleft
        cmp.w   #222,py(a6)
        bge     moveleft
        addq.w  #3,py(a6)
moveleft:
        btst    #2,d0
        beq     moveright
        cmp.w   #40,px(a6)
        ble     moveright
        subq.w  #3,px(a6)
moveright:
        btst    #3,d0
        beq     fire
        cmp.w   #214,px(a6)
        bge     fire
        addq.w  #3,px(a6)
fire:
        tst.w   cooldown(a6)
        beq     canfire
        subq.w  #1,cooldown(a6)
        bra     bomb
canfire:
        btst    #4,keys+1(a6)
        beq     bomb
        lea     bullets(a6),a0
        moveq   #7,d7
findshot:
        tst.w   (a0)
        beq     addshot
        addq.l  #8,a0
        dbra    d7,findshot
        bra     bomb
addshot:
        move.w  #1,(a0)
        move.w  px(a6),2(a0)
        move.w  py(a6),4(a0)
        sub.w   #18,4(a0)
        move.w  #4,cooldown(a6)
        addq.w  #1,shots(a6)
        moveq   #0,d0
        bsr     soundfm
bomb:
        btst    #5,edges+1(a6)
        beq     spawn
        tst.w   bombs(a6)
        beq     spawn
        subq.w  #1,bombs(a6)
        addq.w  #1,bombsused(a6)
        move.w  #20,flash(a6)
        move.w  #24,invul(a6)
        moveq   #3,d0
        bsr     soundfm
        moveq   #PCM_BOMB,d0
        bsr     soundpcm
        lea     enemies(a6),a0
        moveq   #7,d7
bombenemies:
        tst.w   (a0)
        beq     bombnext
        clr.w   (a0)
        addq.w  #1,kills(a6)
        add.l   #100,score(a6)
bombnext:
        addq.l  #8,a0
        dbra    d7,bombenemies
        lea     hostile(a6),a0
        moveq   #7,d7
bombbullets:
        clr.w   (a0)
        addq.l  #8,a0
        dbra    d7,bombbullets
        tst.w   bosshp(a6)
        beq     spawn
        subq.w  #8,bosshp(a6)
        bgt     spawn
        bsr     bossdead
        rts
spawn:
        tst.w   bosshp(a6)
        bne     bossmove
        cmp.w   #6,kills(a6)
        blt     spawnnormal
        move.w  #16,bosshp(a6)
        cmp.w   #1,stage(a6)
        beq     bossmove
        move.w  #24,bosshp(a6)
        bra     bossmove
spawnnormal:
        move.l  frame(a6),d0
        divu    #30,d0
        swap    d0
        tst.w   d0
        bne     moveenemies
        lea     enemies(a6),a0
        moveq   #7,d7
findenemy:
        tst.w   (a0)
        beq     addenemy
        addq.l  #8,a0
        dbra    d7,findenemy
        bra     moveenemies
addenemy:
        move.w  #1,(a0)
        move.w  wave(a6),d0
        mulu    #37,d0
        divu    #160,d0
        swap    d0
        add.w   #48,d0
        move.w  d0,2(a0)
        move.w  #40,4(a0)
        addq.w  #1,wave(a6)
        bra     moveenemies
bossmove:
        move.w  bossdx(a6),d0
        add.w   d0,bossx(a6)
        cmp.w   #80,bossx(a6)
        ble     bossbounce
        cmp.w   #176,bossx(a6)
        blt     bossfire
bossbounce:
        neg.w   bossdx(a6)
bossfire:
        move.l  frame(a6),d0
        and.w   #15,d0
        bne     moveenemies
        move.w  bossx(a6),d1
        move.w  #124,d2
        bsr     enemyfire
        sub.w   #24,d1
        bsr     enemyfire
        add.w   #48,d1
        bsr     enemyfire
moveenemies:
* Boss body and player core are separate from the decorative weapon pixels.
        tst.w   bosshp(a6)
        beq     nobosscontact
        cmp.w   #128,py(a6)
        bge     nobosscontact
        move.w  px(a6),d0
        sub.w   bossx(a6),d0
        add.w   #46,d0
        cmp.w   #92,d0
        bhi     nobosscontact
        bsr     hurt
nobosscontact:
        lea     enemies(a6),a3
        moveq   #7,d6
moveloop:
        tst.w   (a3)
        beq     movenext
        addq.w  #1,4(a3)
        cmp.w   #246,4(a3)
        blt     enemyattack
        clr.w   (a3)
        bsr     hurt
        bra     movenext
enemyattack:
        move.l  frame(a6),d0
        and.w   #63,d0
        bne     enemycontact
        move.w  2(a3),d1
        move.w  4(a3),d2
        add.w   #18,d2
        bsr     enemyfire
enemycontact:
        move.w  2(a3),d1
        move.w  4(a3),d2
        bsr     nearplayer
        tst.w   d0
        beq     movenext
        clr.w   (a3)
        bsr     hurt
movenext:
        cmp.w   #1,mode(a6)
        bne     updatedone
        addq.l  #8,a3
        dbra    d6,moveloop
        bsr     updateshots
        cmp.w   #1,mode(a6)
        bne     updatedone
        bsr     updatehostile
updatedone:
        rts
enemyfire:
        lea     hostile(a6),a0
        moveq   #7,d7
findhostile:
        tst.w   (a0)
        beq     addhostile
        addq.l  #8,a0
        dbra    d7,findhostile
        rts
addhostile:
        move.w  #1,(a0)
        move.w  d1,2(a0)
        move.w  d2,4(a0)
        rts
nearplayer:
        move.w  d1,d0
        sub.w   px(a6),d0
        bpl     nearx
        neg.w   d0
nearx:
        cmp.w   #11,d0
        bgt     farplayer
        move.w  d2,d0
        sub.w   py(a6),d0
        bpl     neary
        neg.w   d0
neary:
        cmp.w   #12,d0
        bgt     farplayer
        moveq   #1,d0
        rts
farplayer:
        moveq   #0,d0
        rts
hurt:
        tst.w   invul(a6)
        bne     hurtdone
        move.w  #40,invul(a6)
        moveq   #2,d0
        bsr     soundfm
        subq.w  #1,life(a6)
        bgt     hurtdone
        move.w  #2,mode(a6)
        moveq   #5,d0
        bsr     musicplay
hurtdone:
        rts
updateshots:
        lea     bullets(a6),a3
        moveq   #7,d6
shotloop:
        tst.w   (a3)
        beq     shotnext
        subq.w  #6,4(a3)
        cmp.w   #20,4(a3)
        blt     removeshot
        tst.w   bosshp(a6)
        beq     shotenemies
        cmp.w   #118,4(a3)
        bgt     shotenemies
        move.w  2(a3),d0
        sub.w   bossx(a6),d0
        add.w   #36,d0
        cmp.w   #72,d0
        bhi     shotenemies
        clr.w   (a3)
        subq.w  #1,bosshp(a6)
        moveq   #1,d0
        bsr     soundfm
        tst.w   bosshp(a6)
        bne     shotnext
        bsr     bossdead
        rts
shotenemies:
        lea     enemies(a6),a4
        moveq   #7,d5
shothit:
        tst.w   (a4)
        beq     hitnext
        move.w  2(a3),d0
        sub.w   2(a4),d0
        bpl     hitx
        neg.w   d0
hitx:
        cmp.w   #14,d0
        bgt     hitnext
        move.w  4(a3),d0
        sub.w   4(a4),d0
        bpl     hity
        neg.w   d0
hity:
        cmp.w   #14,d0
        bgt     hitnext
        clr.w   (a4)
        addq.w  #1,kills(a6)
        add.l   #100,score(a6)
        moveq   #1,d0
        bsr     soundfm
        bra     removeshot
hitnext:
        addq.l  #8,a4
        dbra    d5,shothit
        bra     shotnext
removeshot:
        clr.w   (a3)
shotnext:
        addq.l  #8,a3
        dbra    d6,shotloop
        rts
updatehostile:
        lea     hostile(a6),a3
        moveq   #7,d6
hostileloop:
        tst.w   (a3)
        beq     hostilenext
        addq.w  #3,4(a3)
        cmp.w   #246,4(a3)
        bgt     removehostile
        move.w  2(a3),d1
        move.w  4(a3),d2
        bsr     nearplayer
        tst.w   d0
        beq     hostilenext
        bsr     hurt
removehostile:
        clr.w   (a3)
hostilenext:
        addq.l  #8,a3
        dbra    d6,hostileloop
        rts
bossdead:
        moveq   #PCM_BOSS,d0
        bsr     soundpcm
        clr.w   bosshp(a6)
        add.l   #1000,score(a6)
        cmp.w   #2,stage(a6)
        beq     allclear
        addq.w  #1,stage(a6)
        bsr     stageinit
        rts
allclear:
        move.w  #3,mode(a6)
        moveq   #4,d0
        bsr     musicplay
        rts

        .include VIDEO.INC
number:
        movem.l d0-d7/a1,-(sp)
        move.l  d0,d6
        lea     powers,a1
        moveq   #4,d7
numloop:
        move.l  d6,d0
        divu    (a1)+,d0
        move.l  d0,d6
        swap    d6
        and.l   #$ffff,d6
        and.l   #$ffff,d0
        bsr     digit
        addq.w  #6,d1
        dbra    d7,numloop
        movem.l (sp)+,d0-d7/a1
        rts

digit:
        movem.l d0-d7/a1,-(sp)
        lea     singledigit,a1
        add.b   #'0',d0
        move.b  d0,(a1)
        bsr     text
        movem.l (sp)+,d0-d7/a1
        rts
* Compact, original 5x7 font. text preserves coordinate and caller registers.
text:
        movem.l d0-d7/a0-a2,-(sp)
textchar:
        moveq   #0,d0
        move.b  (a1)+,d0
        beq     textdone
        sub.w   #32,d0
        mulu    #7,d0
        lea     font,a2
        adda.l  d0,a2
        move.w  d1,d6
        move.w  d2,d7
        moveq   #6,d5
fontrow:
        moveq   #0,d0
        move.b  (a2)+,d0
        moveq   #4,d3
fontcol:
        btst    d3,d0
        beq     fontskip
        movem.l d0-d7,-(sp)
        move.w  #8,d0
        moveq   #1,d3
        moveq   #1,d4
        bsr     rect
        movem.l (sp)+,d0-d7
fontskip:
        addq.w  #1,d1
        dbra    d3,fontcol
        move.w  d6,d1
        addq.w  #1,d2
        dbra    d5,fontrow
        move.w  d7,d2
        addq.w  #6,d1
        bra     textchar
textdone:
        movem.l (sp)+,d0-d7/a0-a2
        rts
title:
        lea     $c00000,a5
        lea     titledata,a1
        movea.l a5,a0
        move.w  #255,d1
titlerow:
        moveq   #127,d2
titlecol:
        move.l  (a1)+,(a0)+
        dbra    d2,titlecol
        adda.w  #512,a0
        dbra    d1,titlerow
        clr.w   mode(a6)
        rts
flushkeys:
        moveq   #1,d0
        trap    #15
        tst.l   d0
        beq     flushed
        moveq   #0,d0
        trap    #15
        bra     flushkeys
flushed:
        rts
soundstartupfailed:
        move.l  oldsp(a6),-(sp)
        dc.w    $ff20
        addq.l  #4,sp
        move.w  #1,-(sp)
        dc.w    $ff4c
exit:
        bsr     graphicsstop
        bsr     musicstop
        bsr     flushkeys
        move.w  oldmode(a6),d1
        moveq   #$10,d0
        trap    #15
        moveq   #$1e,d0
        trap    #15
        move.l  oldsp(a6),-(sp)
        dc.w    $ff20
        addq.l  #4,sp
        dc.w    $ff00
        .include SOUND.INC
        .data
scoremsg: dc.b 'SCORE',0
lifemsg: dc.b 'LIFE',0
bombmsg: dc.b 'BOMB',0
stagemsg: dc.b 'STAGE',0
bigmsg: dc.b 'BIG MOM',0
kaidomsg: dc.b 'KAIDO',0
overmsg: dc.b 'GAME OVER',0
clearmsg: dc.b 'ALL CLEAR',0
restartmsg: dc.b 'Z:RETRY ESC:EXIT',0
zoromsg: dc.b 'ZORO SLASH!',0
sanjimsg: dc.b 'SANJI KICK!',0
singledigit: dc.b '0',0
        .even
powers: dc.w 10000,1000,100,10,1
        .include ART.INC
        .even
        .include GRAPHICS.INC
        .even
spdata: .insert SPRITES.SP
sppal:  .insert SPRITES.PAL
bg1:    .insert BG1.BIN
bg1pal: .insert BG1.PAL
bg2:    .insert BG2.BIN
bg2pal: .insert BG2.PAL
        .even
titledata:
        .insert TITLE.RAW
        .bss
        .even
state:  ds.b 272
spalt:  ds.b SP_COUNT+1
        .even
sparg:  ds.w 4
hudscore: ds.l 1
hudkillslife: ds.l 1
hudbombs: ds.w 1
hudmodestage: ds.l 1
hudhp: ds.w 1
        .end start
