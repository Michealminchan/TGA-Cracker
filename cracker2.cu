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
__device__ char dPass[30] = "";

__device__ void permuteKRec(char *alphabet, char *prefix, int n, int k, char *pwd)
{
        if(dResult == 1) return;
    if (k == 0)
    {
        //printf("%s\n", prefix);
        if(mystrcmp(prefix, pwd) == 0){
            dResult = 1;
            mystrcpy(dPass, prefix);
        }
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

int permute1and2(char *pwd, char *guessed, int k){
	char alphabet[] = "abcdefghijklmnopqrstuvwxyz";
    int n = 26;
	char word[3];
    for (int i = 0; i < n; ++i){
		word[0] = alphabet[i];
		if(k == 1){
			word[1] = '\0';
		    if(strcmp(word, pwd) == 0){
		        strcpy(guessed, word);
				return 1;
		    }
		}
		else{
		    for (int j = 0; j < n; ++j){
				word[1] = alphabet[j];
				word[2] = '\0';
				if(strcmp(word, pwd) == 0){
				    strcpy(guessed, word);
					return 1;
		   		}
			}
		}
	}
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
    printf("empezamos\n");
    char passwordGuessed[15];
    /*FILE * fp;
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
        if(strcmp(line, argv[1]) == 0){
            result = 1;
			strcpy(passwordGuessed, argv[1]);
		}
    }
    fclose(fp);
    if (line)
        free(line);*/
	int result = 0;

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

	cudaEvent_t E0, E1;
	float TiempoTotal;

	cudaEventCreate(&E0);
 	cudaEventCreate(&E1);

	cudaEventRecord(E0, 0);
 	cudaEventSynchronize(E0);

    while(result == 0 && k < 15){
        printf("Probando con palabras de longitud %d\n" , k);
        if(k < 3)
            result = permute1and2(argv[1], passwordGuessed, k);
        if(k == 3){
            permute3(hPermut);
            numBytes = 26*26*26*4*sizeof(char);
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
            dim3 dimGrid(nBlocks, 1, 1);
            dim3 dimBlock(nThreads, 1, 1);
            permuteK<<<dimGrid, dimBlock>>>(dAlphabet, dPermut, k, dPwd);
	    printf("permutao\n");
            CheckCudaError((char *) "Invocar Kernel", __LINE__);

            cudaMemcpyFromSymbol(&result, dResult, sizeof(int), 0, cudaMemcpyDeviceToHost);
            if(result == 1){
               cudaMemcpyFromSymbol(&passwordGuessed, dPass, k*sizeof(char), 0, cudaMemcpyDeviceToHost);           
            }

        }
        ++k;
    }
	

	
	cudaEventRecord(E1, 0);
 	cudaEventSynchronize(E1);	
	cudaEventElapsedTime(&TiempoTotal,  E0, E1);
	cudaEventDestroy(E0); cudaEventDestroy(E1);	

	if(k >= 3){
		// Liberar Memoria del device 
  		cudaFree(dPermut); cudaFree(dAlphabet); cudaFree(dPwd);
		cudaDeviceSynchronize();
	}

	if(result == 1){
		printf("Tiempo paralelo para encontrar la contraseña %s: %4.6f segundos\n", passwordGuessed, TiempoTotal/1000.0f);	
	}
	else
		printf("Password not found...\n");
    
}
