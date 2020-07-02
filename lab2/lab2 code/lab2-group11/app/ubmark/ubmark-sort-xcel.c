//========================================================================
// ubmark-sort-xcel
//========================================================================

#include "common.h"
#include "ubmark-sort.dat"

//------------------------------------------------------------------------
// sort_xcel
//------------------------------------------------------------------------
// The basic sorting accelerator protocol is in-place (we only give the
// accelerator a single array base pointer), so we first need to copy the
// source to the destination. Note that you are free to change the
// sorting accelerator protocol if you want to use an out-of-place
// algorithm, and you are also free to modify the source array and use it
// for temporary storage. This is what mergesort does.

__attribute__ ((noinline))
void sort_xcel( int *dest, int *src, int size )
{
  // Copy source to destination

  for ( int i = 0; i < size; i++ )
    dest[i] = src[i];

  // Do in-place sort
  asm volatile (
    "csrw 0x7E1, %[dest];\n"
    "csrw 0x7E2, %[size];\n"
    "csrw 0x7E0, x0     ;\n"
    "csrr x0,    0x7E0  ;\n"

    // Outputs from the inline assembly block

    :

    // Inputs to the inline assembly block

    : [dest] "r"(dest),
      [size] "r"(size)

    // Tell the compiler this accelerator read/writes memory

    : "memory"
    );
}

/*
void value_born( int dest[], int size){
    dest[0] = 3;
    dest[1] = 5;
    dest[2] = 7;
    dest[3] = 10;
    dest[4] = 2;
    dest[5] = 6;
    dest[6] = 12;
    dest[7] = 20;
    dest[8] = 11;
    dest[9] = 13;
    dest[10] = 15;
    dest[11] = 17;
    dest[12] = 1;
    dest[13] = 1;
    dest[14] = 3;
    //dest[15] = 78;

}  */
/*void value_born (int dest[], int size)
{
    int i,j;
    int block = size / 4;
    for (i = 0; i < block; i++){
        for (j = 4 * block; j < 4 * (block + 1); j++){
            dest[i] =

        }
    }
}*/


void merge( int dest[], int size )
{
    int i,j,k,n,top_n,top_k,top_m;
    int q,p;
    int temp[size];
    int temp_sec[size];
    int c_sorting_length = 128;
    int c_sorting_tmp,c_sorting_tmp_sec;

    if ( size % c_sorting_length == 0)
        top_n = size / c_sorting_length;
    else
        top_n = size / c_sorting_length + 1;

    for (n = 1; n < top_n; n++)
    {
        if (size % c_sorting_length == 0)
            top_k = ( n + 1 ) * c_sorting_length;
        else
        {
            if ( n < (top_n - 1))
                top_k = ( n + 1 ) * c_sorting_length;
            else
                top_k = size;
        }
        for (i = 0 , j = n * c_sorting_length, k = 0; k < top_k; k++)
        {
            if(i == n * c_sorting_length)
            {
                temp[k] = dest[j++];
                continue;
            }
            if(n == 1)
            {
                if( n < top_n - 1)
                    c_sorting_tmp_sec = (n + 1) * c_sorting_length;
                else
                    c_sorting_tmp_sec = size;
                if(j == c_sorting_tmp_sec)
                {
                    temp[k] = dest[i++];
                    continue;
                }
            }
            else
            {
                if( n < top_n - 1)
                    c_sorting_tmp = (n + 1) * c_sorting_length;
                else
                    c_sorting_tmp = size;
                if(j == c_sorting_tmp)
                {
                    temp[k] = temp_sec[i++];
                    continue;
                }
            }
            if( n == 1)
            {
                if(dest[i] < dest[j])
                {
                    temp[k] = dest[i];
                    i++;
                }
                else
                {
                    temp[k] = dest[j];
                    j++;
                }
            }
            else
            {
                if(temp_sec[i] < dest[j])
                {
                    temp[k] = temp_sec[i];
                    i++;
                }
                else
                {
                    temp[k] = dest[j];
                    j++;
                }
            }
        }
        if( n < top_n - 1)
        {
            top_m = (n + 1) * c_sorting_length;
            for ( q = 0; q < top_m; q++)
            {
                temp_sec[q] = temp[q];
            }
        }
        else
        {
            top_m = size;
            for ( q = 0; q < top_m; q++)
            {
                temp_sec[q] = temp[q];
            }
        }
    }
    for ( p = 0; p < size; p++)
    {
        dest[p] = temp[p];
    }
}

//------------------------------------------------------------------------
// verify_results
//------------------------------------------------------------------------

void verify_results( int dest[], int ref[], int size )
{
  int i;
  for ( i = 0; i < size; i++ ) {
    if ( !( dest[i] == ref[i] ) ) {
      test_fail( i, dest[i], ref[i] );
    }
  }
  test_pass();
}

//------------------------------------------------------------------------
// Test Harness
//------------------------------------------------------------------------

int main( int argc, char* argv[] )
{
  int dest[size];

  int i;
  int c_sorting_length=128;

  for ( i = 0; i < size; i++ )
    dest[i] = 0;

  if (size == c_sorting_length || size < c_sorting_length) {
    test_stats_on();
    sort_xcel( dest, src, size );
    test_stats_off();
  }
  else {
    test_stats_on();
    sort_xcel( dest, src, size );
    merge( dest, size);
    test_stats_off();
  }

  verify_results( dest, ref, size );

  return 0;
}
