#include <iostream>
#include <windows.h>
#include <stdio.h>
#include <string>
#include <tlhelp32.h>


int loadlibrary(int pid, char* dll, char* function);
bool EnableDebugPrivilege();

int main(int argc, char** argv)
{
	if (argc < 3 || argc > 4)
	{
		printf("Usage: InjectDLL <process id> <full path of dll> <function to call>\n");
		return false;
	}

	if (!EnableDebugPrivilege())
	{
		printf("Elevation failed");
		return false;
	}

	int pid = std::stoi(argv[1]);
	char* dll = argv[2];
	char* function = NULL;

	if (argc == 4)
	{
		function = argv[3];
		printf("Calling function %s\n\r", function);
	}

	printf("Injecting %s to process %i\n\r", dll, pid);

	if (!loadlibrary(pid, dll, function))
	{
		printf("DLL injected successfully\n\r");
	}

	

}

int loadlibrary(int pid, char* dll, char* function) {
	SIZE_T bytesWritten = 0;
	DWORD exitCode = 0;

	// Open the provided process
	HANDLE processHandle = OpenProcess(PROCESS_ALL_ACCESS, false, pid);
	if (processHandle == INVALID_HANDLE_VALUE) {
		printf("Error: Could not open process %i\n\r", pid);
		exitCode = 1;
	}
	else
	{
		// Allocate memory for the dll name
		void* alloc = VirtualAllocEx(processHandle, 0, strlen(dll) + 1, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
		if (alloc == NULL) {
			printf("Error: Could not allocate memory in process\n\r");
			exitCode = 1;
		}
		else
		{
			// Get address of LoadLibraryA function
			void* _loadLibrary = GetProcAddress(LoadLibraryA("kernel32.dll"), "LoadLibraryA");
			if (_loadLibrary == NULL) {
				printf("Could not find address of LoadLibrary\n\r");
				exitCode = 1;
			}
			else
			{
				// Write the dll name to allocated memory
				if (!WriteProcessMemory(processHandle, alloc, dll, strlen(dll) + 1, &bytesWritten)) {
					printf("Could not write into process memory\n\r");
					exitCode = 2;
				}
				else
				{
					// Call the LoadLibrary function
					HANDLE htLoadLibrary = NULL;
					htLoadLibrary = CreateRemoteThread(processHandle, NULL, 0, (LPTHREAD_START_ROUTINE)_loadLibrary, alloc, 0, 0);
					if (htLoadLibrary == NULL) {
						printf("CreateRemoteThread for LoadLibrary failed [%d]\n\r", GetLastError());
						exitCode = 2;
					}
					else
					{
						// Wait for the thread to exit
						WaitForSingleObject(htLoadLibrary, INFINITE);
						CloseHandle(htLoadLibrary);

						if (function != NULL)
						{
							printf("Trying to find %s from %s\n\r", function, dll);
							HMODULE _dll = LoadLibraryA(dll);
							if (_dll == NULL)
							{
								printf("Could not load dll %s\n\r", dll);
								exitCode = 2;
							}
							else
							{
							
								void* _function = GetProcAddress(_dll, function);
								if (_function == NULL) {
									printf("Could not find address of %s from %s\n\r", function, dll);
									exitCode = 1;
								}
								else
								{
									// Call the provided function
									HANDLE htFunction = NULL;
									htFunction = CreateRemoteThread(processHandle, NULL, 0, (LPTHREAD_START_ROUTINE)_function, NULL, 0, 0);
									if (htFunction == NULL) {
										printf("CreateRemoteThread for %s failed [%d]\n\r", function, GetLastError());
										exitCode = 2;
									}
									else
									{
										// Wait for the thread to exit
										WaitForSingleObject(htFunction, INFINITE);
										CloseHandle(htFunction);
										printf("Function %s executed successfully\n\r", function);
									}
								}
							}
						}
					}
				}
			}
			// Close the process handle
			CloseHandle(processHandle);
		}
	}

	return exitCode;
}

bool EnableDebugPrivilege()
{
	bool exitCode = true;
	HANDLE hThis = GetCurrentProcess();
	HANDLE hToken;
	OpenProcessToken(hThis, TOKEN_ADJUST_PRIVILEGES, &hToken);
	LUID luid;
	LookupPrivilegeValue(0, TEXT("seDebugPrivilege"), &luid);
	TOKEN_PRIVILEGES priv;
	priv.PrivilegeCount = 1;
	priv.Privileges[0].Luid = luid;
	priv.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
	exitCode = AdjustTokenPrivileges(hToken, false, &priv, sizeof(priv), 0, 0);
	CloseHandle(hToken);
	CloseHandle(hThis);
	return exitCode;
}


