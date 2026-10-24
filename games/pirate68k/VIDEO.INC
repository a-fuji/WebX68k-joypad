* XSP owns hardware sprites; GVRAM holds the static stage; TVRAM holds HUD.
        .xref _xsp_on,_xsp_off,_xsp_mode,_xsp_pcgdat_set
        .xref _xsp_set_st,_xsp_out,_xsp_vsync
graphicsstop:
        tst.w   xspactive(a6)
        beq     graphicsstopped
        jsr     _xsp_off
        clr.w   xspactive(a6)
graphicsstopped:
        rts
gameplayvideo:
        bsr     graphicsstop
        moveq   #10,d1
        moveq   #$10,d0
        trap    #15
        moveq   #$1f,d0
        trap    #15
        move.w  #$90,d0
        trap    #15
        movem.l d0-d2/a0-a2,-(sp)
        jsr     _xsp_on
* 128 hardware entries are sufficient; avoid raster splitting for this game.
        move.l  #1,-(sp)
        jsr     _xsp_mode
        addq.l  #4,sp
        move.l  #SP_COUNT+1,-(sp)
        pea     spalt
        pea     spdata
        jsr     _xsp_pcgdat_set
        lea     12(sp),sp
        movem.l (sp)+,d0-d2/a0-a2
        move.w  #1,xspactive(a6)
        clr.w   spritepeak(a6)
        move.l  #-1,hudscore
        lea     sppal,a0
        lea     $e82220,a1
        move.w  #159,d0
spalcopy:
        move.w  (a0)+,(a1)+
        dbra    d0,spalcopy
        move.w  #$ffff,$e82202
        move.w  #$12e4,$e82500
        move.w  #$0061,$e82600
        bsr     clear
        rts
background:
        movem.l d0-d3/a0-a2,-(sp)
        lea     bg1,a0
        lea     bg1pal,a2
        cmp.w   #1,stage(a6)
        beq     bgcopy
        lea     bg2,a0
        lea     bg2pal,a2
bgcopy:
        lea     $e82000,a1
        move.w  #255,d0
bgpalette:
        move.w  (a2)+,(a1)+
        dbra    d0,bgpalette
        lea     $c00000,a1
        move.w  #255,d2
bgrow:
        move.w  #255,d1
        moveq   #0,d0
bgpixel:
        move.b  (a0)+,d0
        move.w  d0,(a1)+
        dbra    d1,bgpixel
        adda.w  #512,a1
        dbra    d2,bgrow
        move.w  stage(a6),videostage(a6)
        movem.l (sp)+,d0-d3/a0-a2
        rts
* Clear the visible 256x256 region of text plane 0 only (32 bytes/line).
clear:
        movem.l d0-d2/a0,-(sp)
        lea     $e00000,a0
        move.w  #255,d2
textclearrow:
        moveq   #7,d1
textclearcol:
        clr.l   (a0)+
        dbra    d1,textclearcol
        adda.w  #96,a0
        dbra    d2,textclearrow
        movem.l (sp)+,d0-d2/a0
        rts
* Font pixels on transparent TVRAM. d1=x,d2=y,d3=width,d4=height.
rect:
        movem.l d0-d7/a0,-(sp)
        move.w  d1,d6
        subq.w  #1,d4
txrectrow:
        move.w  d3,d5
        subq.w  #1,d5
txrectcol:
        move.w  d2,d0
        mulu    #128,d0
        move.w  d1,d7
        lsr.w   #3,d7
        add.w   d7,d0
        lea     $e00000,a0
        adda.l  d0,a0
        move.w  d1,d7
        not.w   d7
        and.w   #7,d7
        bset    d7,(a0)
        addq.w  #1,d1
        dbra    d5,txrectcol
        move.w  d6,d1
        addq.w  #1,d2
        dbra    d4,txrectrow
        movem.l (sp)+,d0-d7/a0
        rts
* Composite descriptor: count followed by signed dx,dy,PCG,info words.
* d1/d2 are the object's center in visible screen coordinates.
sprite:
        movem.l d0-d7/a0-a4,-(sp)
        movea.l a1,a3
        move.w  d1,d4
        move.w  d2,d5
        move.w  (a3)+,d7
        subq.w  #1,d7
sprtile:
        lea     sparg,a4
        move.w  (a3)+,d0
        add.w   d4,d0
        move.w  d0,(a4)
        move.w  (a3)+,d0
        add.w   d5,d0
        move.w  d0,2(a4)
        move.l  (a3)+,4(a4)
        pea     sparg
        jsr     _xsp_set_st
        addq.l  #4,sp
        dbra    d7,sprtile
        movem.l (sp)+,d0-d7/a0-a4
        rts
render:
        bsr     refreshhud
        tst.w   invul(a6)
        beq     playerdraw
        btst    #1,frame+3(a6)
        bne     playerhidden
