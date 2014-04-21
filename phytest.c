/*
 * Sample program to call phymem.sys:
 * Syntax: phytest [# lines] [starting line]
 *
 * The program 
 * 1) reads the specified number of lines from the physical screen,
 * 2) clears the screen with dashed lines,
 * 3) outputs the lines read back to the screen with the reverse
 * video attribute.
 * - Illustrates reading / writing physical memory.
 * 
 * Chuck Grandgent, AEG Modicon, Industrial Automation Systems Group,
 * North Andover, Massachusetts
 * CIS 72330,450        Co-Pro BBS 508-975-9779
 * Usenet: Chuck_M_Grandgent@cup.portal.com
 *
 * This program may be freely copied without restriction.
 * No warrantees are made, expressed, or implied.
 * The user assumes full burden of responsibility for suitability
 * of this program for any purpose.   8/14/89
 */

#define INCL_DOS
#include <os2.h>

#include <stdio.h>
#include <process.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <memory.h>

#define ATTR 0          /* normal file */
#define OPENFLAG 0x01   /* fail if no file, or open it */
#define OPENMODE 0x0042 /* acc=read/write, share=deny none */
#define STDOUT (unsigned short)1  /* file handle for screen */

int main(int argc, char **argv);

#ifndef SEGSIZE
#define SEGSIZE 4000
#endif

unsigned short phymem_handle;   /* file handle from DosOpen */

int main(argc, argv)
int argc;
char **argv;
    {
    static char buffer[SEGSIZE];    /* 4k buffer */
    unsigned bytes_to_read;
    unsigned char *bufp;
    int i, j, begin_line;
    unsigned action;    /* action taken by DosOpen */
    unsigned rc;        /* return code */
    unsigned long size = 0; /* no minimum size of file */
    unsigned BytesRead; /* bytes read by DosRead */
    unsigned phymemseg;

    if (argc < 2){
        bytes_to_read = 4000;
        begin_line = 0;
        }
    else {
        bytes_to_read = 2 * 80 * atoi(argv[1]);
                        /* specify # of lines to read */
        if (argc == 3)
            begin_line = atoi(argv[2]); /* specify begining line to read */
        else 
            begin_line = 0;
        }

    if (bytes_to_read > SEGSIZE)
        bytes_to_read = SEGSIZE;    /* limit to 80 chars x 25 lines */

    if (rc = DosOpen("phymem$", &phymem_handle, &action, size, ATTR,
        OPENFLAG, OPENMODE, 0L)) {
        fprintf(stderr, "\nError opening device\n");
        exit(1);
        }

    phymemseg = 0;      /* initialize before read */
    if (rc = DosRead(phymem_handle, (char *) &phymemseg, 2, &BytesRead)) {
        fprintf(stderr, "\nDosRead error=%u\n", rc);
        exit(1);
        }
    fprintf(stderr, "\nSelector @ 0x%04X \n", phymemseg);
    DosClose(phymem_handle);

    bufp = (unsigned char *) buffer;    /* clear buffer to spaces */
    for (i = 0;  i < SEGSIZE;  i++) {
        *bufp = ' ';
        bufp++;
        }

/*
 * now copy from the graphics adapter memory to here (read the screen)
 */
    memcpy(buffer, (char *) ((((long) (phymemseg)) << 16) + (long) (begin_line * 80 * 2)), bytes_to_read);

    bufp = buffer;
    for (i = 0;  i < (bytes_to_read / 2) / 80;  i++) {
        for (j = 0;  j < 80;  j++) {
            if (isprint(*bufp)) {
                printf("%c", *bufp);
                }
            bufp += 2;
            }
        }

/*
 * Mark end of read
 */
    for (i = 0;  i < 25;  i++)
        printf("\n__________________________________________________________________________");


    bufp = buffer;
    bufp++;             /* start at attribute byte */
    for (i = 0;  i < (bytes_to_read / 2) / 80;  i++) {
        for (j = 0;  j < 80;  j++) {
            *bufp = 0x70;   /* >>>>> set to reverse video <<<<<< */
            bufp += 2;
            }
        }

/*
 * Now copy from here to graphics adapter memory (write to screen directly)
 */
    memcpy((char *) ((((long) (phymemseg)) << 16) + ((long) (begin_line * 80 * 2))), buffer, bytes_to_read);

    exit(0);

    return 0;
    }
