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
    public class RSZHeader : ReadableItem
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
    };
    public class ReadableItem
    {
        public void Read(byte[] bytes, ref int offset)
        {
            var type = GetType();
            FieldInfo[] fields = GetType().GetFields(BindingFlags.Instance | BindingFlags.Public);
            foreach (var field in fields)
            {
                if (field.FieldType == typeof(int))
                {
                    field.SetValue(this, BitConverter.ToInt32(bytes, offset));
                    offset += 0x4;
                }
                else if (field.FieldType == typeof(Int64))
                {
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
