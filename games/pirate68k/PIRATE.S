* KAI ZOKU OU GAME / original 68000 fan-game implementation.
* HAS060 -> HLK. IOCS only, no external game library.
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
        bsr     musicinit
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
        move.w  #220,py(a6)
        move.w  #2,bombs(a6)
        clr.w   kills(a6)
        clr.w   wave(a6)
        clr.w   bosshp(a6)
        clr.w   flash(a6)
        clr.w   cooldown(a6)
        move.w  #40,invul(a6)
        move.w  #100,bossx(a6)
        move.w  #2,bossdx(a6)
        lea     enemies(a6),a0
        move.w  #95,d0
clearentities:
        clr.w   (a0)+
        dbra    d0,clearentities
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
        bsr     musicupdate
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
        cmp.w   #32,py(a6)
        ble     movedown
        subq.w  #3,py(a6)
movedown:
        btst    #1,d0
        beq     moveleft
        cmp.w   #238,py(a6)
        bge     moveleft
        addq.w  #3,py(a6)
moveleft:
        btst    #2,d0
        beq     moveright
        cmp.w   #12,px(a6)
        ble     moveright
        subq.w  #3,px(a6)
moveright:
        btst    #3,d0
        beq     fire
        cmp.w   #242,px(a6)
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
        sub.w   #10,4(a0)
        move.w  #4,cooldown(a6)
        addq.w  #1,shots(a6)
bomb:
        btst    #5,edges+1(a6)
        beq     spawn
        tst.w   bombs(a6)
        beq     spawn
        subq.w  #1,bombs(a6)
        addq.w  #1,bombsused(a6)
        move.w  #8,flash(a6)
        move.w  #20,invul(a6)
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
        and.w   #191,d0
        add.w   #24,d0
        move.w  d0,2(a0)
        move.w  #28,4(a0)
        addq.w  #1,wave(a6)
        bra     moveenemies
bossmove:
        move.w  bossdx(a6),d0
        add.w   d0,bossx(a6)
        cmp.w   #24,bossx(a6)
        ble     bossbounce
        cmp.w   #184,bossx(a6)
        blt     bossfire
bossbounce:
        neg.w   bossdx(a6)
bossfire:
        move.l  frame(a6),d0
        and.w   #15,d0
        bne     moveenemies
        move.w  bossx(a6),d1
        add.w   #24,d1
        move.w  #65,d2
        bsr     enemyfire
moveenemies:
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
        addq.w  #8,d2
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
        subq.w  #1,life(a6)
        bgt     hurtdone
        move.w  #2,mode(a6)
        bsr     musicstop
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
        cmp.w   #64,4(a3)
        bgt     shotenemies
        move.w  2(a3),d0
        sub.w   bossx(a6),d0
        cmp.w   #48,d0
        bhi     shotenemies
        clr.w   (a3)
        subq.w  #1,bosshp(a6)
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
        cmp.w   #12,d0
        bgt     hitnext
        move.w  4(a3),d0
        sub.w   4(a4),d0
        bpl     hity
        neg.w   d0
hity:
        cmp.w   #12,d0
        bgt     hitnext
        clr.w   (a4)
        addq.w  #1,kills(a6)
        add.l   #100,score(a6)
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
        clr.w   bosshp(a6)
        add.l   #1000,score(a6)
        cmp.w   #2,stage(a6)
        beq     allclear
        addq.w  #1,stage(a6)
        bsr     stageinit
        rts
allclear:
        move.w  #3,mode(a6)
        bsr     musicstop
        rts

* Gameplay draws into a hidden 16-colour GVRAM page (512 words/scanline).
* rect: d1=x d2=y d3=width d4=height d0=palette index. Preserves all registers.
rect:
        movem.l d0-d7/a0,-(sp)
        movea.l a5,a0
        mulu    #1024,d2
        adda.l  d2,a0
        add.w   d1,d1
        adda.w  d1,a0
        move.w  #1024,d7
        sub.w   d3,d7
        sub.w   d3,d7
        subq.w  #1,d4
