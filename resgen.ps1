Add-Type -a System.Drawing, System.Windows.Forms, System.Design
$resgen = @'
using System;
using System.CodeDom;
using System.CodeDom.Compiler;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Resources;
using System.Resources.Tools;
using System.Runtime.InteropServices;
using System.Runtime.CompilerServices;
using System.Security;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Xml;
using Microsoft.Runtime.Hosting;
using Microsoft.Win32;

namespace System.Tools
{
	public static class ResGen
	{
		private static void Error(string message)
		{
			ResGen.Error(message, 0);
		}

		private static void Error(string message, int errorNumber)
		{
			Console.Error.WriteLine("ResGen : error RG{1:0000}: {0}", message, errorNumber);
			ResGen.errors++;
		}

		private static void Error(string message, string fileName)
		{
			ResGen.Error(message, fileName, 0);
		}

		private static void Error(string message, string fileName, int errorNumber)
		{
			Console.Error.WriteLine("{0} : error RG{1:0000}: {2}", fileName, errorNumber, message);
			ResGen.errors++;
		}

		private static void Error(string message, string fileName, int line, int column)
		{
			ResGen.Error(message, fileName, line, column, 0);
		}

		private static void Error(string message, string fileName, int line, int column, int errorNumber)
		{
			Console.Error.WriteLine("{0}({1},{2}): error RG{3:0000}: {4}", new object[] {fileName, line, column, errorNumber, message});
			ResGen.errors++;
		}

		private static void Warning(string message)
		{
			Console.Error.WriteLine("ResGen : warning RG0000 : {0}", message);
			ResGen.warnings++;
		}

		private static void Warning(string message, string fileName)
		{
			ResGen.Warning(message, fileName, 0);
		}

		private static void Warning(string message, string fileName, int warningNumber)
		{
			Console.Error.WriteLine("{0} : warning RG{1:0000}: {2}", fileName, warningNumber, message);
			ResGen.warnings++;
		}

		private static void Warning(string message, string fileName, int line, int column)
		{
			ResGen.Warning(message, fileName, line, column, 0);
		}

		private static void Warning(string message, string fileName, int line, int column, int warningNumber)
		{
			Console.Error.WriteLine("{0}({1},{2}): warning RG{3:0000}: {4}", new object[] {fileName, line, column, warningNumber, message});
			ResGen.warnings++;
		}

		private static ResGen.Format GetFormat(string filename)
		{
			string extension = Path.GetExtension(filename);
			if (string.Compare(extension, ".txt", StringComparison.OrdinalIgnoreCase) == 0 || string.Compare(extension, ".restext", StringComparison.OrdinalIgnoreCase) == 0)
			{
				return ResGen.Format.Text;
			}
			if (string.Compare(extension, ".resx", StringComparison.OrdinalIgnoreCase) == 0 || string.Compare(extension, ".resw", StringComparison.OrdinalIgnoreCase) == 0)
			{
				return ResGen.Format.XML;
			}
			if (string.Compare(extension, ".resources.dll", StringComparison.OrdinalIgnoreCase) == 0 || string.Compare(extension, ".dll", StringComparison.OrdinalIgnoreCase) == 0 || string.Compare(extension, ".exe", StringComparison.OrdinalIgnoreCase) == 0)
			{
				return ResGen.Format.Assembly;
			}
			if (string.Compare(extension, ".resources", StringComparison.OrdinalIgnoreCase) == 0)
			{
				return ResGen.Format.Binary;
			}
			ResGen.Error(string.Format("Unknown file extension \"{0}\" for file \"{1}\"", extension, filename));
			Environment.Exit(-1);
			return ResGen.Format.Text;
		}

		private static void RemoveCorruptedFile(string filename)
		{
			ResGen.Error(string.Format("Output file is possibly corrupt.  Deleting \"{0}\"", filename));
			try
			{
				File.Delete(filename);
			}
			catch (Exception)
			{
				ResGen.Error(string.Format("Could not delete possibly corrupted output file \"{0}\".", filename));
			}
		}

		private static void SetConsoleUICulture()
		{
			Thread currentThread = Thread.CurrentThread;
			currentThread.CurrentUICulture = CultureInfo.CurrentUICulture.GetConsoleFallbackUICulture();
			if (Console.OutputEncoding.CodePage != Encoding.UTF8.CodePage && Console.OutputEncoding.CodePage != currentThread.CurrentUICulture.TextInfo.OEMCodePage && Console.OutputEncoding.CodePage != currentThread.CurrentUICulture.TextInfo.ANSICodePage)
			{
				currentThread.CurrentUICulture = new CultureInfo("en-US");
			}
		}

		public static void Main(string[] args)
		{
			Environment.ExitCode = -1;
			ResGen.SetConsoleUICulture();
			if (args.Length < 1 || args[0].Equals("-h", StringComparison.OrdinalIgnoreCase) || args[0].Equals("-?", StringComparison.OrdinalIgnoreCase) || args[0].Equals("/h", StringComparison.OrdinalIgnoreCase) || args[0].Equals("/?", StringComparison.OrdinalIgnoreCase))
			{
				ResGen.Usage();
				return;
			}
			bool flag = false;
			List<string> list = new List<string>();
			int m = 0;
			while (m < args.Length)
			{
				string text = args[m];
				if (!text.StartsWith("@", StringComparison.OrdinalIgnoreCase))
				{
					list.Add(text);
					goto IL_1D5;
				}
				if (flag)
				{
					ResGen.Error("You specified multiple response files; at most one is allowed.");
					break;
				}
				if (text.Length == 1)
				{
					ResGen.Error(string.Format("You must specify response file names like this:\r\n@respFile.rsp\r\nYou passed in \"{0}\".", text));
					break;
				}
				string text2 = text.Substring(1);
				if (!ResGen.ValidResponseFileName(text2))
				{
					ResGen.Error(string.Format(ResGen.BadFileExtensionResourceString, new object[] {text2}));
					break;
				}
				if (!File.Exists(text2))
				{
					ResGen.Error(string.Format("The specified response file doesn't exist. You passed in \"{0}\".", text2));
					break;
				}
				flag = true;
				try
				{
					string[] array = File.ReadAllLines(text2);
					foreach (string text3 in array)
					{
						string text4 = text3.Trim();
						if (text4.Length != 0 && !text4.StartsWith("#", StringComparison.OrdinalIgnoreCase))
						{
							if (text4.StartsWith("/compile", StringComparison.OrdinalIgnoreCase) && text4.Length > 8)
							{
								ResGen.Error(string.Format("Response files must be line-delimited; \"{0}\" contains \"{1}\".", text2, text4));
								break;
							}
							list.Add(text4);
						}
					}
				}
				catch (Exception ex)
				{
					ResGen.Error(ex.Message, text2);
				}
				IL_1D5:
				m++;
			}
			string[] inFiles = null;
			string[] outFilesOrDirs = null;
			ResGen.ResourceClassOptions resourceClassOptions = null;
			int num = 0;
			bool flag2 = false;
			bool flag3 = false;
			bool useSourcePath = false;
			bool flag4 = true;
			bool simulateVS = false;
			while (num < list.Count && ResGen.errors == 0)
			{
				if (list[num].Equals("/compile", StringComparison.OrdinalIgnoreCase))
				{
					SortedSet<string> sortedSet = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
					inFiles = new string[list.Count - num - 1];
					outFilesOrDirs = new string[list.Count - num - 1];
					for (int k = 0; k < inFiles.Length; k++)
					{
						inFiles[k] = list[num + 1];
						int num2 = inFiles[k].IndexOf(',');
						if (num2 != -1)
						{
							string text5 = inFiles[k];
							inFiles[k] = text5.Substring(0, num2);
							if (!ResGen.ValidResourceFileName(inFiles[k]))
							{
								ResGen.Error(string.Format(ResGen.BadFileExtensionResourceString, inFiles[k]));
								break;
							}
							if (num2 == text5.Length - 1)
							{
								ResGen.Error(string.Format("You must specify an input & outfile file name like this:\r\ninFile.txt,outFile.resources.\r\nYou passed in \"{0}\".", text5));
								inFiles = new string[0];
								break;
							}
							outFilesOrDirs[k] = text5.Substring(num2 + 1);
							if (ResGen.GetFormat(inFiles[k]) == ResGen.Format.Assembly)
							{
								ResGen.Error("/compile is not supported with assemblies (.resources.dll, .dll or .exe) as input.\r\nUse ResGen /? for usage information.");
								break;
							}
							if (!ResGen.ValidResourceFileName(outFilesOrDirs[k]))
							{
								ResGen.Error(string.Format(ResGen.BadFileExtensionResourceString, outFilesOrDirs[k]));
								break;
							}
						}
						else if (!ResGen.ValidResourceFileName(inFiles[k]))
						{
							if (inFiles[k][0] == '/' || inFiles[k][0] == '-')
							{
								ResGen.Error(string.Format("Invalid command line syntax.  Switch: \"/compile\"  Bad value: \"{1}\".  Use ResGen /? for usage information.", inFiles[k]));
								break;
							}
							ResGen.Error(string.Format(ResGen.BadFileExtensionResourceString, inFiles[k]));
							break;
						}
						else
						{
							string resourceFileName = ResGen.GetResourceFileName(inFiles[k]);
							outFilesOrDirs[k] = resourceFileName;
						}
						string fullPath = Path.GetFullPath(outFilesOrDirs[k]);
						if (sortedSet.Contains(fullPath))
						{
							ResGen.Error(string.Format("Two output filenames resolved to the same output path: \"{0}\"", fullPath));
							break;
						}
						sortedSet.Add(fullPath);
						num++;
					}
				}
				else if (list[num].StartsWith("/str:", StringComparison.OrdinalIgnoreCase))
				{
					string text6 = list[num];
					int num3 = text6.IndexOf(',', 5);
					if (num3 == -1)
					{
						num3 = text6.Length;
					}
					string language = text6.Substring(5, num3 - 5);
					string nameSpace = null;
					string className = null;
					string outputFileName = null;
					int num4 = num3 + 1;
					if (num3 < text6.Length)
					{
						num3 = text6.IndexOf(',', num4);
						if (num3 == -1)
						{
							num3 = text6.Length;
						}
					}
					if (num4 <= num3)
					{
						nameSpace = text6.Substring(num4, num3 - num4);
						if (num3 < text6.Length)
						{
							num4 = num3 + 1;
							num3 = text6.IndexOf(',', num4);
							if (num3 == -1)
							{
								num3 = text6.Length;
							}
							className = text6.Substring(num4, num3 - num4);
						}
						num4 = num3 + 1;
						if (num4 < text6.Length)
						{
							outputFileName = text6.Substring(num4, text6.Length - num4);
						}
					}
					resourceClassOptions = new ResGen.ResourceClassOptions(language, nameSpace, className, outputFileName, flag4, simulateVS);
				}
				else if (list[num].StartsWith("/define:", StringComparison.OrdinalIgnoreCase) || list[num].StartsWith("-define:", StringComparison.OrdinalIgnoreCase) || list[num].StartsWith("/D:", StringComparison.OrdinalIgnoreCase) || list[num].StartsWith("-D:", StringComparison.OrdinalIgnoreCase) || list[num].StartsWith("/d:", StringComparison.OrdinalIgnoreCase) || list[num].StartsWith("-d:", StringComparison.OrdinalIgnoreCase))
				{
					string text7;
					if (list[num].StartsWith("/D:", StringComparison.OrdinalIgnoreCase) || list[num].StartsWith("-D:", StringComparison.OrdinalIgnoreCase) || list[num].StartsWith("/d:", StringComparison.OrdinalIgnoreCase) || list[num].StartsWith("-d:", StringComparison.OrdinalIgnoreCase))
					{
						text7 = list[num].Substring(3);
					}
					else
					{
						text7 = list[num].Substring(8);
					}
					foreach (string text8 in text7.Split(new char[]
					{
						','
					}))
					{
						if (text8.Length == 0 || text8.Contains("&") || text8.Contains("|") || text8.Contains("("))
						{
							ResGen.Error(string.Format("Found an invalid #ifdef value, \"{0}\".  ResGen supports very simple syntax currently, and doesn't include parentheses, || nor &&.", text8));
						}
						ResGen.definesList.Add(text8);
					}
				}
				else
				{
					if (list[num].StartsWith("/r:", StringComparison.OrdinalIgnoreCase) || list[num].StartsWith("-r:", StringComparison.OrdinalIgnoreCase))
					{
						string text9 = list[num];
						text9 = text9.Substring(3);
						if (ResGen.assemblyList == null)
						{
							ResGen.assemblyList = new List<AssemblyName>();
						}
						try
						{
							ResGen.assemblyList.Add(AssemblyName.GetAssemblyName(text9));
						}
						catch (Exception ex2)
						{
							ResGen.Error(string.Format("Could not load referenced assembly \"{0}\".  Caught a {1} saying \"{2}\".", new object[] {text9, ex2.GetType().Name, ex2.Message}));
							
						}
						goto IL_A40;
					}
					if (list[num].Equals("/usesourcepath", StringComparison.OrdinalIgnoreCase) || list[num].Equals("-usesourcepath", StringComparison.OrdinalIgnoreCase))
					{
						useSourcePath = true;
					}
					else if (list[num].Equals("/publicclass", StringComparison.OrdinalIgnoreCase) || list[num].Equals("-publicclass", StringComparison.OrdinalIgnoreCase))
					{
						flag4 = false;
					}
					else if (list[num].Equals("/AllowUntrustedFiles", StringComparison.OrdinalIgnoreCase) || list[num].Equals("-AllowUntrustedFiles", StringComparison.OrdinalIgnoreCase))
					{
						ResGen.allowMOTW = true;
					}
					else if (ResGen.ValidResourceFileName(list[num]))
					{
						if (!flag2)
						{
							inFiles = new string[1];
							inFiles[0] = list[num];
							outFilesOrDirs = new string[1];
							if (ResGen.GetFormat(inFiles[0]) == ResGen.Format.Assembly)
							{
								outFilesOrDirs[0] = null;
							}
							else
							{
								outFilesOrDirs[0] = ResGen.GetResourceFileName(inFiles[0]);
							}
							flag2 = true;
						}
						else
						{
							if (flag3)
							{
								ResGen.Error(string.Format("Invalid command line syntax.  Switch: \"<none>\"  Bad value: \"{0}\".  Use ResGen /? for usage information.", list[num]));
								break;
							}
							outFilesOrDirs[0] = list[num];
							if (ResGen.GetFormat(inFiles[0]) == ResGen.Format.Assembly)
							{
								if (ResGen.ValidResourceFileName(outFilesOrDirs[0]))
								{
									ResGen.Warning(string.Format("When specifying an assembly (.resources.dll, .dll or .exe) as input, an output directory must be specified.\r\n{0} appears to be an output filename but will be treated as a directory name.\r\nUse ResGen /? for usage information.", outFilesOrDirs[0]));
								}
								if (!Directory.Exists(outFilesOrDirs[0]))
								{
									ResGen.Error(string.Format("The specified output directory {0} does not exist.", outFilesOrDirs[0]));
								}
							}
							flag3 = true;
						}
					}
					else if (flag2 && !flag3 && ResGen.GetFormat(inFiles[0]) == ResGen.Format.Assembly)
					{
						outFilesOrDirs[0] = list[num];
						if (!Directory.Exists(outFilesOrDirs[0]))
						{
							ResGen.Error(string.Format("The specified output directory {0} does not exist.", outFilesOrDirs[0]));
						}
						flag3 = true;
					}
					else
					{
						if (list[num][0] == '/' || list[num][0] == '-')
						{

							ResGen.Error(string.Format("Unrecognized switch: \"{0}\".  Use ResGen /? for usage information.", list[num]));
							return;
						}
						ResGen.Error(string.Format(ResGen.BadFileExtensionResourceString, new object[] {list[num]}));
						return;
					}
				}
				IL_A40:
				num++;
			}
			if ((inFiles == null || inFiles.Length == 0) && ResGen.errors == 0)
			{
				ResGen.Usage();
				return;
			}
			if (resourceClassOptions != null)
			{
				resourceClassOptions.InternalClass = flag4;
				if (inFiles.Length > 1 && (resourceClassOptions.ClassName != null || resourceClassOptions.OutputFileName != null))
				{
					ResGen.Error("Cannot use /compile & /str simultaneously if you specify a class name or an output file name to the /str switch as well as multiple input files to /compile.  You would end up with duplicate classes or overwrite one of your classes.");
				}
				if (ResGen.GetFormat(inFiles[0]) == ResGen.Format.Assembly)
				{
					ResGen.Error("/str is not supported with assemblies (.resources.dll, .dll or .exe) as input.\r\nUse ResGen /? for usage information.");
				}
			}
			try
			{
				object value = Registry.GetValue("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\.NETFramework\\SDK", "AllowProcessOfUntrustedResourceFiles", null);
				if (value is string)
				{
					ResGen.allowMOTW = ((string)value).Equals("true", StringComparison.OrdinalIgnoreCase);
				}
			}
			catch
			{
			}
			if (ResGen.errors == 0)
			{
				Parallel.For(0, inFiles.Length, delegate(int i)
				{
					ResGen.ResGenRunner resGenRunner = new ResGen.ResGenRunner();
					resGenRunner.ProcessFile(inFiles[i], outFilesOrDirs[i], resourceClassOptions, useSourcePath);
				});
			}
			if (ResGen.warnings != 0)
			{
				Console.Error.WriteLine(string.Format("{0} warnings(s).", ResGen.warnings));
			}
			if (ResGen.errors != 0)
			{
				Console.Error.WriteLine(string.Format("{0} error(s).", ResGen.errors));
				return;
			}
			Environment.ExitCode = 0;
		}

