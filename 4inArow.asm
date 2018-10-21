;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;				CONNECT 4 - game of wisdom and strategy				   ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

INCLUDE Irvine32.inc

verticalTop = 5      	;gornja granica pri iscrtavanju vertikalnih linija
verticalSize = 19		;duzina vertikalnih linija
verticalBottom = 24		;donja granica pri iscrtavanju vertikalnih linija
horizontalTop = 10		;leva granica pri iscravanju horizontalnih linija
horizontalSize = 22		;duzina horizontalnih linija

.386
.model flat, stdcall
.stack 4096
ExitProcess PROTO, dwExitCode:DWORD

.data
;promenljive potrebne za pracenje poteza
currentPlayer BYTE 1
currentResult BYTE 0
turnCount BYTE 42

;promenljive potrebne za iscrtavanje tabele
cnt DWORD 8
vertical_X BYTE 10      	;x position (column number)
horizontal_Y BYTE 10     	;y position (row number)

;promenljiva potrebna za smestanje unetog karaktera
char BYTE 0

;promenljive potrebne za proveru na 4 ploop-a u redu/koloni/dijagonali
xStraight BYTE 0
rowOffsetForChecking BYTE 0
collumnOffsetForChecking BYTE 0
diagonalOffset BYTE 0
currentPloopForChecking BYTE 0

;promenljive potrebne za proveru pobede i iscrtavanje ploops-a
ploops BYTE 42 DUP(0)
ploopsPointer BYTE 0
collumnOffset BYTE 0
rowOffset BYTE 0

;poruke koje se ispisuju na ekranu
introduction1 BYTE "Welcome to Connect4 game!",0dh,0ah,
					"You are playing it on your own resposibility!",0dh,0ah,
					"Authors won't take charge for any kind of addiction caused by this game.",0dh,0ah,0dh,0ah,0
introduction2 BYTE	"You play with your friend, and these are the RULES:",0dh,0ah,
					"Decide who'll be Player1 - it's important.",0dh,0ah,
					"Player1 plays first, by typing a number 1-7.",0dh,0ah,
					"Ploop will fall into the selected collumn.",0dh,0ah,0dh,0ah,0
introduction3 BYTE	"Ploop before PlayerX means that PlayerX should play. It's his turn.",0dh,0ah,
					"Or don't play. Just press ESC if you've had enough of our GENIUS GAME!!!",0dh,0ah,
					"We'll be sad, but press it anyways.",0dh,0ah,0dh,0ah,
					"Understood?",0dh,0ah,0
inputMessageP1 BYTE " Player1 turn: ",0
inputMessageP2 BYTE " Player2 turn: ",0
numbers BYTE "  1  2  3  4  5  6  7",0
player BYTE "Player ",0
wins BYTE " wins!!!",0dh,0ah,0
drawMessage BYTE "Well done! Game ended in a draw!",0dh,0ah,0
outMessage BYTE "Game aborted/ended :( ",0dh,0ah,0

.code
;procedura za ispisivanje tabele
DrawTable PROC
	mov  dl,vertical_X
	mov  dh,verticalTop-1
	call Gotoxy
	mov edx,offset numbers
	call WriteString
	mov  dl,vertical_X
	mov  dh,verticalTop
	call Gotoxy
	mov  ecx,verticalSize
DrawVertical:
	mov  al,0DBh
	call Gotoxy
	call WriteChar
	inc  dh
	loop Drawvertical

	add vertical_X, 3
	mov ecx,verticalSize
	mov dl,vertical_X
	mov dh,verticalTop
	dec cnt
	mov eax, cnt
	sub eax, 0
	jnz DrawVertical
	
	mov dl,horizontal_Y
	mov dh,verticalTop
	mov ecx,horizontalSize
	mov cnt,7
