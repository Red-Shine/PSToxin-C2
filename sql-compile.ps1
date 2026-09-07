$sql = @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

//modified version of https://github.com/quasar/Quasar/blob/master/Quasar.Client/Recovery/Utilities/SQLiteHandler.cs

public class SQLiteHandler
{
	private byte[] db_bytes;
	private Encoding encoding;
	private string[] field_names;
	private sqlite_master_entry[] master_table_entries;
	private ushort page_size;
	private byte[] SQLDataTypeSize = new byte[] { 0, 1, 2, 3, 4, 6, 8, 8, 0, 0 };
	private table_entry[] table_entries;

	public SQLiteHandler(string baseName)
	{
		if (File.Exists(baseName))
		{
			this.db_bytes = File.ReadAllBytes(baseName);
			if (Encoding.Default.GetString(this.db_bytes, 0, 15) != "SQLite format 3")
			{
				throw new Exception("Not a valid SQLite 3 Database File");
			}
			if (this.db_bytes[0x34] != 0)
			{
				throw new Exception("Auto-vacuum capable database is not supported");
			}
			//if (this.ConvertToInteger(0x2c, 4) >= 4)
			//{
			//	throw new Exception("No supported Schema layer file-format");
			//}
			this.page_size = (ushort)this.ConvertToInteger(0x10, 2);
			switch (this.ConvertToInteger(0x38, 4))
			{
				case 0:
				case 1:
					this.encoding = Encoding.Default;
					break;
				case 2:
					this.encoding = Encoding.Unicode;
					break;
				case 3:
					this.encoding = Encoding.BigEndianUnicode;
					break;
				default:
					throw new Exception("Database contains an unsupported encoding, this could also indicate the database is corrupted");
			}

			this.ReadMasterTable(100L);
		}
	}

	private ulong ConvertToInteger(int startIndex, int Size)
	{
		if ((Size > 8) | (Size == 0))
		{
			return 0L;
		}
		ulong num2 = 0L;
		for (int i = 0; i < Size; i++)
		{
			num2 = (num2 << 8) | this.db_bytes[startIndex + i];
		}
		return num2;
	}

	private long CVL(int startIndex, int endIndex)
	{
		endIndex++;
		byte[] buffer = new byte[8];
		int num4 = endIndex - startIndex;
		if ((num4 == 0) | (num4 > 9))
		{
			return 0L;
		}
		if (num4 == 1)
		{
			buffer[0] = (byte)(this.db_bytes[startIndex] & 0x7f);
			return BitConverter.ToInt64(buffer, 0);
		}
		int num2 = 1;
		int num3 = 7;
		int index = 0;
		if (num4 == 9)
		{
			buffer[0] = this.db_bytes[endIndex - 1];
			endIndex--;
			index = 1;
		}
		for (int i = endIndex - 1; i >= startIndex; i--)
		{
			if ((i - 1) >= startIndex)
			{
				buffer[index] = (byte)((((byte)(this.db_bytes[i] >> ((num2 - 1) & 7))) & (((int)0xff) >> num2)) | ((byte)(this.db_bytes[i - 1] << (num3 & 7))));
				num2++;
				index++;
				num3--;
			}
			else if (num4 != 9)
			{
				buffer[index] = (byte)(((byte)(this.db_bytes[i] >> ((num2 - 1) & 7))) & (((int)0xff) >> num2));
			}
		}
		return BitConverter.ToInt64(buffer, 0);
	}

	public int GetRowCount()
	{
		return this.table_entries.Length;
	}

	public string[] GetTableNames()
	{
		string[] strArray2 = null;
		int index = 0;
		for (int i = 0; i < this.master_table_entries.Length; i++)
		{
			if (this.master_table_entries[i].item_type == "table")
			{
				Array.Resize(ref strArray2, index + 1);
				strArray2[index] = this.master_table_entries[i].item_name;
				index++;
			}
		}
		return strArray2;
	}

	public string GetValue(int row_num, int field)
	{
		if (row_num >= this.table_entries.Length)
		{
			return null;
		}
		if (field >= this.table_entries[row_num].content.Length)
		{
			return null;
		}
		return this.table_entries[row_num].content[field];
	}

	public string GetValue(int row_num, string field)
	{
		int num = -1;
		for (int i = 0; i < this.field_names.Length; i++)
		{
			if (this.field_names[i].ToLower() == field.ToLower())
			{
				num = i;
				break;
			}
		}
		if (num == -1)
		{
			return null;
		}
		return this.GetValue(row_num, num);
	}

	private int GVL(int startIndex)
	{
		if (startIndex > this.db_bytes.Length)
		{
			return 0;
		}
		int num3 = startIndex + 8;
		for (int i = startIndex; i <= num3; i++)
		{
			if (i > (this.db_bytes.Length - 1))
			{
				return 0;
			}
			if ((this.db_bytes[i] & 0x80) != 0x80)
			{
				return i;
			}
		}
		return (startIndex + 8);
	}