		private static string GetResourceFileName(string inFile)
		{
			if (inFile == null)
			{
				return null;
			}
			int num = inFile.LastIndexOf('.');
			if (num == -1)
			{
				return null;
			}
			return inFile.Substring(0, num) + ".resources";
		}

		private static bool ValidResourceFileName(string inFile)
		{
			return inFile != null && (inFile.EndsWith(".resx", StringComparison.OrdinalIgnoreCase) || inFile.EndsWith(".txt", StringComparison.OrdinalIgnoreCase) || inFile.EndsWith(".restext", StringComparison.OrdinalIgnoreCase) || inFile.EndsWith(".resources.dll", StringComparison.OrdinalIgnoreCase) || inFile.EndsWith(".dll", StringComparison.OrdinalIgnoreCase) || inFile.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) || inFile.EndsWith(".resources", StringComparison.OrdinalIgnoreCase));
		}

		private static bool ValidResponseFileName(string inFile)
		{
			return inFile != null && inFile.EndsWith(".rsp", StringComparison.OrdinalIgnoreCase);
		}

		private static bool IfdefsAreActive(IEnumerable<string> searchForAll, IList<string> defines)
		{
			foreach (string text in searchForAll)
			{
				if (text[0] == '!')
				{
					if (defines.Contains(text.Substring(1)))
					{
						return false;
					}
				}
				else if (!defines.Contains(text))
				{
					return false;
				}
			}
			return true;
		}

		private static void Usage()
		{
			Console.WriteLine("Microsoft (R) .NET Resource Generator \r\n[Microsoft .Net Framework, Version 4.8.3928.0]\r\nCopyright (C) Microsoft Corporation.  All rights reserved.\r\n\r\nUsage:\r\n   ResGen inputFile.ext [outputFile.ext] [/str:lang[,namespace[,class[,file]]]]\r\n   ResGen [options] /compile inputFile1.ext[,outputFile1.resources] [...]\r\n   ResGen inputFile.ext2 [outputDirectory]\r\nWhere .ext is .resX, .restext, .txt or .resources\r\nand .ext2 is .resources.dll, .dll or .exe. outputDirectory must already exist.\r\nResources will be extracted under outputDirectory in resW format.\r\n\r\nConverts files from one resource format to another.  If the output\r\nfilename is not specified, inputFile.resources will be used.\r\nOptions:\r\n/compile        Converts a list of resource files from one format to another\r\n                in one bulk operation.  By default, it converts into .resources\r\n                files, using inputFile[i].resources for the output file name.\r\n/str:<language>[,<namespace>[,<class name>[,<file name>]]]] \r\n                Creates a strongly-typed resource class in the specified\r\n                programming language using CodeDOM. In order for the strongly\r\n                typed resource class to work properly, the name of your output \r\n                file without the .resources must match the\r\n                [namespace.]classname of your strongly typed resource class.\r\n                You may need to rename your output file before using it or\r\n                embedding it into an assembly. \r\n/useSourcePath  Use each source file's directory as the current directory\r\n                for resolving relative file paths.\r\n/publicClass    Create the strongly typed resource class as a public class.\r\n                This option is ignored if the /str: option is not used.\r\n/r:<assembly>   Load types from these assemblies. A ResX file with a previous\r\n                version of a type will use the one in this assembly, when set.\r\n/define:A[,B]   For #ifdef support in .ResText files, pass a comma-separated\r\n                list of symbols.  ResText files can use \"#ifdef A\" or \"#if !B\".\r\n/allowUntrustedFiles\r\n                Process files that are in the Internet or Restricted zone or\r\n                have the mark of the web on the file.\r\n\r\nMiscellaneous:\r\n@<file>         Read response file for more options. At most one response file\r\n                may be specified, and its entries must be line-separated.\r\n\r\n.restext & .txt files have this format:\r\n\r\n    # Use # at the beginning of a line for a comment character.\r\n    name=value\r\n    more elaborate name=value\r\n\r\nExample response file contents: \r\n\r\n    # Use # at the beginning of a line for a comment character.\r\n    /useSourcePath\r\n    /compile\r\n    file1.resx,file1.resources\r\n    file2.resx,file2.resources\r\n\r\n");
			Console.WriteLine("Language names valid for the /str:<language> option are:");
			CompilerInfo[] allCompilerInfo = CodeDomProvider.GetAllCompilerInfo();
			for (int i = 0; i < allCompilerInfo.Length; i++)
			{
				string[] languages = allCompilerInfo[i].GetLanguages();
				if (i != 0)
				{
					Console.Write(", ");
				}
				for (int j = 0; j < languages.Length; j++)
				{
					if (j != 0)
					{
						Console.Write(", ");
					}
					Console.Write(languages[j]);
				}
			}
			Console.WriteLine();
		}

		private const int errorCode = -1;

		private static int errors = 0;

		private static int warnings = 0;

		private static bool allowMOTW = false;

		private static List<AssemblyName> assemblyList;

		private static List<string> definesList = new List<string>();

		private static readonly object consoleOutputLock = new object();

