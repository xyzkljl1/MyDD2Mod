using System;
using System.ComponentModel;
using System.Net.Http.Json;
using System.Reflection;
using System.Reflection.PortableExecutable;
using System.Runtime.InteropServices;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;
using System.Xml.Linq;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

Dictionary<InstanceTypeEnum, Type> Enum2Class = new Dictionary<InstanceTypeEnum, Type>();
Dictionary<Type, InstanceTypeEnum> Class2Enum = new Dictionary<Type, InstanceTypeEnum>();

Init();

if (false)
{
    SetItemSellPrice("E:\\OtherGame\\DragonDogma2\\REtool\\HigherItemSellPrice\\natives\\stm\\appsystem\\item\\itemdata\\itemdata.user.2", 0x60, 491);
    SetItemSellPrice("E:\\OtherGame\\DragonDogma2\\REtool\\HigherItemSellPrice\\natives\\stm\\appsystem\\item\\itemdata\\itemarmordata.user.2", 0x74, 361);
    SetItemSellPrice("E:\\OtherGame\\DragonDogma2\\REtool\\HigherItemSellPrice\\natives\\stm\\appsystem\\item\\itemdata\\itemweapondata.user.2", 0x88, 138);

    SetItemSellPrice("E:\\OtherGame\\DragonDogma2\\REtool\\HigherItemSellPrice10\\natives\\stm\\appsystem\\item\\itemdata\\itemdata.user.2", 0x60, 491, 10);
    SetItemSellPrice("E:\\OtherGame\\DragonDogma2\\REtool\\HigherItemSellPrice10\\natives\\stm\\appsystem\\item\\itemdata\\itemarmordata.user.2", 0x74, 361, 10);
    SetItemSellPrice("E:\\OtherGame\\DragonDogma2\\REtool\\HigherItemSellPrice10\\natives\\stm\\appsystem\\item\\itemdata\\itemweapondata.user.2", 0x88, 138, 10);
}

Dictionary<string, string> itemId2Name = new Dictionary<string, string>();
if (false)
{
    var text = File.ReadAllText("E:\\OtherGame\\DragonDogma2\\ITEM_NAME_LOOKUP.json");
    var doc = JsonConvert.DeserializeObject(text)! as JObject;
    foreach (JProperty pair in doc["chS"])
    {
        itemId2Name[pair.Name] = pair.Value.ToString();
    }
}
if (false)
{
    var bytes = File.ReadAllBytes("E:\\OtherGame\\DragonDogma2\\REtool\\re_chunk_000\\natives\\stm\\appsystem\\item\\itemmixdata\\itemmixdata.user.2");
    int ct = BitConverter.ToInt32(bytes, 0x1b0c);
    int offset = 0x0740;
    for (int i = 0; i < ct; i++)
    {
        var itemId = BitConverter.ToInt32(bytes, offset + 0x0);
        var num = BitConverter.ToInt32(bytes, offset + 0x4);

        string msg = itemId2Name[$"{itemId}"];
        msg = $"{msg}*{num} ";

        offset += 0x8;
        var mat_a = readIdList(bytes, ref offset);
        var mat_b = readIdList(bytes, ref offset);
        msg = $"{msg} = {mat_a} + {mat_b}";
        bool nosame = BitConverter.ToBoolean(bytes, offset);
        if (nosame)
            msg += "(*)";
        offset += 0x4;
        Console.WriteLine(msg);
    }
}


