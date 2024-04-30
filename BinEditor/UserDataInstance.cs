using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;

namespace BinEditor
{

    public class ItemArmorDataParam : ReadableItem
    {
        public int Id;
        public int sortNo;
        public int cat;
        public uint attr;
        public int modelId;
        public int fieldmodelid;
        public short iconno;
        public short dropid;
        public short weight;
        public short ___;
        public int buy;
        public int sell;
        public short stack;
        public short mat;
        public short worth;
        public short fav;
        public uint favat;
        public int _;
        public int eqcat;

        public short lv;
        public short series;
        public short job;
        public short styleNo;
        public short phyDef;
        public short slashDefRate;
        public short strikeDefRate;
        public short magicDef;
        public short fireDef;
        public short fireRes;
        public short iceDef;
        public short iceRes;
        public short thunderDef;
        public short thunderRes;
        public short lightDef;
        public short darkDef;
        public short shakeResRate;
        public short blowResRate;
        public short posionRes;
        public short sleepRes;
        public short silentRes;
        public short stoneRes;
        public short waterRes;
        public short oilRes;
        public short special_ext;//actually byte and placeholder
        public short specialValue1;
        public short specialValue2;
        public short specialValue3;
    }
    public class ItemArmorData : ReadableItem
    {
        List<int> itemdataparams = new List<int>();
    }
    public class ItemDataParam : ReadableItem
    {
        public int Id;
        public int sortNo;
        public int cat;
        public uint attr;
        public int modelId;
        public int fieldmodelid;
        public short iconno;
        public short dropid;
        public short weight;
        public short ___;
        public int buy;
        public int sell;
        public short stack;
        public short mat;
        public short worth;
        public short fav;
        public uint favat;
        public int _;
        public int subcat;
        public int useeff;
        public short decay;
        public short __;
        public int decayItemId;
        public short healWhiteHP;
        public short healBlackHP;
        public short healStam;
        public short useattr;
        public uint addstatus;
        public int removestatus;
        public int fakeprice;
        public int fakeid;
    }
    public class ItemData : ReadableItem
    {
        List<int> itemdataparams=new List<int>();
    }
    public class ItemDropParamLot : ReadableItem
    {
        public int Num;
        public int Rate;
    }

    public class ItemDropParamTableItem : ReadableItem
    {
        public int Id;
        public short Num;
        public short Rate;
        public int Attr;
    }
    public class ItemDropParam : ReadableItem
    {
        public int _;
        public uint characterId;
        public int gimmickId;
        public List<int> lotList = new List<int>();
        public List<int> tableList = new List<int>();
    }
    public class ItemDropParamTable : ReadableItem
    {
        public int _;
        public int __;
        public List<int> itemList = new List<int>();
    }
    public class ItemDropData : ReadableItem
    {
        public List<int> Params = new List<int>();        
    }
    public class RSZHeader
    {
        public uint magic;//0x52535A00
        public uint version;
        public int objectCount;
        public int instanceCount;
        public int userdataCount;
        public int ___;
        public Int64 instanceOffset;
        public Int64 dataOffset;
        public Int64 userdataOffset;
        public void Read(byte[] bytes, ref int offset)
        {
            var type = GetType();
            FieldInfo[] fields = GetType().GetFields(BindingFlags.Instance | BindingFlags.Public);
            int idx = 0;
            foreach (var field in fields)
            {

                if (field.FieldType == typeof(int))
                {
                    field.SetValue(this, BitConverter.ToInt32(bytes, offset));
                    offset += 0x4;
                }
                else if (field.FieldType == typeof(Int64))
                {
                    if (offset % 8 != 0)
                        offset += 8 - offset % 8;
                    field.SetValue(this, BitConverter.ToInt64(bytes, offset));
                    offset += 0x8;
                }
                else if (field.FieldType == typeof(uint))
                {
                    field.SetValue(this, BitConverter.ToUInt32(bytes, offset));
                    offset += 0x4;
                }
                else if (field.FieldType == typeof(short))
                {
                    field.SetValue(this, BitConverter.ToInt16(bytes, offset));
                    offset += 0x2;
                }
                else if (field.FieldType == typeof(float))
                {
                    field.SetValue(this, BitConverter.ToSingle(bytes, offset));
                    offset += 0x4;
                }
                else if (field.FieldType == typeof(List<int>))
                {
                    List<int> tmp = new List<int>();
                    int len = BitConverter.ToInt32(bytes, offset);
                    offset += 0x4;

                    for (int i = 0; i < len; i++)
                    {
                        tmp.Add(BitConverter.ToInt32(bytes, offset));
                        offset += 0x4;
                    }

                    field.SetValue(this, tmp);
                }
                else if (field.FieldType == typeof(List<byte>))
                {
                    List<byte> tmp = new List<byte>();
                    //字符串实际byte长度乘2
                    int len = BitConverter.ToInt32(bytes, offset) * 2;
                    offset += 0x4;

                    for (int i = 0; i < len; i++)
                    {
                        tmp.Add(bytes[offset]);
                        offset += 0x1;
                    }
                    //对齐
                    if (len % 4 != 0)
                        offset += 4 - len % 4;
                    field.SetValue(this, tmp);
                }
                else
                {
                    throw new Exception();
                }
            }
        }