		private static string BadFileExtensionResourceString = "The file named \"{0}\" does not have a known extension.  Managed resource files must end in .ResX, .restext, .txt, .resources, .resources.dll, .dll or .exe. Response files must end in .rsp and be specified as @respFile.rsp.";

		internal sealed class ResourceClassOptions
		{
			internal ResourceClassOptions(string language, string nameSpace, string className, string outputFileName, bool isClassInternal, bool simulateVS)
			{
				this._language = language;
				this._nameSpace = nameSpace;
				this._className = className;
				this._outputFileName = outputFileName;
				this._internalClass = isClassInternal;
				this._simulateVS = simulateVS;
			}

			internal string Language
			{
				get
				{
					return this._language;
				}
			}

			internal string NameSpace
			{
				get
				{
					return this._nameSpace;
				}
			}

			internal string ClassName
			{
				get
				{
					return this._className;
				}
			}

			internal string OutputFileName
			{
				get
				{
					return this._outputFileName;
				}
			}

			internal bool InternalClass
			{
				get
				{
					return this._internalClass;
				}
				set
				{
					this._internalClass = value;
				}
			}

			internal bool SimulateVS
			{
				get
				{
					return this._simulateVS;
				}
				set
				{
					this._simulateVS = value;
				}
			}

			private string _language;

			private string _nameSpace;

			private string _className;

			private string _outputFileName;

			private bool _internalClass;

			private bool _simulateVS;
		}

		internal sealed class LineNumberStreamReader : StreamReader
		{
			internal LineNumberStreamReader(string fileName, Encoding encoding, bool detectEncoding) : base(fileName, encoding, detectEncoding)
			{
				this._lineNumber = 1;
				this._col = 0;
			}

			internal LineNumberStreamReader(Stream stream) : base(stream)
			{
				this._lineNumber = 1;
				this._col = 0;
			}

			public override int Read()
			{
				int num = base.Read();
				if (num != -1)
				{
					this._col++;
					if (num == 10)
					{
						this._lineNumber++;
						this._col = 0;
					}
				}
				return num;
			}

			public override int Read([In] [Out] char[] chars, int index, int count)
			{
				int num = base.Read(chars, index, count);
				for (int i = 0; i < num; i++)
				{
					if (chars[i + index] == '\n')
					{
						this._lineNumber++;
						this._col = 0;
					}
					else
					{
						this._col++;
					}
				}
				return num;
			}

			public override string ReadLine()
			{
				string text = base.ReadLine();
				if (text != null)
				{
					this._lineNumber++;
					this._col = 0;
				}
				return text;
			}

			public override string ReadToEnd()
			{
				throw new NotImplementedException("NYI");
			}

			internal int LineNumber
			{
				get
				{
					return this._lineNumber;
				}
			}

			internal int LinePosition
			{
				get
				{
					return this._col;
				}
			}

			private int _lineNumber;

			private int _col;
		}

		internal sealed class TextFileException : Exception
		{
			internal TextFileException(string message, string fileName, int lineNumber, int linePosition) : base(message)
			{
				this._fileName = fileName;
				this._lineNumber = lineNumber;
				this._column = linePosition;
			}

			internal string FileName
			{
				get
				{
					return this._fileName;
				}
			}

			internal int LineNumber
			{
				get
				{
					return this._lineNumber;
				}
			}

			internal int LinePosition
			{
				get
				{
					return this._column;
				}
			}

			private string _fileName;

			private int _lineNumber;

			private int _column;
		}

		private class ResGenRunner
		{
			private void AddResource(ResGen.ResGenRunner.ReaderInfo reader, string name, object value, string inputFileName, int lineNumber, int linePosition)
			{
				ResGen.Entry value2 = new ResGen.Entry(name, value);
				if (reader.resourcesHashTable.ContainsKey(name))
				{
					this.Warning(string.Format("Duplicate resource key!  Name was: \"{0}\"", name), inputFileName, lineNumber, linePosition);
					return;
				}
				reader.resources.Add(value2);
				reader.resourcesHashTable.Add(name, value);
			}

			private void AddResource(ResGen.ResGenRunner.ReaderInfo reader, string name, object value, string inputFileName)
			{
				ResGen.Entry value2 = new ResGen.Entry(name, value);
				if (reader.resourcesHashTable.ContainsKey(name))
				{
					this.Warning(string.Format("Duplicate resource key!  Name was: \"{0}\"", name), inputFileName);
					return;
				}
				reader.resources.Add(value2);
				reader.resourcesHashTable.Add(name, value);
			}

			private void Error(string message)
			{
				this.Error(message, 0);
			}

			private void Error(string message, int errorNumber)
			{
				string formatString = "ResGen : error RG{1:0000}: {0}";
				this.BufferErrorLine(formatString, new object[] {message, errorNumber});
				Interlocked.Increment(ref ResGen.errors);
				this.hadErrors = true;
			}

			private void Error(string message, string fileName)
			{
				this.Error(message, fileName, 0);
			}

			private void Error(string message, string fileName, int errorNumber)
			{
				string formatString = "{0} : error RG{1:0000}: {2}";
				this.BufferErrorLine(formatString, new object[] {fileName, errorNumber, message});
				Interlocked.Increment(ref ResGen.errors);
				this.hadErrors = true;
			}

			private void Error(string message, string fileName, int line, int column)
			{
				this.Error(message, fileName, line, column, 0);
			}

			private void Error(string message, string fileName, int line, int column, int errorNumber)
			{
				string formatString = "{0}({1},{2}): error RG{3:0000}: {4}";
				this.BufferErrorLine(formatString, new object[] {fileName, line, column, errorNumber, message});
				Interlocked.Increment(ref ResGen.errors);
				this.hadErrors = true;
			}

			private void Warning(string message)
			{
				string formatString = "ResGen : warning RG0000 : {0}";
				this.BufferErrorLine(formatString, new object[] {message});
				Interlocked.Increment(ref ResGen.warnings);
			}

			private void Warning(string message, string fileName)
			{
				this.Warning(message, fileName, 0);
			}

			private void Warning(string message, string fileName, int warningNumber)
			{
				string formatString = "{0} : warning RG{1:0000}: {2}";
				this.BufferErrorLine(formatString, new object[] {fileName, warningNumber, message});
				Interlocked.Increment(ref ResGen.warnings);
			}

			private void Warning(string message, string fileName, int line, int column)
			{
				this.Warning(message, fileName, line, column, 0);
			}

			private void Warning(string message, string fileName, int line, int column, int warningNumber)
			{
				string formatString = "{0}({1},{2}): warning RG{3:0000}: {4}";
				this.BufferErrorLine(formatString, new object[] {fileName, line, column, warningNumber, message});
				Interlocked.Increment(ref ResGen.warnings);
			}

			private void BufferErrorLine(string formatString, params object[] args)
			{
				this.bufferedOutput.Add(delegate
				{
					Console.Error.WriteLine(formatString, args);
				});
			}

			private void BufferWriteLine()
			{
				this.BufferWriteLine("", new object[0]);
			}

			private void BufferWriteLine(string formatString, params object[] args)
			{
				this.bufferedOutput.Add(delegate
				{
					Console.WriteLine(formatString, args);
				});
			}

			private void BufferWrite(string formatString, params object[] args)
			{
				this.bufferedOutput.Add(delegate
				{
					Console.Write(formatString, args);
				});
			}

			public void ProcessFile(string inFile, string outFileOrDir, ResGen.ResourceClassOptions resourceClassOptions, bool useSourcePath)
			{
				this.ProcessFileWorker(inFile, outFileOrDir, resourceClassOptions, useSourcePath);
				object consoleOutputLock = ResGen.consoleOutputLock;
				lock (consoleOutputLock)
				{
					foreach (Action action in this.bufferedOutput)
					{
						action();
					}
				}
				if (this.hadErrors && outFileOrDir != null && File.Exists(outFileOrDir) && ResGen.GetFormat(inFile) != ResGen.Format.Assembly && ResGen.GetFormat(outFileOrDir) != ResGen.Format.Assembly)
				{
					GC.Collect(2);
					GC.WaitForPendingFinalizers();
					try
					{
						File.Delete(outFileOrDir);
					}
					catch
					{
					}
				}
			}

			public void ProcessFileWorker(string inFile, string outFileOrDir, ResGen.ResourceClassOptions resourceClassOptions, bool useSourcePath)
			{
				try
				{
					if (!File.Exists(inFile))
					{
						this.Error(string.Format("Couldn't find input file \"{0}\"", inFile));
						return;
					}
					if (ResGen.GetFormat(inFile) != ResGen.Format.Assembly && ResGen.GetFormat(outFileOrDir) == ResGen.Format.Assembly)
					{
						this.Error(string.Format("ResGen cannot write assemblies, only read from them. Cannot create assembly \"{0}\".", outFileOrDir));
						return;
					}
					if (!this.ReadResources(inFile, useSourcePath))
					{
						return;
					}
				}
				catch (ArgumentException ex)
				{
					if (ex.InnerException is XmlException)
					{
						XmlException ex2 = (XmlException)ex.InnerException;
						this.Error(ex2.Message, inFile, ex2.LineNumber, ex2.LinePosition);
					}
					else
					{
						this.Error(ex.Message, inFile);
					}
					return;
				}
				catch (ResGen.TextFileException ex3)
				{
					this.Error(ex3.Message, ex3.FileName, ex3.LineNumber, ex3.LinePosition);
					return;
				}
				catch (XmlException ex4)
				{
					this.Error(ex4.Message, inFile, ex4.LineNumber, ex4.LinePosition);
					return;
				}
				catch (Exception ex5)
				{
					this.Error(ex5.Message, inFile);
					if (ex5.InnerException != null)
					{
						Exception innerException = ex5.InnerException;
						StringBuilder stringBuilder = new StringBuilder(200);
						stringBuilder.Append(ex5.Message);
						while (innerException != null)
						{
							stringBuilder.Append(" ---> ");
							stringBuilder.Append(innerException.GetType().Name);
							stringBuilder.Append(": ");
							stringBuilder.Append(innerException.Message);
							innerException = innerException.InnerException;
						}
						this.Error(string.Format("Specific exception: \"{0}\"  Message: \"{1}\"", new object[] {ex5.InnerException.GetType().Name, stringBuilder.ToString()}), inFile);
					}
					return;
				}
				string text = null;
				string text2 = null;
				string text3 = null;
				bool flag = true;
				try
				{
					if (ResGen.GetFormat(inFile) == ResGen.Format.Assembly)
					{
						using (List<ResGen.ResGenRunner.ReaderInfo>.Enumerator enumerator = this.readers.GetEnumerator())
						{
							while (enumerator.MoveNext())
							{
								ResGen.ResGenRunner.ReaderInfo readerInfo = enumerator.Current;
								string text4 = readerInfo.outputFileName + ".resw";
								text = null;
								flag = true;
								text2 = Path.Combine(outFileOrDir ?? string.Empty, readerInfo.cultureName ?? string.Empty);
								if (text2.Length == 0)
								{
									text = text4;
								}
								else
								{
									if (!Directory.Exists(text2))
									{
										flag = false;
										Directory.CreateDirectory(text2);
									}
									text = Path.Combine(text2, text4);
								}
								this.WriteResources(readerInfo, text);
							}
						}
					}
					else {
						text = outFileOrDir;
						this.WriteResources(this.readers[0], outFileOrDir);
						if (resourceClassOptions != null)
						{
							this.CreateStronglyTypedResources(this.readers[0], outFileOrDir, resourceClassOptions, inFile, out text3);
						}
					}
				}
				catch (IOException ex6)
				{
					if (text != null)
					{
						this.Error(string.Format("Couldn't write output file \"{0}\"", text), text);
						if (ex6.Message != null)
						{
							this.Error(string.Format("Specific exception: \"{0}\"  Message: \"{1}\"", new object[] {ex6.GetType().Name, ex6.Message}), text);
						}
						if (File.Exists(text) && ResGen.GetFormat(text) != ResGen.Format.Assembly)
						{
							ResGen.RemoveCorruptedFile(text);
							if (text3 != null)
							{
								ResGen.RemoveCorruptedFile(text3);
							}
						}
					}
					if (text2 != null && !flag)
					{
						try
						{
							Directory.Delete(text2);
						}
						catch (Exception)
						{
						}
					}
				}
				catch (Exception ex7)
				{
					if (text != null)
					{
						this.Error(string.Format("Error while writing the output file \"{0}\"", text));
					}
					if (ex7.Message != null)
					{
						this.Error(string.Format("Specific exception: \"{0}\"  Message: \"{1}\"", new object[] {ex7.GetType().Name, ex7.Message}));
					}
				}
			}