{
    foreach (string _filename in new[] { "enemydefaultitemdropdata.user.2", "enemyitemdropdata.user.2" })
    {
        string original_filename = $"E:\\OtherGame\\DragonDogma2\\REtool\\re_chunk_000\\natives\\stm\\appsystem\\item\\itemdropdata\\{_filename}";
        string filename = $"E:\\OtherGame\\DragonDogma2\\REtool\\HigherDropRate\\natives\\stm\\appsystem\\item\\itemdropdata\\{_filename}";
        var bytes = File.ReadAllBytes(original_filename);
        var header = getHeader(bytes, 0x30);
        if (header.magic != 0x5a5352)
            return;
        int offset = 0x30 + (int)header.instanceOffset + 0x8;
        var instanceInfos = ReadInstanceInfos(bytes, ref offset);

        offset = (int)header.userdataOffset + 0x30;
        var instances = ReadInstances(bytes, instanceInfos, ref offset);

        /*
        List<int> goblintables = new List<int>();
        for (int i = 0; i < instances.Count; ++i)
        {
            var instance = instances[i];
            var table = instance as ItemDropParamTable;
            if (table != null)
            {
                bool isGoblin = false;
                foreach (var idx in table.itemList)
                {
                    var item = instances[idx - 1] as ItemDropParamTableItem;
                    if (item is not null)
                    {
                        if (item.Id == 208)
                            isGoblin |= true;
                    }
                    else
                        throw new Exception();
                }
                if (isGoblin)
                    goblintables.Add(i);
            }
        }*/
        for (int i = 0; i < instances.Count; ++i)
        {
            var instance = instances[i];
            var param = instance as ItemDropParam;
            if (param != null)
            {
                /*
                bool isgoblin = false;
                foreach (var tableId in param.tableList)
                {
                    if (goblintables.Contains(tableId - 1))
                        isgoblin |= true;
                }*/
                if (param.lotList.Count > 1)
                {
                    foreach (var lotid in param.lotList)
                    {
                        var lot = instances[lotid - 1] as ItemDropParamLot;
                        if (lot is null) throw new Exception();
                        if (lot.Num > 0)
                        {
                            //lot.Num = 10;
                            lot.Rate = 100;
                        }
                        else
                        {
                            lot.Rate = 0;
                        }
                    }

                }
                /*
                 * if (isgoblin)
                    foreach (var lotid in param.lotList)
                    {
                        var lot = instances[lotid - 1] as ItemDropParamLot;
                        if (lot is null) throw new Exception();
                        if (lot.Num > 0)
                        {
                            lot.Num = 10;
                            lot.Rate = 100;
                        }
                        else
                        {
                            lot.Rate = 0;
                        }
                    }
                */
            }
        }

        offset = (int)header.userdataOffset + 0x30;
        WriteInstances(bytes, instances, ref offset);
        File.WriteAllBytes(filename, bytes);

        if (false)
        {
            var newbytes = new byte[bytes.Length];
            offset = (int)header.userdataOffset + 0x30;
            WriteInstances(newbytes, instances, ref offset);
            int end = offset;


            offset = (int)header.userdataOffset + 0x30;
            for (int i = offset; i < end; ++i)
            {
                if (bytes[i] != newbytes[i])
                {
                    Console.WriteLine("1");
                }
            }
        }
    }
}

void Init()
{
    var enumnames = Enum.GetNames(typeof(InstanceTypeEnum));
    var values = Enum.GetValues(typeof(InstanceTypeEnum));
    int ct = 0;
    foreach (InstanceTypeEnum v in values)
    {
        var enumname = enumnames[ct];
        ct++;

        var typename = enumname.Substring(3);
        var type = Type.GetType(typename);
        Enum2Class.Add(v, type!);
        Class2Enum.Add(type!, v);
    }
}

List<uint> ReadInstanceInfos(byte[] bytes, ref int offset)
{
    List<uint> ret = new List<uint>();
    for (; offset < bytes.Length;)
    {
        uint id = BitConverter.ToUInt32(bytes, offset);
        if (id == 0)
            break;
        ret.Add(id);
        offset += 0x8;
    }
    offset += 0x4;
    return ret;
}
List<ReadableItem> ReadInstances(byte[] bytes, List<uint> instanceInfos, ref int offset)
{
    List<ReadableItem> ret = new List<ReadableItem>();
    foreach (var instanceInfo in instanceInfos)
    {
        var type = Enum2Class[(InstanceTypeEnum)instanceInfo];
        ret.Add(ReadClass(bytes, ref offset, type));
    }
    return ret;
}

