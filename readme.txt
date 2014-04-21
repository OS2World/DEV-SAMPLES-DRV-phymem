 Here is a sample device driver which does I/O to physical memory,
 along with a sample program which calls it.
 
 This driver performs little useful purpose except to illustrate some
 basic principles of physical memory access under OS/2.

 < phymem.c >:
 Sample program to call phymem.sys:
 Syntax: phytest [# lines] [starting line]

For the Driver, phymem.asm, you must define the physical segment to
address, and its size:
Example:

PHYSEG  = 0b800h     EGA window segment
SEGSIZE = 0fa0h      EGA window size, 80 * 25 * 2
    masmos2 /W2 /p /DPHYSEG=0b800h /DSEGSIZE=0fa0h phymem,phymem;

For the example "C" program which calls the driver, you must also define
the size of the segment"
Example:
    cl /AL /DSEGSIZE=4000 /W3 /c phytest.c

 The sample "C" program 
 1) reads the specified number of lines from the physical screen,
 2) clears the screen with dashed lines,
 3) outputs the lines read back to the screen with the reverse
 video attribute.
 - Illustrates reading / writing physical memory.
 
 Chuck Grandgent, AEG Modicon, Industrial Automation Systems Group,
 North Andover, Massachusetts
 CIS 72330,450        Co-Pro BBS 508-975-9779
 Usenet: Chuck_M_Grandgent@cup.portal.com

 These programs may be freely copied without restriction.
 No warrantees are made, expressed, or implied.
 The user assumes full burden of responsibility for suitability
 of this program for any purpose.   8/14/89

 Note: the skeleton for the driver is from:
 Ray Duncan's "Advanced OS/2 programming", which I heartily recommend.


PHYTEST           110   8-14-89   8:57p Makefile for program that calls the
                                        driver
PHYMEM   ASM    14987   8-14-89   9:06p Driver assembler source
READ     ME       752   8-14-89   9:07p This file
PHYMEM   DEF       25   8-02-89  10:52a .def file for driver
PHYMEM            528   8-14-89   6:45p Makefile for the driver
PHYTEST  C       3654   8-14-89   8:55p Sample program to call the driver

