#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "similarity.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

static void similar_str(const char *txt1, size_t len1,
                        const char *txt2, size_t len2,
                        size_t *pos1, size_t *pos2,
                        size_t *max)
{   
    char *p = NULL;
    char *q = NULL; 
    char *end1 = (char *) txt1 + len1;
    char *end2 = (char *) txt2 + len2;
    size_t l = 0;
    size_t i = 0;
    
    *max = 0;
    for (p = (char *) txt1; p < end1; p++)
    {   
        for (q = (char *) txt2; q < end2; q++)
        {   
            for (l = 0; (p + l < end1) && (q + l < end2) && (p[l] == q[l]); l++)
            {
            }

            if (l > *max)
            {   
                *max = l; 
                *pos1 = p - txt1;
                *pos2 = q - txt2;
            }
        }
    }
}

static size_t similar_char(const char *txt1, size_t len1,
                           const char *txt2, size_t len2)
{   
    size_t sum  = 0;
    size_t pos1 = 0;
    size_t pos2 = 0;
    size_t max  = 0;
    
    similar_str(txt1, len1, txt2, len2, &pos1, &pos2, &max);
    if ((sum = max))
    {   
        // Left
        // find out the match which is not second max
        if (pos1 && pos2)
        {   
            sum += similar_char(txt1, pos1,
                                    txt2, pos2);
        }
        
        // Right
        if ((pos1 + max < len1) && (pos2 + max < len2))
        {
            sum += similar_char(txt1 + pos1 + max, len1 - pos1 - max,
                                    txt2 + pos2 + max, len2 - pos2 - max);
        }
    }

    return sum;
}

double similarity(const char *t1, size_t len1, const char *t2, size_t len2)
{
    size_t sim = 0;
    double percent = 0.0;

    if (strlen(t1) + strlen(t2) == 0) {
        return 0;
    }

    sim = similar_char(t1, strlen(t1), t2, strlen(t2));
    percent = sim * 200.0 / (strlen(t1) + strlen(t2));

    return (percent);
}