	private bool IsOdd(long value)
	{
		return ((value & 1L) == 1L);
	}

	private void ReadMasterTable(ulong Offset)
	{
		if (this.db_bytes[(int)Offset] == 13)
		{
			ushort num2 = Convert.ToUInt16(this.ConvertToInteger((int)Offset + 3, 2));
			int length = 0;
			if (this.master_table_entries != null)
			{
				length = this.master_table_entries.Length;
				Array.Resize(ref this.master_table_entries, (this.master_table_entries.Length + num2));
			}
			else
			{
				this.master_table_entries = new sqlite_master_entry[num2];
			}
			int num13 = num2;
			for (int i = 0; i < num13; i++)
			{
				ulong num = this.ConvertToInteger((int)Offset + 8 + (i * 2), 2);
				if (Offset != 100)
				{
					num += Offset;
				}
				int endIndex = this.GVL((int)num);
				long num7 = this.CVL((int)num, endIndex);
				int num6 = this.GVL(endIndex + 1);
				this.master_table_entries[length + i].row_id = this.CVL(endIndex + 1, num6);
				num = Convert.ToUInt64(num6 + 1);
				endIndex = this.GVL((int)num);
				num6 = endIndex;
				long num5 = this.CVL((int)num, endIndex);
				long[] numArray = new long[5];
				int index = 0;
				do
				{
					endIndex = num6 + 1;
					num6 = this.GVL(endIndex);
					numArray[index] = this.CVL(endIndex, num6);
					if (numArray[index] > 9L)
					{
						if (this.IsOdd(numArray[index]))
						{
							numArray[index] = (long)Math.Round((double)(((double)(numArray[index] - 13L)) / 2.0));
						}
						else
						{
							numArray[index] = (long)Math.Round((double)(((double)(numArray[index] - 12L)) / 2.0));
						}
					}
					else
					{
						numArray[index] = this.SQLDataTypeSize[(int)numArray[index]];
					}
					index++;
				}
				while (index < 5);
				this.master_table_entries[length + i].item_type = this.encoding.GetString(this.db_bytes, Convert.ToInt32((long)num + num5), (int)numArray[0]);
				this.master_table_entries[length + i].item_name = this.encoding.GetString(this.db_bytes, Convert.ToInt32((long)num + num5 + numArray[0]), (int)numArray[1]);
				this.master_table_entries[length + i].root_num = (long)this.ConvertToInteger(Convert.ToInt32((long)num + num5 + numArray[0] + numArray[1] + numArray[2]), (int)numArray[3]);
				this.master_table_entries[length + i].sql_statement = this.encoding.GetString(this.db_bytes, Convert.ToInt32((long)num + num5 + numArray[0] + numArray[1] + numArray[2] + numArray[3]), (int)numArray[4]);
			}
		}
		else if (this.db_bytes[(int)Offset] == 5)
		{
			ushort num11 = Convert.ToUInt16(this.ConvertToInteger((int)Offset + 3, 2));
			int num14 = num11;
			for (int j = 0; j < num14; j++)
			{
				ushort startIndex = (ushort)this.ConvertToInteger((int)Offset + 12 + (j * 2), 2);
				if (Offset == 100)
				{
					this.ReadMasterTable(Convert.ToUInt64((this.ConvertToInteger(startIndex, 4) - 1) * this.page_size));
				}
				else
				{
					this.ReadMasterTable(Convert.ToUInt64((this.ConvertToInteger((int)(Offset + startIndex), 4) - 1) * this.page_size));
				}
			}
			this.ReadMasterTable(Convert.ToUInt64((this.ConvertToInteger(Convert.ToInt32(Offset + 8), 4) - 1) * this.page_size));
		}
	}

	public bool ReadTable(string TableName)
	{
		int index = -1;
		for (int i = 0; i < this.master_table_entries.Length; i++)
		{
			if (this.master_table_entries[i].item_name.ToLower() == TableName.ToLower())
			{
				index = i;
				break;
			}
		}
		if (index == -1)
		{
			return false;
		}
		string[] strArray = this.master_table_entries[index].sql_statement.Substring(this.master_table_entries[index].sql_statement.IndexOf("(") + 1).Split(new char[] { ',' });
		for (int j = 0; j < strArray.Length; j++)
		{
			strArray[j] = (strArray[j]).TrimStart();
			int num4 = strArray[j].IndexOf(" ");
			if (num4 > 0)
			{
				strArray[j] = strArray[j].Substring(0, num4);
			}
			if (strArray[j].IndexOf("UNIQUE") == 0)
			{
				break;
			}
			Array.Resize(ref this.field_names, j + 1);
			this.field_names[j] = strArray[j];
		}
		return this.ReadTableFromOffset((ulong)((this.master_table_entries[index].root_num - 1L) * this.page_size));
	}

