#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "similarity/similarity.h"

MODULE = similar_text		PACKAGE = similar_text		

double
similarity(c1, l1, c2, l2)
	   const char * c1
	   long         l1
	   const char * c2
           long         l2
    OUTPUT:
	   RETVAL

double
similar_text(s1, s2)
             char * s1
             char * s2
             PROTOTYPE: @
             CODE:
{
    RETVAL = similarity(s1, strlen(s1), s2, strlen(s2));
}
    OUTPUT:
    RETVAL
