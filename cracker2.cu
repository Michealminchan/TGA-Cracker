#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

int printAllKLengthRec(char *alphabet, char *prefix, int n, int k, char *pwd)
{
    int result = 0;
    //int size = (int)sizeof(prefix)/sizeof(prefix[0]);
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
        char newPrefix[30]= "";// = malloc(len + 1 + 1 );
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

__global__ void permuteK(char *dAlphabet, char *dPermut, int k, int &dResult, char *pwd){
    
    if(dResult == 1) return;
    
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int pos = i*3;
    char prefix[4];
    prefix[0] = dPermut[pos];
    prefix[1] = dPermut[pos+1];
    prefix[2] = dPermut[pos+2];
    prefix[3] = '\0';
    int result = printAllKLengthRec(dAlphabet, prefix, 26, k-3, pwd);

    if(result == 1) dResult = 1;
}


void permute3(char *permutation)
{
    char alphabet[] = "abcdefghijklmnopqrstuvwxyz";
    int n = 26;
    for (int i = 0; i < n; ++i){
        for (int j = 0; j < n; ++j){
            for (int k = 0; k < n; ++k){
                char newPrefix[4];
                
                newPrefix[0] = alphabet[i];
                newPrefix[1] = alphabet[j];
                newPrefix[2] = alphabet[k];
                newPrefix[3] = '\0';              
                strcat(permutation, newPrefix);
            }
        }
    }
}

/*
void permute(char *permut3){
    permut3[0] = 'a';
    permut3[1] = '\0';
    permut3[2] = 'b';
    permut3[3] = 'c';
    permut3[4] = '\0';
}*/


void CheckCudaError(char sms[], int line) {
  cudaError_t error;
 
  error = cudaGetLastError();
  if (error) {
    printf("(ERROR) %s - %s in %s at line %d\n", sms, cudaGetErrorString(error), __FILE__, line);
    exit(EXIT_FAILURE);
  }
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
    int cont = 0;
    while ((read = getline(&line, &len, fp)) != -1 && result == 0) {
        line[read-1] = '\0';
        ++cont;
        if(strcmp(line, argv[1]) == 0)
            result = 1;
    }
    fclose(fp);
    if (line)
        free(line);
   
    
    char alphabet[] = "abcdefghijklmnopqrstuvwxyz";
    char hPermut[26*26*26*4] = "";
    
    //Fuerza bruta
    int k = 1;
    unsigned long int numBytes;
    char *dPermut;
    char *dAlphabet; 
    char *dPwd;
    int dResult;
    int nThreads = 1024;
    unsigned long int nBlocks;


    while(result == 0 && k < 10){
        printf("Probando con palabras de longitud %d\n" , k);
        if(k < 3)
            result = printAllKLengthRec(alphabet, "", 26, k, argv[1]);
        if(k == 3){
            permute3(hPermut);
            numBytes = 26*26*26*3*sizeof(char);
            cudaMalloc((char**)&dPermut, numBytes);
            cudaMalloc((char**)&dAlphabet, 26*sizeof(char));
	    cudaMalloc((char**)&dPwd, 26*sizeof(char));
            //cudaMalloc((int*)&dResult, sizeof(int)); 
            CheckCudaError((char *) "Obtener Memoria en el device", __LINE__); 

            // Copiar datos desde el host en el device 
            cudaMemcpy(dPermut, hPermut, numBytes, cudaMemcpyHostToDevice);
            cudaMemcpy(dAlphabet, alphabet, 26*sizeof(char), cudaMemcpyHostToDevice);
	    cudaMemcpy(dPwd, argv[1], 26*sizeof(char), cudaMemcpyHostToDevice);
            //cudaMemcpy(dResult, 0, sizeof(int), cudaMemcpyHostToDevice);
            
            CheckCudaError((char *) "Copiar Datos Host --> Device", __LINE__);
        }
        if(k >= 3){
	    unsigned long int N = pow(26, 3);
	    nBlocks = (N + nThreads - 1)/nThreads;
            dim3 dimGrid(nBlocks, nBlocks, 1);
	    dim3 dimBlock(nThreads, nThreads, 1);
            permuteK<<<dimGrid, dimBlock>>>(dAlphabet, dPermut, k, result, dPwd);
            CheckCudaError((char *) "Invocar Kernel", __LINE__);

	    //cudaMemcpy(result, dResult, sizeof(int), cudaMemcpyDeviceToHost);
	    //CheckCudaError((char *) "Copiar Datos Device --> Host", __LINE__);

        }
            
        
        ++k;
    }
    //result = 1 si la encuentra
    printf("%d\n", result);
}