	private bool ReadTableFromOffset(ulong Offset)
	{
		if (this.db_bytes[(int)Offset] == 13)
		{
			int num2 = Convert.ToInt32(this.ConvertToInteger((int)Offset + 3, 2));
			int length = 0;
			if (this.table_entries != null)
			{
				length = this.table_entries.Length;
				Array.Resize(ref this.table_entries, (this.table_entries.Length + num2));
			}
			else
			{
				this.table_entries = new table_entry[num2];
			}
			for (int i = 0; i < num2; i++)
			{
				record_header_field[] _fieldArray = null;
				ulong num = this.ConvertToInteger((int)Offset + 8 + (i * 2), 2);
				if (Offset != 100)
				{
					num += Offset;
				}
				int endIndex = this.GVL((int)num);
				long num9 = this.CVL((int)num, endIndex);
				int num8 = this.GVL(endIndex + 1);
				this.table_entries[length + i].row_id = this.CVL(endIndex + 1, num8);
				num = Convert.ToUInt64(num8 + 1);
				endIndex = this.GVL((int)num);
				num8 = endIndex;
				long num7 = this.CVL((int)num, endIndex);
				long num10 = Convert.ToInt64((int)num - endIndex + 1);
				for (int j = 0; num10 < num7; j++)
				{
					Array.Resize(ref _fieldArray, j + 1);
					endIndex = num8 + 1;
					num8 = this.GVL(endIndex);
					_fieldArray[j].type = this.CVL(endIndex, num8);
					if (_fieldArray[j].type > 9L)
					{
						if (this.IsOdd(_fieldArray[j].type))
						{
							_fieldArray[j].size = (long)Math.Round((double)(((double)(_fieldArray[j].type - 13L)) / 2.0));
						}
						else
						{
							_fieldArray[j].size = (long)Math.Round((double)(((double)(_fieldArray[j].type - 12L)) / 2.0));
						}
					}
					else
					{
						_fieldArray[j].size = this.SQLDataTypeSize[(int)_fieldArray[j].type];
					}
					num10 = (num10 + (num8 - endIndex)) + 1L;
				}
				this.table_entries[length + i].content = new string[_fieldArray.Length];
				int num4 = 0;
				for (int k = 0; k < _fieldArray.Length; k++)
				{
					if (_fieldArray[k].type > 9L)
					{
						if (!this.IsOdd(_fieldArray[k].type))
						{
							this.table_entries[length + i].content[k] = this.encoding.GetString(this.db_bytes, (int)num + (int)num7 + num4, (int)_fieldArray[k].size);
						}
						else
						{
							this.table_entries[length + i].content[k] = Encoding.Default.GetString(this.db_bytes, (int)num + (int)num7 + num4, (int)_fieldArray[k].size);
						}
					}
					else
					{
						this.table_entries[length + i].content[k] = this.ConvertToInteger((int)num + (int)num7 + num4, (int)_fieldArray[k].size).ToString();
					}
					num4 += (int)_fieldArray[k].size;
				}
			}
		}
		else if (this.db_bytes[(int)Offset] == 5)
		{
			ushort num14 = Convert.ToUInt16(this.ConvertToInteger((int)Offset + 3, 2));
			int num18 = num14;
			for (int m = 0; m < num18; m++)
			{
				ushort num13 = (ushort)this.ConvertToInteger((int)Offset + 12 + (m * 2), 2);
				this.ReadTableFromOffset(Convert.ToUInt64((this.ConvertToInteger((int)(Offset + num13), 4) - 1) * this.page_size));
			}
			this.ReadTableFromOffset(Convert.ToUInt64((this.ConvertToInteger(Convert.ToInt32(Offset + 8), 4) - 1) * this.page_size));
		}
		return true;
	}

	[StructLayout(LayoutKind.Sequential)]
	private struct record_header_field
	{
		public long size;
		public long type;
	}

	[StructLayout(LayoutKind.Sequential)]
	private struct sqlite_master_entry
	{
		public long row_id;
		public string item_type;
		public string item_name;
		public string astable_name;
		public long root_num;
		public string sql_statement;
	}

	[StructLayout(LayoutKind.Sequential)]
	private struct table_entry
	{
		public long row_id;
		public string[] content;
	}
}
'@
sc 'sql.cs' $sql
[IO.file]::writeallbytes("sql.res", @(0,0,0,0,8,0,0,0))
C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe /out:$PWD\sql.dll /win32res:sql.res /t:library $PWD\sql.cs /nowin32manifest /nologo
ri "sql.cs"
ri "sql.res"