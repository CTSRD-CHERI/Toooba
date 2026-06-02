#include <util.h>
//#include <stdio.h>
//#include <math.h>
#include "../bareBench.h"
#include "input_large.h"

#define UNLIMIT


/*struct my3DVertexStruct {
  int x, y, z;
  double distance;
};*/

static void swap_bytes(char *a, char *b, unsigned long size) {
    while (size--) {
        char tmp = *a;
        *a++ = *b;
        *b++ = tmp;
    }
}

static void quicksort(char *base, unsigned long left, unsigned long right, unsigned long size,
                      int (*compar)(const void *, const void *)) {
    if (left >= right) return;

    unsigned long pivot_index = left + (right - left) / 2;
    char *pivot = base + pivot_index * size;

    // Move pivot to end
    swap_bytes(base + pivot_index * size, base + right * size, size);

    unsigned long store_index = left;
    for (unsigned long i = left; i < right; i++) {
        if (compar(base + i * size, base + right * size) < 0) {
            swap_bytes(base + i * size, base + store_index * size, size);
            store_index++;
        }
    }

    // Move pivot to its final place
    swap_bytes(base + store_index * size, base + right * size, size);

    if (store_index > 0)
        quicksort(base, left, store_index - 1, size, compar);
    quicksort(base, store_index + 1, right, size, compar);
}

void qsort(void *base, unsigned long nmemb, unsigned long size,
           int (*compar)(const void *, const void *)) {
    if (!base || nmemb < 2 || !compar) return;

    quicksort((char *)base, 0, nmemb - 1, size, compar);
}

int compare(const void *elem1, const void *elem2)
{
  /* D = [(x1 - x2)^2 + (y1 - y2)^2 + (z1 - z2)^2]^(1/2) */
  /* sort based on distances from the origin... */

  double distance1, distance2;

  distance1 = (*((struct my3DVertexStruct *)elem1)).distance;
  distance2 = (*((struct my3DVertexStruct *)elem2)).distance;

  return (distance1 > distance2) ? 1 : ((distance1 == distance2) ? 0 : -1);
}

volatile int output;

int
main(void) {
  int i,count=0;

  for(count = 0; count < sizeof(array)/sizeof(struct my3DVertexStruct); ++count)
	 array[count].distance = sqrt(pow(array[count].x, 2) + pow(array[count].y, 2) + pow(array[count].z, 2));
  
  //printf("\nSorting %d vectors based on distance from the origin.\n\n",count);
  output = count;
  qsort(array,count,sizeof(struct my3DVertexStruct),compare);
  
  for(i=0;i<count;i++)
    output = array[i].x ^ array[i].y ^ array[i].z;
     //printf("%d %d %d\n", array[i].x, array[i].y, array[i].z);
  return 0;
}
