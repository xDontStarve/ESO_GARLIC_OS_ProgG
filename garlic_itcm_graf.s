@;==============================================================================
@;
@;	"garlic_itcm_graf.s":	codigo de rutinas de soporte a la gestion de
@;							ventanas graficas (version 1.0)
@;
@;==============================================================================

NVENT	= 4					@; numero de ventanas totales
PPART	= 2					@; numero de ventanas horizontales o verticales
							@; (particiones de pantalla)
L2_PPART = 1				@; log base 2 de PPART

VCOLS	= 32				@; columnas y filas de cualquier ventana
VFILS	= 24
PCOLS	= VCOLS * PPART		@; numero de columnas totales (en pantalla)
PFILS	= VFILS * PPART		@; numero de filas totales (en pantalla)

WBUFS_LEN = 36				@; longitud de cada buffer de ventana (32+4)

.section .itcm,"ax",%progbits

	.arm
	.align 2


	.global _gg_escribirLinea
	@; Rutina para escribir toda una linea de caracteres almacenada en el
	@; buffer de la ventana especificada;
	@;Parametros:
	@;	R0: ventana a actualizar (int v)
	@;	R1: fila actual (int f)
	@;	R2: numero de caracteres a escribir (int n)
_gg_escribirLinea:
	push {r3-r8, lr}
@;desplazamiento de ventanas = (((v/PPART)*PCOLS*VFILS)+(v%PPART)*VCOLS);
	and r3, r0, #L2_PPART	@; v%PPART
	lsr r4, r0, #L2_PPART	@; v/PPART
	mov r5, #PCOLS
	mov r6, #VFILS
	mov r7, #VCOLS
	mul r8, r5, r6			@; PCOLS*VFILS
	mul r6, r4, r8			@; (v/PPART)*PCOLS*VFILS
	mla r4, r3, r7, r6		@; (v/PPART)*PCOLS*VFILS+(v%PPART)*VCOLS
	mul r3, r1, r5			@; PCOLS * FILA = posición de fila dentro de la ventana
	add r4, r3				@; Desplazamiento hasta la ventana + desplazamiento dentro de la ventana
	lsl r4, #1				@; Desplazamiento de ventanas * 2: Cada baldosa son 2 bytes, cada posicion de memoria es 1 byte
	ldr r3, =map2ptr		@; Cargar variable con el puntero a mapa
	ldr r3, [r3]			@; Cargar el puntero al mapa
	add r3, r4				@; R3 = Puntero a la posición inicial de la fila actual de la ventana actual.
	ldr r4, =_gd_wbfs
	mov r6, #WBUFS_LEN		@; Tamaño de 1 posicion del buffer
	mul r5, r0, r6			@; Desplazamiento dentro del buffer hasta la ventana deseada
	add r4, r5				@; Posicion inicial del buffer de nuestra ventana
	add r4, #4				@; R4 = variable pChars
	mov r5, #0				@; R5 = Contador del bucle
	cmp r2, r5
	beq .fi_while
.while_charLeft:
	ldrb r6, [r4]			@; Cargar valor en la variable pChars
	sub r6, #32				@; Pasar de ASCII a codigo baldosa.
	strh r6, [r3]			@; Transferir el valor a la psición correspondiente. 16b
	add r5, #1				@; Actualizar variable de control de chars restantes.
	add r4, #1				@; Sumar 1 posición a ptr de pChars
	add r3, #2				@; Sumar 2 posiciones al ptr de la fila (cada baldosa son 2B).
	cmp r2, r5
	bne .while_charLeft
.fi_while:
	pop {r3-r8, pc}


	.global _gg_desplazar
	@; Rutina para desplazar una posicion hacia arriba todas las filas de la
	@; ventana (v), y borrar el contenido de la Ultima fila
	@;Parametros:
	@;	R0: ventana a desplazar (int v)
_gg_desplazar:
	push {r1-r12,lr}
	and r1, r0, #L2_PPART	@; v%PPART
	lsr r2, r0, #L2_PPART	@; v/PPART
	mov r3, #PCOLS
	mov r4, #VFILS
	mov r5, #VCOLS
	mul r6, r3, r4			@; PCOLS*VFILS
	mul r4, r2, r6			@; (v/PPART)*PCOLS*VFILS
	mla r2, r1, r5, r4		@; (v/PPART)*PCOLS*VFILS+(v%PPART)*VCOLS
	lsl r2, #1				@; Desplazamiento de ventanas * 2: Cada baldosa son 2 bytes, cada posicion de memoria es 1 byte
	ldr r1, =map2ptr		@; Cargar variable con el puntero a mapa
	ldr r1, [r1]			@; Cargar el puntero al mapa
	add r1, r2				@; R1 = Puntero a la posición inicial de la ventana actual.
	mov r2, #1				@; R2 = Contador de filas
	mov r4, #0				@; R4 = Contador de columnas
	mov r11, #0				@; R11 = Offset para mover el puntero de la fila
	mov r12, #0				@; R12 = baldosa vacía (0)
.desplazar_lineas:
	mov r4, #0
	mov r11, #0
	sub r5, r2, #1			@; Fila anterior donde copiar los elementos
	mul r6, r5, r3			
	lsl r6, #1				@; Desplazamiento para llegar desde ptr de ventana a ventana anterior.
	mul r7, r2, r3			
	lsl r7, #1				@; Desplazamiento para llegar a la fila actual.
	add r6, r1				@; R6 = puntero a fila anterior
	add r7, r1				@; R7 = puntero a fila actual
	.copiar_linea:
	cmp r4, #VCOLS
	bhs .final_linea
	ldrh r8, [r7, r11]		@; Cargar valor de fila actual y guardarlo en la anterior.
	strh r8, [r6, r11]
	strh r12, [r7, r11]		@; Guardar baldosa vacía
	add r4, #1
	add r11, #2
	b .copiar_linea
	.final_linea:
	add r2, #1				@; Actualizar fila a la siguiente
	cmp r2, #VFILS
	bls .desplazar_lineas
.final_desplazar:
	pop {r1-r12,pc}


.end