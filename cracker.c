#include <stdio.h>
#include <stdlib.h>
#include <string.h>


int printAllKLengthRec(char *alphabet, char *prefix, int n, int k, char *pwd)
{
    int result = 0;
    int size = (int)sizeof(prefix)/sizeof(prefix[0]);
    // Base case: k is 0,
    if (k == 0) 
    {
        //printf("%s\n", prefix);
        if(strcmp(prefix, pwd) == 0)
            result = 1;
        return result;
    }
 
    // One by one add all characters 
    // from alphabet and recursively 
    // call for k equals to k-1
    for (int i = 0; i < n; ++i)
    {
        size_t len = strlen(prefix);
        char *newPrefix = malloc(len + 1 + 1 ); /* one for extra char, one for trailing zero */
        strcpy(newPrefix, prefix);
        newPrefix[len] = alphabet[i];
        newPrefix[len + 1] = '\0';
        
    
        int r = printAllKLengthRec(alphabet, newPrefix, n, k - 1, pwd);
        free( newPrefix );
        if(r == 1)
            return 1;
    }
    return 0;
}



void test(){
    char *str = "blablabla";
    char c = 'H';

    size_t len = strlen(str);
    char *str2 = malloc(len + 1 + 1 ); /* one for extra char, one for trailing zero */
    strcpy(str2, str);
    str2[len] = c;
    str2[len + 1] = '\0';

    printf( "%s\n", str2 ); /* prints "blablablaH" */

    free( str2 );
}

int main(int argc, char** argv){
    
    //Buscar la palabra dentro de un diccionario, words.txt
    
    FILE * fp;
    char * line = NULL;
    size_t len = 0;
    ssize_t read;
    fp = fopen("words.txt", "r");
    if (fp == NULL)
        exit(EXIT_FAILURE);
    int result = 0;
    while ((read = getline(&line, &len, fp)) != -1 && result == 0) {
        line[read-1] = '\0';
        if(strcmp(line, argv[1]) == 0)
            result = 1;
    }
    fclose(fp);
    if (line)
        free(line);
   
    
    char alphabet[] = "abcdefghijklmnopqrstuvwxyz";

    //Fuerza bruta
    int k = 1;
    while(result == 0 && k < 10){
        printf("Probando con palabras de longitud %d\n" , k);
        result = printAllKLengthRec(alphabet, "", 26, k, argv[1]);
        
        ++k;
    }
    //result = 1 si la encuentra
    printf("%d\n", result);
}
