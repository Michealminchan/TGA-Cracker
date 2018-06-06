
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

__device__ void mystrcpy(char dest[], const char source[]) 
{
    int i = 0;
    while ((dest[i] = source[i]) != '\0')
    {
        i++;
    } 
}
__device__ int mystrcmp(char string1[], char string2[] )
{
    for (int i = 0; ; i++)
    {
        if (string1[i] != string2[i])
        {
            return string1[i] < string2[i] ? -1 : 1;
        }
        if (string1[i] == '\0')
        {
            return 0;
        }
    }
}

__device__ size_t mystrlen(const char *str)
{
        const char *s;
        for (s = str; *s; ++s);
        return (s - str);
}

__device__ int dResult = 0;

__device__ void permuteKRec(char *alphabet, char *prefix, int n, int k, char *pwd)
{
	if(dResult == 1) return;
    if (k == 0) 
    {
        //printf("%s\n", prefix);
        if(mystrcmp(prefix, pwd) == 0)
            dResult = 1;
		return;
    }
    for (int i = 0; i < n; ++i)
    {
        size_t len = mystrlen(prefix);
        char newPrefix[100]; // = malloc(len + 1 + 1 );
        mystrcpy(newPrefix, prefix);
        newPrefix[len] = alphabet[i];
        newPrefix[len + 1] = '\0';   
    
        permuteKRec(alphabet, newPrefix, n, k - 1, pwd);
        free( newPrefix );
    }
}


__global__ void permuteK(char *dAlphabet, char *dPermut, int k, char *pwd){
    

    if(dResult == 1) return;
    
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if(i == 1)
	printf("dento de permute");
    int pos = i*3;
    char prefix[4];
    prefix[0] = dPermut[pos];
    prefix[1] = dPermut[pos+1];
    prefix[2] = dPermut[pos+2];
    prefix[3] = '\0';
    permuteKRec(dAlphabet, prefix, 26, k-3, pwd);

    //if(result == 1) dResult = 1;
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

int permute1and2(char *pwd){
	return 0;
}

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
    int nThreads = 1024;
    unsigned long int nBlocks;


    while(result == 0 && k < 10){
        printf("Probando con palabras de longitud %d\n" , k);
        if(k < 3)
            result = permute1and2(argv[1]);
	if(k == 3){
		permute3(hPermut);
            numBytes = 26*26*26*4*sizeof(char);
            cudaMalloc((char**)&dPermut, numBytes);
            cudaMalloc((char**)&dAlphabet, 26*sizeof(char));
	    cudaMalloc((char**)&dPwd, 26*sizeof(char));
            //cudaMalloc((int*)&dResult, sizeof(int)); 
            CheckCudaError((char *) "Obtener Memoria en el device", __LINE__); 
		
		printf("CudaMallocs Done\n");
            // Copiar datos desde el host en el device 
            cudaMemcpy(dPermut, hPermut, numBytes, cudaMemcpyHostToDevice);
            cudaMemcpy(dAlphabet, alphabet, 26*sizeof(char), cudaMemcpyHostToDevice);
	    cudaMemcpy(dPwd, argv[1], 26*sizeof(char), cudaMemcpyHostToDevice);
  
            //cudaMemcpy(dResult, 0, sizeof(int), cudaMemcpyHostToDevice);
            printf("CudaMemcpy done\n");
            CheckCudaError((char *) "Copiar Datos Host --> Device", __LINE__);
        }
        if(k >= 3){
			unsigned long int N = pow(26, 3);
			nBlocks = (N + nThreads - 1)/nThreads;
		    dim3 dimGrid(nBlocks, 1, 1);
			dim3 dimBlock(nThreads, 1, 1);
		printf("call func\n");
            permuteK<<<dimGrid, dimBlock>>>(dAlphabet, dPermut, k, dPwd);
            printf("ret func\n");
		CheckCudaError((char *) "Invocar Kernel", __LINE__);

			cudaMemcpyFromSymbol(&result, "dResult", sizeof(result), 0, cudaMemcpyDeviceToHost);
	    //cudaMemcpy(result, dResult, sizeof(int), cudaMemcpyDeviceToHost);
	    //CheckCudaError((char *) "Copiar Datos Device --> Host", __LINE__);

        }
            
        
        ++k;
    }
    //result = 1 si la encuentra
    printf("%d\n", result);
}