DrawHorizontal:
	mov  al,0DBh
	call Gotoxy
	call WriteChar
	inc  dl
	loop DrawHorizontal

	add dh,3
	mov dl,horizontal_Y
	mov ecx,horizontalSize
	dec cnt
	mov eax, cnt
	sub eax, 0
	jnz DrawHorizontal

	ret
DrawTable ENDP

;procedura za prihvatanje kolone i smestanje ploops-a na njen vrh
PlayGame PROC
CharInput:
	mov rowOffset,0
	call ReadChar
	mov char,al									;provera da li je unet esc karakter, 
	sub al,27
	jnz ContinuePlay								;ako nije, nastavlja se sa proverama i igrom
	mov dl,0										;ako jeste, izlazi se i ispisuje se abort message
	mov dh,verticalBottom
	add dh,2
	call Gotoxy	
	mov edx,offset outMessage
	call WriteString												
	INVOKE ExitProcess,0

	ContinuePlay:
	sub al,22									;provera da li je unet broj izmedju 1 i 7
	js CharInput									;ako je manji od 1
	sub al,7										;ili veci od 7
	jns CharInput										;neophodno je ponovo uneti broj!!!
	mov al,char
	sub al,48
	mov collumnOffset,al
	movzx eax,collumnOffset		;vracanje za zero-extend da bi nestale informacije o karakteru bez znacaja u eax registru
	imul eax,6
	mov ploopsPointer,al

SearchForRowOffset:
	movzx eax,ploopsPointer
	dec al	
	mov ploopsPointer, al
	mov esi, OFFSET ploops
	add esi, eax
	add rowOffset,1
	mov al,rowOffset
	sub al,7
	jz CharInput
	mov al, [esi]
	sub al,0
	jnz SearchForRowOffset
	mov al,char
	call WriteChar
	mov esi, OFFSET ploops
	movzx eax,ploopsPointer
	add esi, eax
	mov al, currentPlayer
	mov [esi], al
	call drawPloop
	ret
PlayGame ENDP

;procedura za proveru na 4 ploop-a u koloni
Check4inaCollumn PROC
	mov cnt,7
	movzx eax,collumnOffset
	imul eax,6
	mov rowOffsetForChecking, al
NotStreak:	
	mov xStraight,0
Streak:
	mov eax,cnt
	dec eax
	jz Returning
	mov cnt,eax	
	movzx eax, rowOffsetForChecking
	dec eax
	mov rowOffsetForChecking,al
	add eax, OFFSET ploops
	mov esi, eax
	mov al, [esi]
	sub al, currentPlayer
	jnz NotStreak
	movzx eax,xStraight
	inc al
	mov xStraight,al
	sub al,4
	jnz Streak
	call EndingResultWrite

Returning:
	ret
Check4inaCollumn ENDP

;procedura za proveru na 4 ploop-a u redu
Check4inaRow PROC
	mov cnt,-1
	mov eax,6
	sub al,rowOffset
	mov collumnOffsetForChecking, al
NotStreak:	
	mov xStraight,0
Streak:
	mov eax,cnt
	inc eax
	mov cnt,eax
	sub eax,7
	jz Returning
	add eax,7
	imul eax, 6
	add al, collumnOffsetForChecking
	add eax, OFFSET ploops
	mov esi, eax
	mov al, [esi]
	sub al, currentPlayer
	jnz NotStreak
	movzx eax,xStraight
	inc al
	mov xStraight,al
	sub al,4
	jnz Streak
	call EndingResultWrite

Returning:
	ret
Check4inaRow ENDP

;procedura za proveru na 4 ploop-a u glavnoj dijagonali
Check4inaMajorDiagonal PROC
	mov collumnOffsetForChecking, 0
	mov rowOffsetForChecking, 7
	movzx eax, collumnOffset
	dec eax
	imul eax,7
	mov diagonalOffset,al
	mov al, ploopsPointer
	inc al
	sub al, diagonalOffset
	mov diagonalOffset, al
	sub al,4
	jns Returning
	add al,6
	js Returning
	mov al,diagonalOffset
	dec al
	js HighDiagonals