			private void CreateStronglyTypedResources(ResGen.ResGenRunner.ReaderInfo reader, string outFile, ResGen.ResourceClassOptions options, string inputFileName, out string sourceFile)
			{
				CodeDomProvider codeDomProvider = CodeDomProvider.CreateProvider(options.Language);
				string text = outFile.Substring(0, outFile.LastIndexOf('.'));
				int num = text.LastIndexOfAny(new char[]
				{
					Path.VolumeSeparatorChar,
					Path.DirectorySeparatorChar,
					Path.AltDirectorySeparatorChar
				});
				if (num != -1)
				{
					text = text.Substring(num + 1);
				}
				string nameSpace = options.NameSpace;
				string text2 = options.ClassName;
				if (string.IsNullOrEmpty(text2))
				{
					text2 = text;
				}
				sourceFile = options.OutputFileName;
				if (string.IsNullOrEmpty(sourceFile))
				{
					string str = outFile.Substring(0, outFile.LastIndexOf('.'));
					sourceFile = str + "." + codeDomProvider.FileExtension;
				}
				string[] array = null;
				string text3 = StronglyTypedResourceBuilder.VerifyResourceName(text2, codeDomProvider);
				if (text3 != null)
				{
					text2 = text3;
				}
				string text4;
				if (string.IsNullOrEmpty(nameSpace))
				{
					text4 = text2;
				}
				else
				{
					text4 = nameSpace + "." + text2;
				}
				this.BufferWrite("Creating strongly typed resource class \"{0}\"...  ", text4);
				if (!text.Equals(text4, StringComparison.OrdinalIgnoreCase) && outFile.EndsWith(".resources", StringComparison.OrdinalIgnoreCase))
				{
					this.BufferWriteLine();
					this.Warning(string.Format("The base name of your output file, \"{0}\", does not match the base name used by the strongly typed resources, \"{1}\".  In order for the strongly typed resources to work correctly, you will need to rename your output file to \"{1}.resources\".", text, text4), inputFileName);
				}
				IDictionary resourcesHashTable = reader.resourcesHashTable;
				CodeCompileUnit codeCompileUnit = StronglyTypedResourceBuilder.Create(resourcesHashTable, text2, nameSpace, codeDomProvider, options.InternalClass, out array);
				codeCompileUnit.ReferencedAssemblies.Add("System.dll");
				CodeGeneratorOptions options2 = new CodeGeneratorOptions();
				UTF8Encoding encoding = new UTF8Encoding(true, true);
				using (TextWriter textWriter = new StreamWriter(sourceFile, false, encoding))
				{
					codeDomProvider.GenerateCodeFromCompileUnit(codeCompileUnit, textWriter, options2);
				}
				if (array.Length != 0)
				{
					this.BufferWriteLine();
					foreach (string text5 in array)
					{
						this.Error(string.Format("Could not create a property on the strongly typed resource class for the resource name \"{0}\".", text5), inputFileName);
					}
					return;
				}
				this.BufferWriteLine("Done.", new object[0]);
			}

			private bool IsDangerous(string filename)
			{
				if (ResGen.allowMOTW)
				{
					return false;
				}
				if (this.internetSecurityManager == null)
				{
					Type typeFromCLSID = Type.GetTypeFromCLSID(new Guid("7b8a2d94-0ac9-11d1-896c-00c04fb6bfc4"));
					this.internetSecurityManager = (IInternetSecurityManager)Activator.CreateInstance(typeFromCLSID);
				}
				int num = 0;
				this.internetSecurityManager.MapUrlToZone(Path.GetFullPath(filename), out num, 0);
				if ((long)num < 3L)
				{
					return false;
				}
				bool result = true;
				if (ResGen.GetFormat(filename) == ResGen.Format.XML)
				{
					result = false;
					FileStream fileStream = new FileStream(filename, FileMode.Open, FileAccess.Read, FileShare.Read);
					XmlTextReader xmlTextReader = new XmlTextReader(fileStream);
					xmlTextReader.DtdProcessing = DtdProcessing.Ignore;
					xmlTextReader.XmlResolver = null;
					try
					{
						while (xmlTextReader.Read())
						{
							if (xmlTextReader.NodeType == XmlNodeType.Element)
							{
								string localName = xmlTextReader.LocalName;
								if (xmlTextReader.LocalName.Equals("data"))
								{
									if (xmlTextReader["mimetype"] != null)
									{
										result = true;
									}
								}
								else if (xmlTextReader.LocalName.Equals("metadata") && xmlTextReader["mimetype"] != null)
								{
									result = true;
								}
							}
						}
					}
					catch
					{
						result = true;
					}
					fileStream.Close();
					xmlTextReader.Close();
				}
				return result;
			}

			private bool ReadResources(string filename, bool useSourcePath)
			{
				ResGen.Format format = ResGen.GetFormat(filename);
				if (format == ResGen.Format.Assembly)
				{
					if (this.IsDangerous(filename))
					{
						this.Error(string.Format("Couldn't process file {0} due to being in the Internet or Restricted zone or having the mark of the web on the file, use /allowUntrustedFiles if you want to process these files.", filename));
						return false;
					}
					this.ReadAssemblyResources(filename);
				}
				else
				{
					ResGen.ResGenRunner.ReaderInfo readerInfo = new ResGen.ResGenRunner.ReaderInfo();
					this.readers.Add(readerInfo);
					switch (format)
					{
					case ResGen.Format.Text:
						this.ReadTextResources(readerInfo, filename);
						break;
					case ResGen.Format.XML:
					{
						if (this.IsDangerous(filename))
						{
							this.Error(string.Format("Couldn't process file {0} due to being in the Internet or Restricted zone or having the mark of the web on the file, use /allowUntrustedFiles if you want to process these files.", filename));
							return false;
						}
						ResXResourceReader resXResourceReader;
						if (ResGen.assemblyList != null)
						{
							resXResourceReader = new ResXResourceReader(filename, ResGen.assemblyList.ToArray());
						}
						else
						{
							resXResourceReader = new ResXResourceReader(filename);
						}
						if (useSourcePath)
						{
							string fullPath = Path.GetFullPath(filename);
							resXResourceReader.BasePath = Path.GetDirectoryName(fullPath);
						}
						this.ReadResources(readerInfo, resXResourceReader, filename);
						break;
					}
					case ResGen.Format.Binary:
						if (this.IsDangerous(filename))
						{
							this.Error(string.Format("Couldn't process file {0} due to being in the Internet or Restricted zone or having the mark of the web on the file, use /allowUntrustedFiles if you want to process these files.", filename));
							return false;
						}
						this.ReadResources(readerInfo, new ResourceReader(filename), filename);
						break;
					}
					this.BufferWriteLine(string.Format("Read in {0} resources from \"{1}\"", readerInfo.resources.Count, filename), new object[0]);
				}
				return true;
			}

			private void ReadResources(ResGen.ResGenRunner.ReaderInfo readerInfo, IResourceReader reader, string fileName)
			{
				try
				{
					IDictionaryEnumerator enumerator = reader.GetEnumerator();
					while (enumerator.MoveNext())
					{
						string name = (string)enumerator.Key;
						object value = enumerator.Value;
						this.AddResource(readerInfo, name, value, fileName);
					}
				}
				finally
				{
					if (reader != null)
					{
						reader.Dispose();
					}
				}
			}