rectrow:
        move.w  d3,d5
        subq.w  #1,d5
rectcol:
        move.w  d0,(a0)+
        dbra    d5,rectcol
        adda.w  d7,a0
        dbra    d4,rectrow
        movem.l (sp)+,d0-d7/a0
        rts
clear:
        movea.l a5,a0
        move.l  #$00010001,d0
        move.w  #255,d2
clearrow:
        moveq   #31,d1
clearcol:
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        dbra    d1,clearcol
        adda.w  #512,a0
        dbra    d2,clearrow
        rts
render:
        bsr     clear
        moveq   #0,d1
        moveq   #20,d2
        move.w  #256,d3
        moveq   #1,d4
        move.w  #9,d0
        bsr     rect
* Ocean lanes.
        moveq   #40,d2
        moveq   #5,d7
lanes:
        moveq   #0,d1
        move.w  #256,d3
        moveq   #1,d4
        move.w  #1,d0
        bsr     rect
        add.w   #36,d2
        dbra    d7,lanes
        move.w  px(a6),d1
        subq.w  #8,d1
        move.w  py(a6),d2
        subq.w  #8,d2
        lea     luffy,a1
        bsr     sprite
        lea     enemies(a6),a3
        moveq   #7,d6
drawenemy:
        tst.w   (a3)
        beq     drawenemynext
        move.w  2(a3),d1
        subq.w  #8,d1
        move.w  4(a3),d2
        subq.w  #8,d2
        lea     minion,a1
        bsr     sprite
drawenemynext:
        addq.l  #8,a3
        dbra    d6,drawenemy
        tst.w   bosshp(a6)
        beq     drawshots
        move.w  bossx(a6),d1
        moveq   #32,d2
        lea     bigmom,a1
        cmp.w   #1,stage(a6)
        beq     drawboss
        lea     kaido,a1
drawboss:
        bsr     bosssprite
        move.w  bossx(a6),d1
        moveq   #28,d2
        move.w  bosshp(a6),d3
        add.w   d3,d3
        moveq   #2,d4
        move.w  #4,d0
        bsr     rect
drawshots:
        lea     bullets(a6),a3
        moveq   #7,d6
drawshotloop:
        tst.w   (a3)
        beq     drawshotnext
        move.w  2(a3),d1
        move.w  4(a3),d2
        moveq   #3,d3
        moveq   #7,d4
        move.w  #3,d0
        bsr     rect
drawshotnext:
        addq.l  #8,a3
        dbra    d6,drawshotloop
        lea     hostile(a6),a3
        moveq   #7,d6
drawhostile:
        tst.w   (a3)
        beq     drawhostilenext
        move.w  2(a3),d1
        move.w  4(a3),d2
        moveq   #4,d3
        moveq   #6,d4
        move.w  #7,d0
        bsr     rect
drawhostilenext:
        addq.l  #8,a3
        dbra    d6,drawhostile
        bsr     hud
        tst.w   flash(a6)
        beq     drawend
        lea     zoro,a1
        move.w  bombsused(a6),d0
        btst    #0,d0
        bne     drawally
        lea     sanji,a1
drawally:
        moveq   #32,d1
        move.w  #160,d2
        bsr     sprite
        lea     zoromsg,a1
        move.w  bombsused(a6),d0
        btst    #0,d0
        bne     allytext
        lea     sanjimsg,a1
allytext:
        moveq   #56,d1
        move.w  #166,d2
        bsr     text
drawend:
        cmp.w   #2,mode(a6)
        beq     gameover
        cmp.w   #3,mode(a6)
        beq     cleartext
        rts
gameover:
        lea     overmsg,a1
        bra     endtext
cleartext:
        lea     clearmsg,a1
endtext:
        moveq   #72,d1
        moveq   #110,d2
        bsr     text
        lea     restartmsg,a1
        moveq   #48,d1
        moveq   #126,d2
        bsr     text
        rts