        public void Write(byte[] bytes, ref int offset)
        {
            var type = GetType();
            FieldInfo[] fields = GetType().GetFields(BindingFlags.Instance | BindingFlags.Public);
            foreach (var field in fields)
            {
                if (field.FieldType == typeof(int))
                {
                    var tmp = BitConverter.GetBytes((int)field.GetValue(this));
                    System.Array.Copy(tmp, 0x0, bytes, offset, 0x4);
                    offset += 0x4;
                }
                else if (field.FieldType == typeof(Int64))
                {
                    if (offset % 8 != 0)
                        offset += 8 - offset % 8;
                    var tmp = BitConverter.GetBytes((Int64)field.GetValue(this));
                    System.Array.Copy(tmp, 0x0, bytes, offset, 0x8);
                    offset += 0x8;
                }
                else if (field.FieldType == typeof(uint))
                {
                    var tmp = BitConverter.GetBytes((uint)field.GetValue(this));
                    System.Array.Copy(tmp, 0x0, bytes, offset, 0x4);
                    offset += 0x4;
                }
                else if (field.FieldType == typeof(float))
                {
                    var tmp = BitConverter.GetBytes((float)field.GetValue(this));
                    System.Array.Copy(tmp, 0x0, bytes, offset, 0x4);
                    offset += 0x4;
                }

                else if (field.FieldType == typeof(short))
                {
                    var tmp = BitConverter.GetBytes((short)field.GetValue(this));
                    System.Array.Copy(tmp, 0x0, bytes, offset, 0x2);
                    offset += 0x2;
                }
                else if (field.FieldType == typeof(List<int>))
                {
                    List<int> v = (List<int>)field.GetValue(this);
                    var tmp = BitConverter.GetBytes(v.Count);
                    System.Array.Copy(tmp, 0x0, bytes, offset, 0x4);
                    offset += 0x4;

                    foreach (var i in v)
                    {
                        tmp = BitConverter.GetBytes(i);
                        System.Array.Copy(tmp, 0x0, bytes, offset, 0x4);
                        offset += 0x4;
                    }
                }
                else if (field.FieldType == typeof(List<byte>))
                {
                    List<byte> v = (List<byte>)field.GetValue(this);
                    var tmp = BitConverter.GetBytes(v.Count / 2);
                    System.Array.Copy(tmp, 0x0, bytes, offset, 0x4);
                    offset += 0x4;

                    foreach (var i in v)
                    {
                        tmp = BitConverter.GetBytes((short)i);
                        System.Array.Copy(tmp, 0x0, bytes, offset, 0x1);
                        offset += 0x1;
                    }
                    if (v.Count % 4 != 0)
                        offset += 4 - v.Count % 4;
                }
                else
                {
                    throw new Exception();
                }
            }
        }

    };
    public class ReadableItem
    {
        public Dictionary<string, dynamic> dynamicValues=new Dictionary<string, dynamic>();
        public TypeDefine typeDefine;
        public object ReadSingle(TypeDefineField field,byte[] bytes,ref int offset)
        {
            dynamic ret = null;
            if (field.type == "Vec3")
            {
                ret = null;
            }
            else if (field.type == "Object")
            {
                int v = BitConverter.ToInt32(bytes, offset);
                ret = v;
            }
            else if (field.type == "F32")
            {
                float v = BitConverter.ToSingle(bytes, offset);
                ret = v;
            }
            else if (field.type == "S32")
            {
                int v = BitConverter.ToInt32(bytes, offset);
                ret = v;
            }
            else if (field.type == "U32")
            {
                uint v = BitConverter.ToUInt32(bytes, offset);
                ret = v;
            }
            else if (field.type == "Data")
            {
                uint v = BitConverter.ToUInt32(bytes, offset);
                ret = v;
            }
            else if (field.type == "U64")
            {
                var v = BitConverter.ToUInt64(bytes, offset);
                ret = v;
            }
            else if (field.type == "Bool")
            {
                var v = BitConverter.ToBoolean(bytes, offset);
                ret = v;
            }
            else if (field.type == "Range")
            {
                //2*int32
                var v = BitConverter.ToInt64(bytes, offset);
                ret = v;
            }
            else if (field.type == "String")
            {
                int len = BitConverter.ToInt32(bytes, offset);
                offset += field.size;
                var str=Encoding.Unicode.GetString(bytes, offset, len*2);
                ret = str;
                offset += len * 2;
                offset -= field.size;
            }
            else
            {
                throw new Exception();
            }
            offset += field.size;
            return ret;
        }
        public void Read(byte[] bytes, ref int offset,TypeDefine typeDefine)
        {
            this.typeDefine = typeDefine;
            var type = GetType();
            FieldInfo[] fields = GetType().GetFields(BindingFlags.Instance | BindingFlags.Public);
            int idx = 0;
            foreach(var field in typeDefine.fields)
            {
                var typeDefineField = typeDefine.fields[idx++];
                var align = typeDefineField.align;
                if (offset % align != 0)
                    offset += align - offset % align;
                if (field.array)
                {
                    var list=new List<dynamic>();
                    int len = BitConverter.ToInt32(bytes, offset);
                    offset += 0x4;
                    for(int i = 0;i<len;++i)
                    {
                        list.Add(ReadSingle(field,bytes,ref offset));
                    }
                    dynamicValues[field.name]=list;
                }
                else
                {
                    dynamicValues[field.name]=ReadSingle(field, bytes, ref offset);
                }
            }
        }