			private void ReadTextResources(ResGen.ResGenRunner.ReaderInfo reader, string fileName)
			{
				Stack<string> stack = new Stack<string>();
				bool flag = false;
				using (ResGen.LineNumberStreamReader lineNumberStreamReader = new ResGen.LineNumberStreamReader(fileName, new UTF8Encoding(true), true))
				{
					StringBuilder stringBuilder = new StringBuilder(40);
					StringBuilder stringBuilder2 = new StringBuilder(120);
					int num = lineNumberStreamReader.Read();
					while (num != -1)
					{
						if (num == 10 || num == 13)
						{
							num = lineNumberStreamReader.Read();
						}
						else if (num == 35)
						{
							string text = lineNumberStreamReader.ReadLine();
							if (string.IsNullOrEmpty(text))
							{
								num = lineNumberStreamReader.Read();
							}
							else
							{
								if (text.StartsWith("ifdef ", StringComparison.InvariantCulture) || text.StartsWith("ifndef ", StringComparison.InvariantCulture) || text.StartsWith("if ", StringComparison.InvariantCulture) || text.StartsWith("If ", StringComparison.InvariantCulture))
								{
									string text2 = text.Substring(text.IndexOf(' ') + 1).Trim();
									for (int i = 0; i < text2.Length; i++)
									{
										if (text2[i] == '#' || text2[i] == ';')
										{
											text2 = text2.Substring(0, i).Trim();
											break;
										}
									}
									if (text[0] == 'I' && text2.EndsWith(" Then", StringComparison.InvariantCulture))
									{
										text2 = text2.Substring(0, text2.Length - 5);
									}
									if (text2.Length == 0 || text2.Contains("&") || text2.Contains("|") || text2.Contains("("))
									{
										throw new ResGen.TextFileException(string.Format("Found an invalid #ifdef value, \"{0}\".  ResGen supports very simple syntax currently, and doesn't include parentheses, || nor &&.", text2), fileName, lineNumberStreamReader.LineNumber - 1, 7);
									}
									if (text.StartsWith("ifndef", StringComparison.InvariantCulture))
									{
										text2 = "!" + text2;
									}
									stack.Push(text2);
									flag = !ResGen.IfdefsAreActive(stack, ResGen.definesList);
								}
								else if (text.StartsWith("endif", StringComparison.InvariantCulture) || text.StartsWith("End If", StringComparison.InvariantCulture))
								{
									if (stack.Count == 0)
									{
										throw new ResGen.TextFileException("Found an #endif without a matching #ifdef.", fileName, lineNumberStreamReader.LineNumber - 1, 1);
									}
									stack.Pop();
									flag = !ResGen.IfdefsAreActive(stack, ResGen.definesList);
								}
								num = lineNumberStreamReader.Read();
							}
						}
						else if (flag || num == 9 || num == 32 || num == 59)
						{
							lineNumberStreamReader.ReadLine();
							num = lineNumberStreamReader.Read();
						}
						else if (num == 91)
						{
							string text3 = lineNumberStreamReader.ReadLine();
							if (!text3.Equals("strings]", StringComparison.OrdinalIgnoreCase))
							{
								throw new ResGen.TextFileException(string.Format("Unexpected INF file bracket syntax - ResGen does not support text in square brackets.  Bad text: \"[{0}\".", text3), fileName, lineNumberStreamReader.LineNumber - 1, 1);
							}
							this.Warning("The \"[strings]\" tag is no longer necessary in your text files.  Please remove it.", fileName, lineNumberStreamReader.LineNumber - 1, 1);
							num = lineNumberStreamReader.Read();
						}
						else
						{
							stringBuilder.Length = 0;
							while (num != 61)
							{
								if (num == 13 || num == 10)
								{
									throw new ResGen.TextFileException(string.Format("Found a resource that had a new line in it, but couldn't find the equal sign within!  Length: {0}  name: '{1}'.", stringBuilder.Length, stringBuilder), fileName, lineNumberStreamReader.LineNumber, lineNumberStreamReader.LinePosition);
								}
								stringBuilder.Append((char)num);
								num = lineNumberStreamReader.Read();
								if (num == -1)
								{
									break;
								}
							}
							if (stringBuilder.Length == 0)
							{
								throw new ResGen.TextFileException("Found an equals sign at beginning of a line!  Expected a name / value pair like 'name = value'", fileName, lineNumberStreamReader.LineNumber, lineNumberStreamReader.LinePosition);
							}
							if (stringBuilder[stringBuilder.Length - 1] == ' ')
							{
								stringBuilder.Length--;
							}
							num = lineNumberStreamReader.Read();
							if (num == 32)
							{
								num = lineNumberStreamReader.Read();
							}
							stringBuilder2.Length = 0;
							while (num != -1)
							{
								bool flag2 = false;
								if (num == 92)
								{
									num = lineNumberStreamReader.Read();
									if (num <= 92)
									{
										if (num == 34 || num == 92)
										{
											goto IL_4DC;
										}
									}
									else
									{
										if (num == 110)
										{
											num = 10;
											flag2 = true;
											goto IL_4DC;
										}
										switch (num)
										{
										case 114:
											num = 13;
											flag2 = true;
											goto IL_4DC;
										case 116:
											num = 9;
											goto IL_4DC;
										case 117:
										{
											char[] array = new char[4];
											int j = 4;
											int num2 = 0;
											while (j > 0)
											{
												int num3 = lineNumberStreamReader.Read(array, num2, j);
												if (num3 == 0)
												{
													throw new ResGen.TextFileException(string.Format("Unsupported or invalid escape character in value!  Escape char: '{0}' Name was: \"{1}\"", (char)num, stringBuilder.ToString()), fileName, lineNumberStreamReader.LineNumber, lineNumberStreamReader.LinePosition);
												}
												num2 += num3;
												j -= num3;
											}
											num = (int)ushort.Parse(new string(array), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
											flag2 = (num == 10 || num == 13);
											goto IL_4DC;
										}
										}
									}
									throw new ResGen.TextFileException(string.Format("Unsupported or invalid escape character in value!  Escape char: '{0}' Name was: \"{1}\"", (char)num, stringBuilder.ToString()), fileName, lineNumberStreamReader.LineNumber, lineNumberStreamReader.LinePosition);
								}
								IL_4DC:
								if (!flag2)
								{
									if (num == 13)
									{
										num = lineNumberStreamReader.Read();
										if (num == -1)
										{
											break;
										}
									}
									if (num == 10)
									{
										num = lineNumberStreamReader.Read();
										break;
									}
								}
								stringBuilder2.Append((char)num);
								num = lineNumberStreamReader.Read();
							}
							this.AddResource(reader, stringBuilder.ToString(), stringBuilder2.ToString(), fileName, lineNumberStreamReader.LineNumber, lineNumberStreamReader.LinePosition);
						}
					}
					if (stack.Count > 0)
					{
						throw new ResGen.TextFileException(string.Format("Found an #ifdef but not a matching #endif before reaching the end of the file.  Unmatched #ifdef: \"{0}\".", stack.Pop()), fileName, lineNumberStreamReader.LineNumber - 1, 1);
					}
				}
			}

			private void WriteResources(ResGen.ResGenRunner.ReaderInfo reader, string filename)
			{
				switch (ResGen.GetFormat(filename))
				{
				case ResGen.Format.Text:
					this.WriteTextResources(reader, filename);
					return;
				case ResGen.Format.XML:
					this.WriteResources(reader, new ResXResourceWriter(filename));
					return;
				case ResGen.Format.Assembly:
					this.Error(string.Format("ResGen cannot write assemblies, only read from them. Cannot create assembly \"{0}\".", filename));
					return;
				case ResGen.Format.Binary:
					this.WriteResources(reader, new ResourceWriter(filename));
					return;
				default:
					return;
				}
			}

			private void WriteResources(ResGen.ResGenRunner.ReaderInfo reader, IResourceWriter writer) {
				try
				{
					foreach (object obj in reader.resources)
					{
						ResGen.Entry entry = (ResGen.Entry)obj;
						string name = entry.name;
						object value = entry.value;
						writer.AddResource(name, value);
					}
					this.BufferWrite("Writing resource file...  ", new object[0]);
				}
				catch
				{
					writer.Close();
					throw;
				}
				finally
				{
					writer.Close();
				}
				this.BufferWriteLine("Done.", new object[0]);
			}

			private void WriteTextResources(ResGen.ResGenRunner.ReaderInfo reader, string fileName)
			{
				using (StreamWriter streamWriter = new StreamWriter(fileName, false, Encoding.UTF8))
				{
					foreach (object obj in reader.resources)
					{
						ResGen.Entry entry = (ResGen.Entry)obj;
						string name = entry.name;
						object value = entry.value;
						string text = value as string;
						if (text == null)
						{
							this.Error(string.Format("Only strings can be written to a .txt or .restext file; the value of '{0}' is a '{1}'", name, value.GetType().FullName), fileName);
						}
						text = text.Replace("\\", "\\\\");
						text = text.Replace("\n", "\\n");
						text = text.Replace("\r", "\\r");
						text = text.Replace("\t", "\\t");
						streamWriter.WriteLine("{0}={1}", name, text);
					}
				}
			}

			internal void ReadAssemblyResources(string name)
			{
				Assembly assembly = null;
				bool flag = false;
				bool flag2 = false;
				NeutralResourcesLanguageAttribute neutralResourcesLanguageAttribute = null;
				AssemblyName assemblyName = null;
				try
				{
					assembly = Assembly.UnsafeLoadFrom(name);
					assemblyName = assembly.GetName();
					CultureInfo cultureInfo = null;
					try
					{
						cultureInfo = assemblyName.CultureInfo;
					}
					catch (ArgumentException ex)
					{
						this.Warning(string.Format("Creating the CultureInfo failed for assembly \"{2}\".  Note the set of cultures supported is Operating System-dependent, and the Operating System has removed some cultures from time to time (ie, some Serbian cultures are split up in Windows 7).  The culture may be a user-defined custom culture that we can't currently load on this machine.  Exception info: {0}: {1}", new object[] {ex.GetType().Name, ex.Message, assemblyName.ToString()}));
						flag2 = true;
					}
					if (!flag2)
					{
						flag = cultureInfo.Equals(CultureInfo.InvariantCulture);
						neutralResourcesLanguageAttribute = this.CheckAssemblyCultureInfo(name, assemblyName, cultureInfo, assembly, flag);
					}
				}
				catch (BadImageFormatException)
				{
					this.Error(string.Format("Did not recognize \"{0}\" as a managed assembly.", name));
				}
				catch (Exception ex2)
				{
					this.Error(string.Format("Loading assembly \"{0}\" failed.  {1}", name, ex2));
				}
				if (assembly != null)
				{
					string[] manifestResourceNames = assembly.GetManifestResourceNames();
					CultureInfo cultureInfo2 = null;
					string text = null;
					if (!flag2)
					{
						cultureInfo2 = assemblyName.CultureInfo;
						if (!cultureInfo2.Equals(CultureInfo.InvariantCulture))
						{
							text = "." + cultureInfo2.Name + ".resources";
						}
					}
					foreach (string text2 in manifestResourceNames)
					{
						if (text2.EndsWith(".resources", StringComparison.InvariantCultureIgnoreCase))
						{
							if (flag)
							{
								if (CultureInfo.InvariantCulture.CompareInfo.IsSuffix(text2, ".en-US.resources"))
								{
									this.Error(string.Format("Main assembly \"{1}\" was built improperly.  The manifest resource \"{0}\" ends in .en-US.resources, when it should end in .resources.  Either rename it to something like foo.resources (and consider using the NeutralResourcesLanguageAtribute on the main assembly), or move it to a US English satellite assembly.", text2, name));
									continue;
								}
							}
							else if (!flag2 && !CultureInfo.InvariantCulture.CompareInfo.IsSuffix(text2, text))
							{
								this.Error(string.Format("Satellite assembly \"{2}\" was built improperly.  The manifest resource \"{0}\" will not be found by the ResourceManager.  It must end in \"{1}\".", new object[] {text2, text, name}));
								continue;
							}
							try
							{
								Stream manifestResourceStream = assembly.GetManifestResourceStream(text2);
								using (IResourceReader resourceReader = new ResourceReader(manifestResourceStream))
								{
									ResGen.ResGenRunner.ReaderInfo readerInfo = new ResGen.ResGenRunner.ReaderInfo();
									readerInfo.outputFileName = text2.Remove(text2.Length - 10);
									if (cultureInfo2 != null && !string.IsNullOrEmpty(cultureInfo2.Name))
									{
										readerInfo.cultureName = cultureInfo2.Name;
									}
									else if (neutralResourcesLanguageAttribute != null && !string.IsNullOrEmpty(neutralResourcesLanguageAttribute.CultureName))
									{
										readerInfo.cultureName = neutralResourcesLanguageAttribute.CultureName;
										this.Warning(string.Format("This assembly contains neutral resources corresponding to the culture \"{0}\". These resources will not be considered neutral in the output format as we are unable to preserve this information. The resources will continue to correspond to \"{0}\" in the output format.", readerInfo.cultureName));
									}
									if (readerInfo.cultureName != null && readerInfo.outputFileName.EndsWith("." + readerInfo.cultureName, StringComparison.OrdinalIgnoreCase))
									{
										readerInfo.outputFileName = readerInfo.outputFileName.Remove(readerInfo.outputFileName.Length - (readerInfo.cultureName.Length + 1));
									}
									this.readers.Add(readerInfo);
									foreach (object obj in resourceReader)
									{
										DictionaryEntry dictionaryEntry = (DictionaryEntry)obj;
										this.AddResource(readerInfo, (string)dictionaryEntry.Key, dictionaryEntry.Value, text2);
									}
									this.BufferWriteLine(string.Format("Read in {0} resources from \"{1}\"", readerInfo.resources.Count, text2), new object[0]);
								}
							}
							catch (FileNotFoundException)
							{
								this.Error(string.Format("Couldn't find the linked resources file \"{0}\" listed in the assembly manifest.", text2));
							}
						}
					}
				}
			}

			private NeutralResourcesLanguageAttribute CheckAssemblyCultureInfo(string name, AssemblyName assemblyName, CultureInfo culture, Assembly a, bool mainAssembly)
			{
				NeutralResourcesLanguageAttribute neutralResourcesLanguageAttribute = null;
				if (mainAssembly)
				{
					object[] customAttributes = a.GetCustomAttributes(typeof(NeutralResourcesLanguageAttribute), false);
					if (customAttributes.Length != 0)
					{
						neutralResourcesLanguageAttribute = (NeutralResourcesLanguageAttribute)customAttributes[0];
						if (neutralResourcesLanguageAttribute.Location != UltimateResourceFallbackLocation.Satellite && neutralResourcesLanguageAttribute.Location != UltimateResourceFallbackLocation.MainAssembly)
						{
							this.Warning(string.Format("Invalid or unrecognized UltimateResourceFallbackLocation value in the NeutralResourcesLanguageAttribute for assembly \"{1}\". Location: \"{0}\"", neutralResourcesLanguageAttribute.Location, name));
						}
						if (!ResGen.ResGenRunner.ContainsProperlyNamedResourcesFiles(a, true))
						{
							this.Error("This assembly claims to contain neutral resources, but doesn't contain any .resources files as manifest resources.  Either the NeutralResourcesLanguageAttribute was wrong, or there is a build-related problem with this assembly.");
						}
					}
				}
				else
				{
					if (!assemblyName.Name.EndsWith(".resources", StringComparison.InvariantCultureIgnoreCase))
					{
						this.Error(string.Format("The assembly in file \"{0}\" has an assembly culture, indicating it is a satellite assembly for culture \"{1}\".  But satellite assembly simple names must end in \".resources\", while this one's simple name is \"{2}\".  This is either a main assembly with the culture incorrectly set, or a satellite assembly with an incorrect simple name.", new object[] {name, culture.Name, assemblyName.Name}));
						return null;
					}
					Type[] types = a.GetTypes();
					if (types.Length != 0)
					{
						this.Warning(string.Format("The assembly \"{0}\" says it is a satellite assembly, but it contains code. Main assemblies shouldn't specify the assembly culture in their manifest, and satellites should not contain code.  This is almost certainly an error in your build process.", name));
					}
					if (!ResGen.ResGenRunner.ContainsProperlyNamedResourcesFiles(a, false))
					{
						this.Warning(string.Format("This assembly claims to be a satellite assembly, but doesn't contain any properly named .resources files as manifest resources.  The name of the files should end in {0}.resources.  There is probably a build-related problem with this assembly.", assemblyName.CultureInfo.Name));
					}
				}
				byte[] publicKey = assemblyName.GetPublicKey();
				if (publicKey != null && publicKey.Length != 0 && !ResGen.ResGenRunner.StrongNameHelper.AssemblyIsFullySigned(a))
				{
					this.Warning(string.Format("Assembly \"{0}\" isn't fully signed.  Please fully sign this assembly using sn.exe before shipping it to customers.", name));
				}
				return neutralResourcesLanguageAttribute;
			}

			private static bool ContainsProperlyNamedResourcesFiles(Assembly a, bool mainAssembly)
			{
				string value = mainAssembly ? ".resources" : (a.GetName().CultureInfo.Name + ".resources");
				foreach (string text in a.GetManifestResourceNames())
				{
					if (text.EndsWith(value, StringComparison.InvariantCultureIgnoreCase))
					{
						return true;
					}
				}
				return false;
			}

			private List<Action> bufferedOutput = new List<Action>(2);

			private List<ResGen.ResGenRunner.ReaderInfo> readers = new List<ResGen.ResGenRunner.ReaderInfo>();

			private bool hadErrors;

			private const string CLSID_InternetSecurityManager = "7b8a2d94-0ac9-11d1-896c-00c04fb6bfc4";

			public const uint ZoneLocalMachine = 0U;

			public const uint ZoneIntranet = 1U;

			public const uint ZoneTrusted = 2U;

			public const uint ZoneInternet = 3U;

			public const uint ZoneUntrusted = 4U;

			private IInternetSecurityManager internetSecurityManager;

			internal sealed class ReaderInfo
			{
				public ReaderInfo()
				{
					this.resources = new ArrayList();
					this.resourcesHashTable = new Hashtable(StringComparer.InvariantCultureIgnoreCase);
				}

				public string outputFileName;

				public string cultureName;

				public ArrayList resources;

				public Hashtable resourcesHashTable;
			}

			internal static class StrongNameHelper
			{
				public static bool AssemblyIsFullySigned(Assembly assembly)
				{
					if (assembly.Location == null)
					{
						throw new ArgumentException("MissingFileLocation");
					}
					int num;
					return StrongNameHelpers.StrongNameSignatureVerification(assembly.Location, 17, out num);
				}

				private enum StrongNameFlags
				{
					ForceVerification = 1,
					AllAccess = 16
				}
			}
		}