hud:
        lea     scoremsg,a1
        moveq   #4,d1
        moveq   #4,d2
        bsr     text
        move.l  score(a6),d0
        moveq   #40,d1
        bsr     number
        lea     lifemsg,a1
        moveq   #82,d1
        bsr     text
        move.w  life(a6),d0
        moveq   #106,d1
        bsr     digit
        lea     bombmsg,a1
        moveq   #122,d1
        bsr     text
        move.w  bombs(a6),d0
        move.w  #146,d1
        bsr     digit
        lea     stagemsg,a1
        move.w  #162,d1
        bsr     text
        move.w  stage(a6),d0
        move.w  #198,d1
        bsr     digit
        lea     bigmsg,a1
        cmp.w   #1,stage(a6)
        beq     bosslabel
        lea     kaidomsg,a1
bosslabel:
        move.w  #186,d1
        move.w  #245,d2
        bsr     text
        rts
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
* 16x16 sprites in nibble rows: zero is transparent, palette in ART.INC.
sprite:
        movem.l d0-d7/a0-a2,-(sp)
        move.w  d1,d6
        moveq   #15,d7
sprrow:
        move.l  (a1)+,d5
        move.l  (a1)+,d4
        moveq   #15,d3
sprcol:
        moveq   #0,d0
        rol.l   #4,d5
        move.w  d5,d0
        and.w   #15,d0
        beq     sprskip
        movem.l d0-d7,-(sp)
        moveq   #1,d3
        moveq   #1,d4
        bsr     rect
        movem.l (sp)+,d0-d7
sprskip:
        addq.w  #1,d1
        cmp.w   #8,d3
        bne     sprsame
        move.l  d4,d5
sprsame:
        dbra    d3,sprcol
        move.w  d6,d1
        addq.w  #1,d2
        dbra    d7,sprrow
        movem.l (sp)+,d0-d7/a0-a2
        rts
* Boss uses the same original 16x16 design enlarged 3x horizontally/2x vertically.
bosssprite:
        movem.l d0-d7/a0-a2,-(sp)
        move.w  d1,d6
        moveq   #15,d7
bossrow:
        move.l  (a1)+,d5
        move.l  (a1)+,d4
        moveq   #15,d3
bosscol:
        moveq   #0,d0
        rol.l   #4,d5
        move.w  d5,d0
        and.w   #15,d0
        beq     bossskip
        movem.l d0-d7,-(sp)
        moveq   #3,d3
        moveq   #2,d4
        bsr     rect
        movem.l (sp)+,d0-d7
bossskip:
        addq.w  #3,d1
        cmp.w   #8,d3
        bne     bosssame
        move.l  d4,d5
bosssame:
        dbra    d3,bosscol
        move.w  d6,d1
        addq.w  #2,d2
        dbra    d7,bossrow
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
exit:
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
gameplayvideo:
        moveq   #6,d1
        moveq   #$10,d0
        trap    #15
        moveq   #$1f,d0
        trap    #15
        move.w  #$90,d0
        trap    #15
        moveq   #0,d4
setpalette:
        move.w  d4,d1
        lea     palette,a0
        add.w   d4,d4
        moveq   #0,d2
        move.w  (a0,d4.w),d2
        lsr.w   #1,d4
        move.w  #$94,d0
        trap    #15
        addq.w  #1,d4
        cmp.w   #16,d4
        blo     setpalette
        lea     $c80000,a5
        move.w  #2,drawpage(a6)
        rts
flip:
        move.w  drawpage(a6),d1
        move.w  #$b2,d0
        trap    #15
        cmp.w   #2,drawpage(a6)
        beq     drawzero
        move.w  #2,drawpage(a6)
        lea     $c80000,a5
        rts
drawzero:
        move.w  #1,drawpage(a6)
        lea     $c00000,a5
        rts
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
titledata:
        .insert TITLE.RAW
        .bss
        .even
state:  ds.b 272
        .end start