void WriteInstances(byte[] bytes, List<ReadableItem> instances, ref int offset)
{
    foreach (var instance in instances)
        instance.Write(bytes, ref offset);
}



string readIdList(byte[] bytes, ref int offset)
{
    string ret = "";
    var ct = BitConverter.ToInt32(bytes, offset);
    for (int j = 0; j < ct; j++)
    {
        offset += 0x4;
        int itemId = BitConverter.ToInt32(bytes, offset);
        var name = itemId2Name[$"{itemId}"];
        if (ret != "")
            ret = $"{ret}/{name}";
        else
            ret = name;
    }
    offset += 0x4;
    return ret;
}


void SetItemSellPrice(string filename, int itemStructLength, int ct, int rate = 1)
{
    var bytes = File.ReadAllBytes(filename);
    var len = bytes.Length;
    var header = getHeader(bytes, 0x30);
    if (header.magic != 0x5a5352)
        return;

    int offset = (int)header.userdataOffset + 0x30;
    for (int i = 0; i < ct; i++)
    //for(;offset<len;offset+=itemStructLength)
    {
        var idx = BitConverter.ToInt32(bytes, offset + 0x0);
        var buyprice = BitConverter.ToInt32(bytes, offset + 0x20);
        var sellprice = BitConverter.ToInt32(bytes, offset + 0x24);

        sellprice = buyprice * rate;
        for (int j = 0; j < 4; j++)
        {
            bytes[offset + 0x24 + j] = BitConverter.GetBytes(sellprice)[j];
        }
        offset += itemStructLength;
        Console.WriteLine($"{idx}:{buyprice}/{sellprice}");
    }
    File.WriteAllBytes(filename, bytes);
    Console.WriteLine("Done");
}


RSZHeader getHeader(byte[] bytes, int offset)
{
    int size = Marshal.SizeOf(typeof(RSZHeader));
    IntPtr buffer = Marshal.AllocHGlobal(size);
    Marshal.Copy(bytes, offset, buffer, size);
    var header = (RSZHeader)Marshal.PtrToStructure(buffer, typeof(RSZHeader))!;
    Marshal.FreeHGlobal(buffer);
    return header;
}

ReadableItem ReadClass(byte[] bytes, ref int offset, Type type)
{
    var ret = Activator.CreateInstance(type) as ReadableItem;
    ret!.Read(bytes, ref offset);
    return ret;
}

enum InstanceTypeEnum : uint
{
    appItemDropParamLot = 0x6aa821d2,
    appItemDropParamTableItem = 0x32b6b787,
    appItemDropParamTable = 0x8fcd056d,
    appItemDropParam = 0xd4dd21f2,
    appItemDropData = 0x1428e659,
};


struct RSZHeader
{
    public uint magic;//0x52535A00
    public uint version;
    public int objectCount;
    public int instanceCount;
    public int userdataCount;
    public Int64 instanceOffset;
    public Int64 dataOffset;
    public Int64 userdataOffset;
};

class ItemDropParamLot : ReadableItem
{
    public int Num;
    public int Rate;
}

class ItemDropParamTableItem : ReadableItem
{
    public int Id;
    public short Num;
    public short Rate;
    public int Attr;
}
class ItemDropParam : ReadableItem
{
    public int _;
    public uint characterId;
    public int gimmickId;
    public List<int> lotList = new List<int>();
    public List<int> tableList = new List<int>();
}
class ItemDropParamTable : ReadableItem
{
    public int _;
    public int __;
    public List<int> itemList = new List<int>();
}
class ItemDropData : ReadableItem
{
    public List<int> Params = new List<int>();
}

class ReadableItem
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

}