		private enum Format
		{
			Text,
			XML,
			Assembly,
			Binary
		}

		private class Entry
		{
			public Entry(string name, object value)
			{
				this.name = name;
				this.value = value;
			}

			public string name;

			public object value;
		}
	}
}


namespace Microsoft.Runtime.Hosting
{
	[SecurityCritical]
	[ComConversionLoss]
	[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
	[Guid("9FD93CCF-3280-4391-B3A9-96E1CDE77C8D")]
	[ComImport]
	internal interface IClrStrongName
	{
		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int GetHashFromAssemblyFile([MarshalAs(UnmanagedType.LPStr)] [In] string pszFilePath, [MarshalAs(UnmanagedType.U4)] [In] [Out] ref int piHashAlg, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 3)] [Out] byte[] pbHash, [MarshalAs(UnmanagedType.U4)] [In] int cchHash, [MarshalAs(UnmanagedType.U4)] out int pchHash);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int GetHashFromAssemblyFileW([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzFilePath, [MarshalAs(UnmanagedType.U4)] [In] [Out] ref int piHashAlg, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 3)] [Out] byte[] pbHash, [MarshalAs(UnmanagedType.U4)] [In] int cchHash, [MarshalAs(UnmanagedType.U4)] out int pchHash);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int GetHashFromBlob([In] IntPtr pbBlob, [MarshalAs(UnmanagedType.U4)] [In] int cchBlob, [MarshalAs(UnmanagedType.U4)] [In] [Out] ref int piHashAlg, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 4)] [Out] byte[] pbHash, [MarshalAs(UnmanagedType.U4)] [In] int cchHash, [MarshalAs(UnmanagedType.U4)] out int pchHash);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int GetHashFromFile([MarshalAs(UnmanagedType.LPStr)] [In] string pszFilePath, [MarshalAs(UnmanagedType.U4)] [In] [Out] ref int piHashAlg, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 3)] [Out] byte[] pbHash, [MarshalAs(UnmanagedType.U4)] [In] int cchHash, [MarshalAs(UnmanagedType.U4)] out int pchHash);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int GetHashFromFileW([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzFilePath, [MarshalAs(UnmanagedType.U4)] [In] [Out] ref int piHashAlg, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 3)] [Out] byte[] pbHash, [MarshalAs(UnmanagedType.U4)] [In] int cchHash, [MarshalAs(UnmanagedType.U4)] out int pchHash);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int GetHashFromHandle([In] IntPtr hFile, [MarshalAs(UnmanagedType.U4)] [In] [Out] ref int piHashAlg, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 3)] [Out] byte[] pbHash, [MarshalAs(UnmanagedType.U4)] [In] int cchHash, [MarshalAs(UnmanagedType.U4)] out int pchHash);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		[return: MarshalAs(UnmanagedType.U4)]
		int StrongNameCompareAssemblies([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzAssembly1, [MarshalAs(UnmanagedType.LPWStr)] [In] string pwzAssembly2, [MarshalAs(UnmanagedType.U4)] out int dwResult);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameFreeBuffer([In] IntPtr pbMemory);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameGetBlob([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzFilePath, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 2)] [Out] byte[] pbBlob, [MarshalAs(UnmanagedType.U4)] [In] [Out] ref int pcbBlob);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameGetBlobFromImage([In] IntPtr pbBase, [MarshalAs(UnmanagedType.U4)] [In] int dwLength, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 3)] [Out] byte[] pbBlob, [MarshalAs(UnmanagedType.U4)] [In] [Out] ref int pcbBlob);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameGetPublicKey([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzKeyContainer, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 2)] [In] byte[] pbKeyBlob, [MarshalAs(UnmanagedType.U4)] [In] int cbKeyBlob, out IntPtr ppbPublicKeyBlob, [MarshalAs(UnmanagedType.U4)] out int pcbPublicKeyBlob);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		[return: MarshalAs(UnmanagedType.U4)]
		int StrongNameHashSize([MarshalAs(UnmanagedType.U4)] [In] int ulHashAlg, [MarshalAs(UnmanagedType.U4)] out int cbSize);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameKeyDelete([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzKeyContainer);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameKeyGen([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzKeyContainer, [MarshalAs(UnmanagedType.U4)] [In] int dwFlags, out IntPtr ppbKeyBlob, [MarshalAs(UnmanagedType.U4)] out int pcbKeyBlob);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameKeyGenEx([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzKeyContainer, [MarshalAs(UnmanagedType.U4)] [In] int dwFlags, [MarshalAs(UnmanagedType.U4)] [In] int dwKeySize, out IntPtr ppbKeyBlob, [MarshalAs(UnmanagedType.U4)] out int pcbKeyBlob);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameKeyInstall([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzKeyContainer, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 2)] [In] byte[] pbKeyBlob, [MarshalAs(UnmanagedType.U4)] [In] int cbKeyBlob);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameSignatureGeneration([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzFilePath, [MarshalAs(UnmanagedType.LPWStr)] [In] string pwzKeyContainer, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 3)] [In] byte[] pbKeyBlob, [MarshalAs(UnmanagedType.U4)] [In] int cbKeyBlob, [In] [Out] IntPtr ppbSignatureBlob, [MarshalAs(UnmanagedType.U4)] out int pcbSignatureBlob);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameSignatureGenerationEx([MarshalAs(UnmanagedType.LPWStr)] [In] string wszFilePath, [MarshalAs(UnmanagedType.LPWStr)] [In] string wszKeyContainer, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 3)] [In] byte[] pbKeyBlob, [MarshalAs(UnmanagedType.U4)] [In] int cbKeyBlob, [In] [Out] IntPtr ppbSignatureBlob, [MarshalAs(UnmanagedType.U4)] out int pcbSignatureBlob, [MarshalAs(UnmanagedType.U4)] [In] int dwFlags);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameSignatureSize([MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 1)] [In] byte[] pbPublicKeyBlob, [MarshalAs(UnmanagedType.U4)] [In] int cbPublicKeyBlob, [MarshalAs(UnmanagedType.U4)] out int pcbSize);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		[return: MarshalAs(UnmanagedType.U4)]
		int StrongNameSignatureVerification([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzFilePath, [MarshalAs(UnmanagedType.U4)] [In] int dwInFlags, [MarshalAs(UnmanagedType.U4)] out int dwOutFlags);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		[return: MarshalAs(UnmanagedType.U4)]
		int StrongNameSignatureVerificationEx([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzFilePath, [MarshalAs(UnmanagedType.I1)] [In] bool fForceVerification, [MarshalAs(UnmanagedType.I1)] out bool fWasVerified);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		[return: MarshalAs(UnmanagedType.U4)]
		int StrongNameSignatureVerificationFromImage([In] IntPtr pbBase, [MarshalAs(UnmanagedType.U4)] [In] int dwLength, [MarshalAs(UnmanagedType.U4)] [In] int dwInFlags, [MarshalAs(UnmanagedType.U4)] out int dwOutFlags);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameTokenFromAssembly([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzFilePath, out IntPtr ppbStrongNameToken, [MarshalAs(UnmanagedType.U4)] out int pcbStrongNameToken);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameTokenFromAssemblyEx([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzFilePath, out IntPtr ppbStrongNameToken, [MarshalAs(UnmanagedType.U4)] out int pcbStrongNameToken, out IntPtr ppbPublicKeyBlob, [MarshalAs(UnmanagedType.U4)] out int pcbPublicKeyBlob);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameTokenFromPublicKey([MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 1)] [In] byte[] pbPublicKeyBlob, [MarshalAs(UnmanagedType.U4)] [In] int cbPublicKeyBlob, out IntPtr ppbStrongNameToken, [MarshalAs(UnmanagedType.U4)] out int pcbStrongNameToken);
	}
	[SecurityCritical]
	[ComConversionLoss]
	[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
	[Guid("9FD93CCF-3280-4391-B3A9-96E1CDE77C8D")]
	[ComImport]
	internal interface IClrStrongNameUsingIntPtr
	{
		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int GetHashFromAssemblyFile([MarshalAs(UnmanagedType.LPStr)] [In] string pszFilePath, [MarshalAs(UnmanagedType.U4)] [In] [Out] ref int piHashAlg, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 3)] [Out] byte[] pbHash, [MarshalAs(UnmanagedType.U4)] [In] int cchHash, [MarshalAs(UnmanagedType.U4)] out int pchHash);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int GetHashFromAssemblyFileW([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzFilePath, [MarshalAs(UnmanagedType.U4)] [In] [Out] ref int piHashAlg, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 3)] [Out] byte[] pbHash, [MarshalAs(UnmanagedType.U4)] [In] int cchHash, [MarshalAs(UnmanagedType.U4)] out int pchHash);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int GetHashFromBlob([In] IntPtr pbBlob, [MarshalAs(UnmanagedType.U4)] [In] int cchBlob, [MarshalAs(UnmanagedType.U4)] [In] [Out] ref int piHashAlg, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 4)] [Out] byte[] pbHash, [MarshalAs(UnmanagedType.U4)] [In] int cchHash, [MarshalAs(UnmanagedType.U4)] out int pchHash);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int GetHashFromFile([MarshalAs(UnmanagedType.LPStr)] [In] string pszFilePath, [MarshalAs(UnmanagedType.U4)] [In] [Out] ref int piHashAlg, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 3)] [Out] byte[] pbHash, [MarshalAs(UnmanagedType.U4)] [In] int cchHash, [MarshalAs(UnmanagedType.U4)] out int pchHash);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int GetHashFromFileW([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzFilePath, [MarshalAs(UnmanagedType.U4)] [In] [Out] ref int piHashAlg, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 3)] [Out] byte[] pbHash, [MarshalAs(UnmanagedType.U4)] [In] int cchHash, [MarshalAs(UnmanagedType.U4)] out int pchHash);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int GetHashFromHandle([In] IntPtr hFile, [MarshalAs(UnmanagedType.U4)] [In] [Out] ref int piHashAlg, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 3)] [Out] byte[] pbHash, [MarshalAs(UnmanagedType.U4)] [In] int cchHash, [MarshalAs(UnmanagedType.U4)] out int pchHash);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		[return: MarshalAs(UnmanagedType.U4)]
		int StrongNameCompareAssemblies([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzAssembly1, [MarshalAs(UnmanagedType.LPWStr)] [In] string pwzAssembly2, [MarshalAs(UnmanagedType.U4)] out int dwResult);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameFreeBuffer([In] IntPtr pbMemory);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameGetBlob([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzFilePath, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 2)] [Out] byte[] pbBlob, [MarshalAs(UnmanagedType.U4)] [In] [Out] ref int pcbBlob);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameGetBlobFromImage([In] IntPtr pbBase, [MarshalAs(UnmanagedType.U4)] [In] int dwLength, [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 3)] [Out] byte[] pbBlob, [MarshalAs(UnmanagedType.U4)] [In] [Out] ref int pcbBlob);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameGetPublicKey([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzKeyContainer, [In] IntPtr pbKeyBlob, [MarshalAs(UnmanagedType.U4)] [In] int cbKeyBlob, out IntPtr ppbPublicKeyBlob, [MarshalAs(UnmanagedType.U4)] out int pcbPublicKeyBlob);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		[return: MarshalAs(UnmanagedType.U4)]
		int StrongNameHashSize([MarshalAs(UnmanagedType.U4)] [In] int ulHashAlg, [MarshalAs(UnmanagedType.U4)] out int cbSize);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameKeyDelete([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzKeyContainer);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameKeyGen([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzKeyContainer, [MarshalAs(UnmanagedType.U4)] [In] int dwFlags, out IntPtr ppbKeyBlob, [MarshalAs(UnmanagedType.U4)] out int pcbKeyBlob);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameKeyGenEx([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzKeyContainer, [MarshalAs(UnmanagedType.U4)] [In] int dwFlags, [MarshalAs(UnmanagedType.U4)] [In] int dwKeySize, out IntPtr ppbKeyBlob, [MarshalAs(UnmanagedType.U4)] out int pcbKeyBlob);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameKeyInstall([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzKeyContainer, [In] IntPtr pbKeyBlob, [MarshalAs(UnmanagedType.U4)] [In] int cbKeyBlob);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameSignatureGeneration([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzFilePath, [MarshalAs(UnmanagedType.LPWStr)] [In] string pwzKeyContainer, [In] IntPtr pbKeyBlob, [MarshalAs(UnmanagedType.U4)] [In] int cbKeyBlob, [In] [Out] IntPtr ppbSignatureBlob, [MarshalAs(UnmanagedType.U4)] out int pcbSignatureBlob);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameSignatureGenerationEx([MarshalAs(UnmanagedType.LPWStr)] [In] string wszFilePath, [MarshalAs(UnmanagedType.LPWStr)] [In] string wszKeyContainer, [In] IntPtr pbKeyBlob, [MarshalAs(UnmanagedType.U4)] [In] int cbKeyBlob, [In] [Out] IntPtr ppbSignatureBlob, [MarshalAs(UnmanagedType.U4)] out int pcbSignatureBlob, [MarshalAs(UnmanagedType.U4)] [In] int dwFlags);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameSignatureSize([In] IntPtr pbPublicKeyBlob, [MarshalAs(UnmanagedType.U4)] [In] int cbPublicKeyBlob, [MarshalAs(UnmanagedType.U4)] out int pcbSize);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		[return: MarshalAs(UnmanagedType.U4)]
		int StrongNameSignatureVerification([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzFilePath, [MarshalAs(UnmanagedType.U4)] [In] int dwInFlags, [MarshalAs(UnmanagedType.U4)] out int dwOutFlags);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		[return: MarshalAs(UnmanagedType.U4)]
		int StrongNameSignatureVerificationEx([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzFilePath, [MarshalAs(UnmanagedType.I1)] [In] bool fForceVerification, [MarshalAs(UnmanagedType.I1)] out bool fWasVerified);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		[return: MarshalAs(UnmanagedType.U4)]
		int StrongNameSignatureVerificationFromImage([In] IntPtr pbBase, [MarshalAs(UnmanagedType.U4)] [In] int dwLength, [MarshalAs(UnmanagedType.U4)] [In] int dwInFlags, [MarshalAs(UnmanagedType.U4)] out int dwOutFlags);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameTokenFromAssembly([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzFilePath, out IntPtr ppbStrongNameToken, [MarshalAs(UnmanagedType.U4)] out int pcbStrongNameToken);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameTokenFromAssemblyEx([MarshalAs(UnmanagedType.LPWStr)] [In] string pwzFilePath, out IntPtr ppbStrongNameToken, [MarshalAs(UnmanagedType.U4)] out int pcbStrongNameToken, out IntPtr ppbPublicKeyBlob, [MarshalAs(UnmanagedType.U4)] out int pcbPublicKeyBlob);

		[MethodImpl(MethodImplOptions.PreserveSig | MethodImplOptions.InternalCall)]
		int StrongNameTokenFromPublicKey([In] IntPtr pbPublicKeyBlob, [MarshalAs(UnmanagedType.U4)] [In] int cbPublicKeyBlob, out IntPtr ppbStrongNameToken, [MarshalAs(UnmanagedType.U4)] out int pcbStrongNameToken);
	}
	internal static class StrongNameHelpers
	{
		private static IClrStrongName StrongName
		{
			[SecurityCritical]
			get
			{
				if (StrongNameHelpers.s_StrongName == null)
				{
					StrongNameHelpers.s_StrongName = (IClrStrongName)RuntimeEnvironment.GetRuntimeInterfaceAsObject(new Guid("B79B0ACD-F5CD-409b-B5A5-A16244610B92"), new Guid("9FD93CCF-3280-4391-B3A9-96E1CDE77C8D"));
				}
				return StrongNameHelpers.s_StrongName;
			}
		}

		private static IClrStrongNameUsingIntPtr StrongNameUsingIntPtr
		{
			[SecurityCritical]
			get
			{
				return (IClrStrongNameUsingIntPtr)StrongNameHelpers.StrongName;
			}
		}

		[SecurityCritical]
		public static int StrongNameErrorInfo()
		{
			return StrongNameHelpers.ts_LastStrongNameHR;
		}

		[SecurityCritical]
		public static void StrongNameFreeBuffer(IntPtr pbMemory)
		{
			StrongNameHelpers.StrongNameUsingIntPtr.StrongNameFreeBuffer(pbMemory);
		}

		[SecurityCritical]
		public static bool StrongNameGetPublicKey(string pwzKeyContainer, IntPtr pbKeyBlob, int cbKeyBlob, out IntPtr ppbPublicKeyBlob, out int pcbPublicKeyBlob)
		{
			int num = StrongNameHelpers.StrongNameUsingIntPtr.StrongNameGetPublicKey(pwzKeyContainer, pbKeyBlob, cbKeyBlob, out ppbPublicKeyBlob, out pcbPublicKeyBlob);
			if (num < 0)
			{
				StrongNameHelpers.ts_LastStrongNameHR = num;
				ppbPublicKeyBlob = IntPtr.Zero;
				pcbPublicKeyBlob = 0;
				return false;
			}
			return true;
		}

		[SecurityCritical]
		public static bool StrongNameKeyDelete(string pwzKeyContainer)
		{
			int num = StrongNameHelpers.StrongName.StrongNameKeyDelete(pwzKeyContainer);
			if (num < 0)
			{
				StrongNameHelpers.ts_LastStrongNameHR = num;
				return false;
			}
			return true;
		}

		[SecurityCritical]
		public static bool StrongNameKeyGen(string pwzKeyContainer, int dwFlags, out IntPtr ppbKeyBlob, out int pcbKeyBlob)
		{
			int num = StrongNameHelpers.StrongName.StrongNameKeyGen(pwzKeyContainer, dwFlags, out ppbKeyBlob, out pcbKeyBlob);
			if (num < 0)
			{
				StrongNameHelpers.ts_LastStrongNameHR = num;
				ppbKeyBlob = IntPtr.Zero;
				pcbKeyBlob = 0;
				return false;
			}
			return true;
		}

		[SecurityCritical]
		public static bool StrongNameKeyInstall(string pwzKeyContainer, IntPtr pbKeyBlob, int cbKeyBlob)
		{
			int num = StrongNameHelpers.StrongNameUsingIntPtr.StrongNameKeyInstall(pwzKeyContainer, pbKeyBlob, cbKeyBlob);
			if (num < 0)
			{
				StrongNameHelpers.ts_LastStrongNameHR = num;
				return false;
			}
			return true;
		}

		[SecurityCritical]
		public static bool StrongNameSignatureGeneration(string pwzFilePath, string pwzKeyContainer, IntPtr pbKeyBlob, int cbKeyBlob)
		{
			IntPtr zero = IntPtr.Zero;
			int num = 0;
			return StrongNameHelpers.StrongNameSignatureGeneration(pwzFilePath, pwzKeyContainer, pbKeyBlob, cbKeyBlob, ref zero, out num);
		}

		[SecurityCritical]
		public static bool StrongNameSignatureGeneration(string pwzFilePath, string pwzKeyContainer, IntPtr pbKeyBlob, int cbKeyBlob, ref IntPtr ppbSignatureBlob, out int pcbSignatureBlob)
		{
			int num = StrongNameHelpers.StrongNameUsingIntPtr.StrongNameSignatureGeneration(pwzFilePath, pwzKeyContainer, pbKeyBlob, cbKeyBlob, ppbSignatureBlob, out pcbSignatureBlob);
			if (num < 0)
			{
				StrongNameHelpers.ts_LastStrongNameHR = num;
				pcbSignatureBlob = 0;
				return false;
			}
			return true;
		}

		[SecurityCritical]
		public static bool StrongNameSignatureSize(IntPtr pbPublicKeyBlob, int cbPublicKeyBlob, out int pcbSize)
		{
			int num = StrongNameHelpers.StrongNameUsingIntPtr.StrongNameSignatureSize(pbPublicKeyBlob, cbPublicKeyBlob, out pcbSize);
			if (num < 0)
			{
				StrongNameHelpers.ts_LastStrongNameHR = num;
				pcbSize = 0;
				return false;
			}
			return true;
		}

		[SecurityCritical]
		public static bool StrongNameSignatureVerification(string pwzFilePath, int dwInFlags, out int pdwOutFlags)
		{
			int num = StrongNameHelpers.StrongName.StrongNameSignatureVerification(pwzFilePath, dwInFlags, out pdwOutFlags);
			if (num < 0)
			{
				StrongNameHelpers.ts_LastStrongNameHR = num;
				pdwOutFlags = 0;
				return false;
			}
			return true;
		}

		[SecurityCritical]
		public static bool StrongNameSignatureVerificationEx(string pwzFilePath, bool fForceVerification, out bool pfWasVerified)
		{
			int num = StrongNameHelpers.StrongName.StrongNameSignatureVerificationEx(pwzFilePath, fForceVerification, out pfWasVerified);
			if (num < 0)
			{
				StrongNameHelpers.ts_LastStrongNameHR = num;
				pfWasVerified = false;
				return false;
			}
			return true;
		}

		[SecurityCritical]
		public static bool StrongNameTokenFromPublicKey(IntPtr pbPublicKeyBlob, int cbPublicKeyBlob, out IntPtr ppbStrongNameToken, out int pcbStrongNameToken)
		{
			int num = StrongNameHelpers.StrongNameUsingIntPtr.StrongNameTokenFromPublicKey(pbPublicKeyBlob, cbPublicKeyBlob, out ppbStrongNameToken, out pcbStrongNameToken);
			if (num < 0)
			{
				StrongNameHelpers.ts_LastStrongNameHR = num;
				ppbStrongNameToken = IntPtr.Zero;
				pcbStrongNameToken = 0;
				return false;
			}
			return true;
		}

		[SecurityCritical]
		public static bool StrongNameSignatureSize(byte[] bPublicKeyBlob, int cbPublicKeyBlob, out int pcbSize)
		{
			int num = StrongNameHelpers.StrongName.StrongNameSignatureSize(bPublicKeyBlob, cbPublicKeyBlob, out pcbSize);
			if (num < 0)
			{
				StrongNameHelpers.ts_LastStrongNameHR = num;
				pcbSize = 0;
				return false;
			}
			return true;
		}

		[SecurityCritical]
		public static bool StrongNameTokenFromPublicKey(byte[] bPublicKeyBlob, int cbPublicKeyBlob, out IntPtr ppbStrongNameToken, out int pcbStrongNameToken)
		{
			int num = StrongNameHelpers.StrongName.StrongNameTokenFromPublicKey(bPublicKeyBlob, cbPublicKeyBlob, out ppbStrongNameToken, out pcbStrongNameToken);
			if (num < 0)
			{
				StrongNameHelpers.ts_LastStrongNameHR = num;
				ppbStrongNameToken = IntPtr.Zero;
				pcbStrongNameToken = 0;
				return false;
			}
			return true;
		}

		[SecurityCritical]
		public static bool StrongNameGetPublicKey(string pwzKeyContainer, byte[] bKeyBlob, int cbKeyBlob, out IntPtr ppbPublicKeyBlob, out int pcbPublicKeyBlob)
		{
			int num = StrongNameHelpers.StrongName.StrongNameGetPublicKey(pwzKeyContainer, bKeyBlob, cbKeyBlob, out ppbPublicKeyBlob, out pcbPublicKeyBlob);
			if (num < 0)
			{
				StrongNameHelpers.ts_LastStrongNameHR = num;
				ppbPublicKeyBlob = IntPtr.Zero;
				pcbPublicKeyBlob = 0;
				return false;
			}
			return true;
		}

		[SecurityCritical]
		public static bool StrongNameKeyInstall(string pwzKeyContainer, byte[] bKeyBlob, int cbKeyBlob)
		{
			int num = StrongNameHelpers.StrongName.StrongNameKeyInstall(pwzKeyContainer, bKeyBlob, cbKeyBlob);
			if (num < 0)
			{
				StrongNameHelpers.ts_LastStrongNameHR = num;
				return false;
			}
			return true;
		}

		[SecurityCritical]
		public static bool StrongNameSignatureGeneration(string pwzFilePath, string pwzKeyContainer, byte[] bKeyBlob, int cbKeyBlob)
		{
			IntPtr zero = IntPtr.Zero;
			int num = 0;
			return StrongNameHelpers.StrongNameSignatureGeneration(pwzFilePath, pwzKeyContainer, bKeyBlob, cbKeyBlob, ref zero, out num);
		}

		[SecurityCritical]
		public static bool StrongNameSignatureGeneration(string pwzFilePath, string pwzKeyContainer, byte[] bKeyBlob, int cbKeyBlob, ref IntPtr ppbSignatureBlob, out int pcbSignatureBlob)
		{
			int num = StrongNameHelpers.StrongName.StrongNameSignatureGeneration(pwzFilePath, pwzKeyContainer, bKeyBlob, cbKeyBlob, ppbSignatureBlob, out pcbSignatureBlob);
			if (num < 0)
			{
				StrongNameHelpers.ts_LastStrongNameHR = num;
				pcbSignatureBlob = 0;
				return false;
			}
			return true;
		}

		[ThreadStatic]
		private static int ts_LastStrongNameHR;

		[SecurityCritical]
		[ThreadStatic]
		private static IClrStrongName s_StrongName;
	}
}
[StructLayout(LayoutKind.Sequential, Pack = 4)]
public struct GUID
{
	public int Data1;

	public ushort Data2;

	public ushort Data3;

	[MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)]
	public byte[] Data4;
}

[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
[Guid("00000101-0000-0000-C000-000000000046")]
[ComImport]
public interface IEnumString
{
	[MethodImpl(MethodImplOptions.InternalCall)]
	void RemoteNext([In] int celt, [MarshalAs(UnmanagedType.LPWStr)] out string rgelt, out int pceltFetched);

	[MethodImpl(MethodImplOptions.InternalCall)]
	void Skip([In] int celt);

	[MethodImpl(MethodImplOptions.InternalCall)]
	void Reset();

	[MethodImpl(MethodImplOptions.InternalCall)]
	void Clone([MarshalAs(UnmanagedType.Interface)] out IEnumString ppenum);
}
[Guid("79EAC9EE-BAF9-11CE-8C82-00AA004BA90B")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
[ComConversionLoss]
[ComImport]
public interface IInternetSecurityManager
{
	[MethodImpl(MethodImplOptions.InternalCall)]
	void SetSecuritySite([MarshalAs(UnmanagedType.Interface)] [In] IInternetSecurityMgrSite pSite);

	[MethodImpl(MethodImplOptions.InternalCall)]
	void GetSecuritySite([MarshalAs(UnmanagedType.Interface)] out IInternetSecurityMgrSite ppSite);

	[MethodImpl(MethodImplOptions.InternalCall)]
	void MapUrlToZone([MarshalAs(UnmanagedType.LPWStr)] [In] string pwszUrl, out int pdwZone, [In] int dwFlags);

	[MethodImpl(MethodImplOptions.InternalCall)]
	void GetSecurityId([MarshalAs(UnmanagedType.LPWStr)] [In] string pwszUrl, out byte pbSecurityId, [In] [Out] ref int pcbSecurityId, [ComAliasName("UrlMonTypeLib.ULONG_PTR")] [In] int dwReserved);

	[MethodImpl(MethodImplOptions.InternalCall)]
	void ProcessUrlAction([MarshalAs(UnmanagedType.LPWStr)] [In] string pwszUrl, [In] int dwAction, out byte pPolicy, [In] int cbPolicy, [In] ref byte pContext, [In] int cbContext, [In] int dwFlags, [In] int dwReserved);

	[MethodImpl(MethodImplOptions.InternalCall)]
	void QueryCustomPolicy([MarshalAs(UnmanagedType.LPWStr)] [In] string pwszUrl, [ComAliasName("UrlMonTypeLib.GUID")] [In] ref GUID guidKey, [Out] IntPtr ppPolicy, out int pcbPolicy, [In] ref byte pContext, [In] int cbContext, [In] int dwReserved);

	[MethodImpl(MethodImplOptions.InternalCall)]
	void SetZoneMapping([In] int dwZone, [MarshalAs(UnmanagedType.LPWStr)] [In] string lpszPattern, [In] int dwFlags);

	[MethodImpl(MethodImplOptions.InternalCall)]
	void GetZoneMappings([In] int dwZone, [MarshalAs(UnmanagedType.Interface)] out IEnumString ppenumString, [In] int dwFlags);
}
[ComConversionLoss]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
[Guid("79EAC9ED-BAF9-11CE-8C82-00AA004BA90B")]
[ComImport]
public interface IInternetSecurityMgrSite
{
	[MethodImpl(MethodImplOptions.InternalCall)]
	void GetWindow([ComAliasName("UrlMonTypeLib.wireHWND")] [Out] IntPtr phwnd);

	[MethodImpl(MethodImplOptions.InternalCall)]
	void EnableModeless([In] int fEnable);
}
'@
sc "$pwd\resgen.cs" $resgen
[IO.File]::WriteAllBytes("$pwd\resgen.res", @(0,0,0,0,8,0,0,0))
$asm = [Uri].Assembly.Location
$asm2 = [Xml].Assembly.Location
$asm3 = [Web.UI.Design.ControlDesigner].Assembly.Location
$asm4 = [Windows.Forms.Form].Assembly.Location
&"$pwd\compiler\csc" /out:"$pwd\resgen.exe" /win32res:"$pwd\resgen.res" /r:$asm,$asm2,$asm3,$asm4 /t:winexe "$pwd\resgen.cs" /nologo /o /langversion:7.3
ri "$pwd\resgen.cs"
ri "$pwd\resgen.res"