        public void Write(byte[] bytes, ref int offset)
        {
            var type = GetType();
            FieldInfo[] fields = GetType().GetFields(BindingFlags.Instance | BindingFlags.Public);
            foreach (var field in fields)
            {
                if (field.FieldType == typeof(int))
                {
                    var tmp = BitConverter.GetBytes((int)field.GetValue(this));
                    System.Array.Copy(tmp, 0x0, bytes, offset, 0x4);
                    offset += 0x4;
                }
                else if (field.FieldType == typeof(Int64))
                {
                    if (offset % 8 != 0)
                        offset += 8 - offset % 8;
                    var tmp = BitConverter.GetBytes((Int64)field.GetValue(this));
                    System.Array.Copy(tmp, 0x0, bytes, offset, 0x8);
                    offset += 0x8;
                }
                else if (field.FieldType == typeof(uint))
                {
                    var tmp = BitConverter.GetBytes((uint)field.GetValue(this));
                    System.Array.Copy(tmp, 0x0, bytes, offset, 0x4);
                    offset += 0x4;
                }
                else if (field.FieldType == typeof(float))
                {
                    var tmp = BitConverter.GetBytes((float)field.GetValue(this));
                    System.Array.Copy(tmp, 0x0, bytes, offset, 0x4);
                    offset += 0x4;
                }

                else if (field.FieldType == typeof(short))
                {
                    var tmp = BitConverter.GetBytes((short)field.GetValue(this));
                    System.Array.Copy(tmp, 0x0, bytes, offset, 0x2);
                    offset += 0x2;
                }
                else if (field.FieldType == typeof(List<int>))
                {
                    List<int> v = (List<int>)field.GetValue(this);
                    var tmp = BitConverter.GetBytes(v.Count);
                    System.Array.Copy(tmp, 0x0, bytes, offset, 0x4);
                    offset += 0x4;

                    foreach (var i in v)
                    {
                        tmp = BitConverter.GetBytes(i);
                        System.Array.Copy(tmp, 0x0, bytes, offset, 0x4);
                        offset += 0x4;
                    }
                }
                else if (field.FieldType == typeof(List<byte>))
                {
                    List<byte> v = (List<byte>)field.GetValue(this);
                    var tmp = BitConverter.GetBytes(v.Count/2);
                    System.Array.Copy(tmp, 0x0, bytes, offset, 0x4);
                    offset += 0x4;

                    foreach (var i in v)
                    {
                        tmp = BitConverter.GetBytes((short)i);
                        System.Array.Copy(tmp, 0x0, bytes, offset, 0x1);
                        offset += 0x1;
                    }
                    if (v.Count % 4 != 0)
                        offset += 4 - v.Count % 4;
                }
                else
                {
                    throw new Exception();
                }
            }
        }
        public ReadableItem() { }

        public void IncreaseValueInListInt(int value) 
        {
            var type = GetType();
            FieldInfo[] fields = GetType().GetFields(BindingFlags.Instance | BindingFlags.Public);
            foreach (var field in fields)
            {
                if (field.FieldType == typeof(List<int>))
                {
                    var list=(List<int>)field.GetValue(this);
                    for (int i = 0; i < list!.Count; ++i)
                        list[i] = list[i] + value;
                }
            }
        }
    }
}