LowDiagonals:
	mov collumnOffsetForChecking,0
	mov al,8
	sub al,diagonalOffset
	mov rowOffsetForChecking, al
	mov al,diagonalOffset
	mov currentPloopForChecking,al
	sub currentPloopForChecking,7
	jmp NotStreak
HighDiagonals:
	mov rowOffsetForChecking, 7
	movzx eax,diagonalOffset
	imul eax,-1
	mov collumnOffsetForChecking,al
	mov al,diagonalOffset
	imul eax,-6
	add	al,7
	mov currentPloopForChecking,al
	sub currentPloopForChecking,7
NotStreak:	
	mov xStraight,0
Streak:
	mov al,collumnOffsetForChecking
	inc eax
	mov collumnOffsetForChecking,al
	sub eax,8
	jz Returning
	movzx eax,rowOffsetForChecking
	dec eax
	mov rowOffsetForChecking,al
	sub eax,-1
	jz Returning

	;logika pomeranja
	movsx eax,currentPloopForChecking
	add eax,7
	mov currentPloopForChecking,al
	dec eax
	add eax, OFFSET ploops
	mov esi, eax
	mov al, [esi]
	sub al, currentPlayer
	jnz NotStreak
	movzx eax,xStraight
	inc al
	mov xStraight,al
	sub al,4
	jnz Streak
	call EndingResultWrite

Returning:
	ret
Check4inaMajorDiagonal ENDP

;;procedura za proveru na 4 ploop-a u sporednoj dijagonali
Check4inaMinorDiagonal PROC
	mov collumnOffsetForChecking, 0
	mov rowOffsetForChecking, 0
	movzx eax, collumnOffset
	dec eax
	imul eax,5
	mov diagonalOffset,al
	mov al, ploopsPointer
	inc al
	sub al, diagonalOffset
	mov diagonalOffset, al
	sub al,10
	jns Returning
	add al,6
	js Returning
	mov al,diagonalOffset
	sub al,7
	js HighDiagonals
LowDiagonals:
	mov rowOffsetForChecking,0
	mov al,diagonalOffset
	sub al,6
	mov collumnOffsetForChecking, al
	movzx eax,diagonalOffset
	imul eax,6
	sub eax,30
	mov currentPloopForChecking,al
	sub currentPloopForChecking,5
	jmp NotStreak
HighDiagonals:
	mov collumnOffsetForChecking,0
	mov al,8
	sub al,diagonalOffset	
	mov rowOffsetForChecking,al
	mov al,diagonalOffset
	mov currentPloopForChecking,al
	sub currentPloopForChecking,5
NotStreak:	
	mov xStraight,0
Streak:
	mov al,collumnOffsetForChecking
	inc eax
	mov collumnOffsetForChecking,al
	sub eax,8
	jz Returning
	movzx eax,rowOffsetForChecking
	inc eax
	mov rowOffsetForChecking,al
	sub eax,7
	jz Returning

	;logika pomeranja
	movsx eax,currentPloopForChecking
	add eax,5
	mov currentPloopForChecking,al
	dec eax
	add eax, OFFSET ploops
	mov esi, eax
	mov al, [esi]
	sub al, currentPlayer
	jnz NotStreak
	movzx eax,xStraight
	inc al
	mov xStraight,al
	sub al,4
	jnz Streak
	call EndingResultWrite

Returning:
	ret
Check4inaMinorDiagonal ENDP

;procedura za ispis rezultata igre - ako je neko pobedio
EndingResultWrite PROC
	mov dl,0
	mov dh,verticalBottom
	add dh,2
	call Gotoxy
	mov edx,offset player
	call WriteString
	mov al,currentPlayer
	add al,48
	call WriteChar
	mov edx,offset wins	
	call WriteString
	INVOKE ExitProcess,0
EndingResultWrite ENDP