playerdraw:
        lea     luffy_idle,a1
        btst    #2,keys+1(a6)
        beq     playerright
        lea     luffy_left,a1
playerright:
        btst    #3,keys+1(a6)
        beq     playerfire
        lea     luffy_right,a1
playerfire:
        cmp.w   #3,cooldown(a6)
        blt     playerpose
        lea     luffy_shot,a1
playerpose:
        move.w  px(a6),d1
        move.w  py(a6),d2
        bsr     sprite
playerhidden:
        lea     enemies(a6),a3
        moveq   #7,d6
drawenemy:
        tst.w   (a3)
        beq     drawenemynext
        move.w  2(a3),d1
        move.w  4(a3),d2
        lea     grunt_idle,a1
        btst    #3,frame+3(a6)
        beq     gruntpose
        lea     grunt_step,a1
gruntpose:
        bsr     sprite
drawenemynext:
        addq.l  #8,a3
        dbra    d6,drawenemy
        tst.w   bosshp(a6)
        beq     drawshots
        move.w  bossx(a6),d1
        moveq   #78,d2
        lea     bigmom_art,a1
        cmp.w   #1,stage(a6)
        beq     drawboss
        lea     kaido_art,a1
drawboss:
        bsr     sprite
        move.w  #88,d1
        moveq   #23,d2
        move.w  bosshp(a6),d3
        mulu    #80,d3
        moveq   #16,d0
        cmp.w   #1,stage(a6)
        beq     hpwidth
        moveq   #24,d0
hpwidth:
        divu    d0,d3
        moveq   #2,d4
        bsr     rect
drawshots:
        lea     bullets(a6),a3
        moveq   #7,d6
drawshotloop:
        tst.w   (a3)
        beq     drawshotnext
        move.w  2(a3),d1
        move.w  4(a3),d2
        lea     shot_art,a1
        bsr     sprite
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
        lea     orb_art,a1
        bsr     sprite
drawhostilenext:
        addq.l  #8,a3
        dbra    d6,drawhostile
        tst.w   flash(a6)
        beq     drawend
        lea     zoro_art,a1
        btst    #0,bombsused+1(a6)
        bne     drawally
        lea     sanji_art,a1
drawally:
        moveq   #64,d1
        move.w  #172,d2
        bsr     sprite
        lea     slash_art,a1
        btst    #0,bombsused+1(a6)
        bne     draweffect
        lea     flame_art,a1
draweffect:
        move.w  #144,d1
        add.w   flash(a6),d1
        move.w  #152,d2
        sub.w   flash(a6),d2
        bsr     sprite
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
        move.w  #144,d2
        bsr     text
        lea     restartmsg,a1
        moveq   #48,d1
        move.w  #158,d2
        bsr     text
        rts
* TVRAM is persistent. Repaint only when values change, avoiding clear/draw tearing.
refreshhud:
        move.l  score(a6),d0
        cmp.l   hudscore,d0
        bne     hudchanged
        move.l  kills(a6),d0
        cmp.l   hudkillslife,d0
        bne     hudchanged
        move.w  bombs(a6),d0
        cmp.w   hudbombs,d0
        bne     hudchanged
        move.l  mode(a6),d0
        cmp.l   hudmodestage,d0
        bne     hudchanged
        move.w  bosshp(a6),d0
        cmp.w   hudhp,d0
        beq     hudunchanged
hudchanged:
        move.l  score(a6),hudscore
        move.l  kills(a6),hudkillslife
        move.w  bombs(a6),hudbombs
        move.l  mode(a6),hudmodestage
        move.w  bosshp(a6),hudhp
        bsr     clear
        bsr     hud
hudunchanged:
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
        move.w  #190,d1
        bsr     text
        move.w  life(a6),d0
        move.w  #222,d1
        bsr     digit
        lea     bombmsg,a1
        moveq   #4,d1
        move.w  #245,d2
        bsr     text
        move.w  bombs(a6),d0
        moveq   #36,d1
        bsr     digit
        lea     stagemsg,a1
        moveq   #64,d1
        bsr     text
        move.w  stage(a6),d0
        moveq   #100,d1
        bsr     digit
        lea     bigmsg,a1
        cmp.w   #1,stage(a6)
        beq     bosslabel
        lea     kaidomsg,a1
bosslabel:
        move.w  #186,d1
        bsr     text
        rts
flip:
        movem.l d0-d2/a0-a2,-(sp)
        jsr     _xsp_out
        move.w  d0,spritecount(a6)
        cmp.w   spritepeak(a6),d0
        bls     peakdone
        move.w  d0,spritepeak(a6)
peakdone:
        move.l  #1,-(sp)
        jsr     _xsp_vsync
        addq.l  #4,sp
        movem.l (sp)+,d0-d2/a0-a2
        rts
