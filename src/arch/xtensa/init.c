/* 
 * BSD 3 Clause - See LICENCE file for details.
 *
 * Copyright (c) 2015, Intel Corporation
 * All rights reserved.
 *
 * Authors:	Liam Girdwood <liam.r.girdwood@linux.intel.com>
 *
 * Xtensa architecture initialisation.
 */

#include <xtensa/xtruntime.h>
#include <xtensa/hal.h>
#include <platform/memory.h>
#include <platform/interrupt.h>
#include <reef/mailbox.h>
#include <reef/debug.h>
#include <reef/init.h>
#include <stdint.h>

static void exception(void)
{
	volatile uint32_t *dump = (uint32_t*) mailbox_get_exception_base();

	/* Exception Vector number */
	__asm__ __volatile__ ("rsr %0, EXCCAUSE" : "=a" (dump[0]) : : "memory");
	/* Exception Vector address */
	__asm__ __volatile__ ("rsr %0, EXCVADDR" : "=a" (dump[1]) : : "memory");
	/* Exception Program counter */
	__asm__ __volatile__ ("rsr %0, PS" : "=a" (dump[2]) : : "memory");
	/* Level 1 Exception PC */
	__asm__ __volatile__ ("rsr %0, EPC1" : "=a" (dump[3]) : : "memory");
	/* Level 2 Exception PC */
	__asm__ __volatile__ ("rsr %0, EPC2" : "=a" (dump[4]) : : "memory");
	/* Level 3 Exception PC */
	__asm__ __volatile__ ("rsr %0, EPC3" : "=a" (dump[5]) : : "memory");
	/* Level 4 Exception PC */
	__asm__ __volatile__ ("rsr %0, EPC4" : "=a" (dump[6]) : : "memory");
	/* Level 5 Exception PC */
	__asm__ __volatile__ ("rsr %0, EPC5" : "=a" (dump[7]) : : "memory");
	/* Level 6 Exception PC */
	__asm__ __volatile__ ("rsr %0, EPC6" : "=a" (dump[8]) : : "memory");
	/* Level 7 Exception PC */
	__asm__ __volatile__ ("rsr %0, EPC7" : "=a" (dump[9]) : : "memory");
	/* Level 2 Exception PS */
	__asm__ __volatile__ ("rsr %0, EPS2" : "=a" (dump[10]) : : "memory");
	/* Level 3 Exception PS */
	__asm__ __volatile__ ("rsr %0, EPS3" : "=a" (dump[11]) : : "memory");
	/* Level 4 Exception PS */
	__asm__ __volatile__ ("rsr %0, EPS4" : "=a" (dump[12]) : : "memory");
	/* Level 5 Exception PS */
	__asm__ __volatile__ ("rsr %0, EPS5" : "=a" (dump[13]) : : "memory");
	/* Level 6 Exception PS */
	__asm__ __volatile__ ("rsr %0, EPS6" : "=a" (dump[14]) : : "memory");
	/* Level 7 Exception PS */
	__asm__ __volatile__ ("rsr %0, EPS7" : "=a" (dump[15]) : : "memory");
	/* Double Exception program counter */
	__asm__ __volatile__ ("rsr %0, DEPC" : "=a" (dump[16]) : : "memory");

	/* atm we loop forever */
	/* TODO: we should probably stall/HALT at this point or recover */
	while(1) {};
}

static void register_exceptions(void)
{
	_xtos_set_exception_handler(EXCCAUSE_ILLEGAL, (void*) &exception);
	_xtos_set_exception_handler(EXCCAUSE_SYSCALL, (void*) &exception);
	_xtos_set_exception_handler(EXCCAUSE_DIVIDE_BY_ZERO, (void*) &exception);

	_xtos_set_exception_handler(EXCCAUSE_INSTR_DATA_ERROR, (void*) &exception);
	_xtos_set_exception_handler(EXCCAUSE_INSTR_ADDR_ERROR, (void*) &exception);

	_xtos_set_exception_handler(EXCCAUSE_LOAD_STORE_ERROR, (void*) &exception);
	_xtos_set_exception_handler(EXCCAUSE_LOAD_STORE_ADDR_ERROR, (void*) &exception);
	_xtos_set_exception_handler(EXCCAUSE_LOAD_STORE_DATA_ERROR, (void*) &exception);
}

int arch_init(void)
{
	register_exceptions();
	return 0;
}

/* called from assembler context with no return or func parameters */
void __memmap_init(void)
{
}