;procedura za iscrtavanje ploop-a na mestu odredjenom collumnOffset i rowOffset promenljivama
drawPloop PROC
	mov dl,0
	mov dh,0
	call Gotoxy

	mov al,collumnOffset
	dec eax
	imul eax,3
	add eax,horizontalTop
	inc eax
	mov dl,al
	
	mov al,rowOffset
	dec eax
	imul eax,3
	imul eax,-1
	add eax,verticalBottom
	sub eax,2
	mov dh,al
	
	call Gotoxy
	
	movzx eax, currentPlayer
	sub eax,1
	jz casePlayer1
	
	call WriteRedDot
	add dl,1
	call Gotoxy
	call WriteRedDot
	sub dh,1
	call Gotoxy
	call WriteRedDot
	call Gotoxy
	sub dl,1
	call Gotoxy
	call WriteRedDot
	ret
caseplayer1:
	call WriteGreenDot
	add dl,1
	call Gotoxy
	call WriteGreenDot
	sub dh,1
	call Gotoxy
	call WriteGreenDot
	sub dl,1
	call Gotoxy
	call WriteGreenDot
	ret
drawPloop ENDP

;tri procedure za iscrtavanje obojenih kvadratica
WriteRedDot PROC
	mov eax,lightRed + (blue * 16)
 	call SetTextColor
	mov  al,0DBh
	call WriteChar
	mov eax,white + (blue * 16)
 	call SetTextColor
	ret
WriteRedDot ENDP

WriteBlueDot PROC
	mov eax,blue + (blue * 16)
 	call SetTextColor
	mov  al,0DBh
	call WriteChar
	mov eax,white + (blue * 16)
 	call SetTextColor
	ret
WriteBlueDot ENDP

WriteGreenDot PROC
	mov eax,green + (blue * 16)
 	call SetTextColor
	mov  al,0DBh
	call WriteChar
	mov eax,white + (blue * 16)
 	call SetTextColor
	ret
WriteGreenDot ENDP

;glavni program pocinje ovde
main PROC
	mov  edx,offset introduction1
	call WriteString
	mov  edx,offset introduction2
	call WriteString
	mov  edx,offset introduction3
	call WriteString
	call WaitMsg
	mov eax,white + (blue * 16)
 	call SetTextColor
 	call Clrscr
	call DrawTable

player1:
	mov currentPlayer,1
	mov dl,0
	mov dh,0
	call Gotoxy
	call WriteGreenDot
	mov dl,0
	mov dh,1
	call Gotoxy
	call WriteBlueDot

	mov dl,1
	mov dh,0
	call Gotoxy
	mov edx,offset inputMessageP1
	call WriteString
	call PlayGame
	call Check4inaCollumn
	call Check4inaRow
	call Check4inaMajorDiagonal
	call Check4inaMinorDiagonal

	mov al, turnCount
	sub al,1
	mov turnCount,al
	sub al,0
	jz endingProcess

player2:
	mov currentPlayer,2
	mov dl,0
	mov dh,0
	call Gotoxy
	call WriteBlueDot
	mov dl,0
	mov dh,1
	call Gotoxy
	call WriteRedDot

	mov dl,1
	mov dh,1
	call Gotoxy
	mov edx,offset inputMessageP2
	call WriteString
	call PlayGame
	call Check4inaCollumn
	call Check4inaRow
	call Check4inaMajorDiagonal
	call Check4inaMinorDiagonal
	
	mov al, turnCount
	sub al,1
	mov turnCount,al
	sub al,0
	jnz player1

;deo koda koji se izvrsava kada nema pobednika nakon 42 poteza
endingProcess:
	mov dl,0
	mov dh,verticalBottom
	add dh,2
	call Gotoxy	
	mov edx,offset drawMessage
	call WriteString
	INVOKE ExitProcess,0
main ENDP

END main

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;		  ending of CONNECT 4 - game of wisdom and strategy			   ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;