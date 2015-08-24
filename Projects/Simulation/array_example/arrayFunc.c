//	This function uses double array dIn as an argument with dimensions iSizeIn
//	and puts results in double array dOut with dimensions iSizeOut
//	For this example, dIn and dOut are the same size so iSizeOut is ignored
//	But in general, dIn and dOut can have different dimensions
__declspec(dllexport)  int _stdcall useArray( double* dIn, double* dOut, int* iSizeIn, int* iSizeOut )
{
	int i, j, iHeight, iWidth;
	iHeight = iSizeIn[0];
	iWidth = iSizeIn[1];
	for(i=0;i<iHeight;i++) {
		for(j=0;j<iWidth;j++) {
			dOut[i*iWidth+j] = dIn[i*iWidth+j]*10;
		}
	}
	return 0;
}