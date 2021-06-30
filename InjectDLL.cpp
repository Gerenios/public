#include <iostream>
#include <windows.h>
#include <stdio.h>
#include <string>
#include <tlhelp32.h>


int loadlibrary(int pid, char* dll);
bool EnableDebugPrivilege();

int main(int argc, char** argv)
{
	if (argc != 3)
	{
		printf("Usage: InjectDLL <process id> <full path of dll>\n");
		return false;
	}

	EnableDebugPrivilege();
	int pid = std::stoi(argv[1]);
	char* dll = argv[2];

	printf("Injecting %s to process %i\n", dll, pid);

	if (!loadlibrary(pid, dll))
	{
		printf("DLL injected successfully\n");
	}

}


int loadlibrary(int pid, char* dll) {
	SIZE_T bytesWritten = 0;

	HANDLE processHandle = OpenProcess(PROCESS_ALL_ACCESS, false, pid);
	if (processHandle == INVALID_HANDLE_VALUE) {
		printf("Error: Could not open process\n");
		return 1;
	}

	void* alloc = VirtualAllocEx(processHandle, 0, 4096, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
	if (alloc == NULL) {
		printf("Error: Could not allocate memory in process\n");
		return 1;
	}

	void* _loadLibrary = GetProcAddress(LoadLibraryA("kernel32.dll"), "LoadLibraryA");
	if (_loadLibrary == NULL) {
		printf("Could not find address of LoadLibrary\n");
		return 1;
	}

	if (!WriteProcessMemory(processHandle, alloc, dll, strlen(dll) + 1, &bytesWritten)) {
		printf("Could not write into process memory\n");
		return 2;
	}
	
	if (CreateRemoteThread(processHandle, NULL, 0, (LPTHREAD_START_ROUTINE)_loadLibrary, alloc, 0, NULL) == NULL) {
		printf("CreateRemoteThread failed [%d] :(\n", GetLastError());
		return 2;
	}

	return 0;
}

bool EnableDebugPrivilege()
{
	HANDLE hThis = GetCurrentProcess();
	HANDLE hToken;
	OpenProcessToken(hThis, TOKEN_ADJUST_PRIVILEGES, &hToken);
	LUID luid;
	LookupPrivilegeValue(0, TEXT("seDebugPrivilege"), &luid);
	TOKEN_PRIVILEGES priv;
	priv.PrivilegeCount = 1;
	priv.Privileges[0].Luid = luid;
	priv.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
	AdjustTokenPrivileges(hToken, false, &priv, sizeof(priv), 0, 0);
	CloseHandle(hToken);
	CloseHandle(hThis);
	return true;
}

