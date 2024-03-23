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
using BinEditor;

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

if(false)
{
    foreach (string _filename in new[] { "enemydefaultitemdropdata.user.2", "enemyitemdropdata.user.2" })
    {
        string original_filename = $"E:\\OtherGame\\DragonDogma2\\REtool\\re_chunk_000\\natives\\stm\\appsystem\\item\\itemdropdata\\{_filename}";
        string filename = $"E:\\OtherGame\\DragonDogma2\\REtool\\HigherDropRate2\\natives\\stm\\appsystem\\item\\itemdropdata\\{_filename}";
        var data = new userdata();
        data.Read(original_filename);
        for (int i = 0; i < data.instances.Count; ++i)
        {
            var instance = data.instances[i];
            var param = instance as ItemDropParam;
            if (param != null)
            {
                if (param.lotList.Count > 1)
                {
                    foreach (var lotid in param.lotList)
                    {
                        var lot = data.instances[lotid - 1] as ItemDropParamLot;
                        if (lot is null) throw new Exception();
                        if (lot.Num > 0)
                        {
                            lot.Num = lot.Num*2;
                            lot.Rate = 100;
                        }
                        else
                        {
                            lot.Rate = 0;
                        }
                    }

                }
            }
        }
        data.Write(filename);
    }
}

//drop ferrystone
if(true)
{
    foreach (string _filename in new[] { "enemydefaultitemdropdata.user.2", "enemyitemdropdata.user.2" })
    {
        string original_filename = $"E:\\OtherGame\\DragonDogma2\\REtool\\re_chunk_000\\natives\\stm\\appsystem\\item\\itemdropdata\\{_filename}";
        string filename = $"E:\\OtherGame\\DragonDogma2\\REtool\\DropFerryStone3\\natives\\stm\\appsystem\\item\\itemdropdata\\{_filename}";
        var data = new userdata();
        data.Read(original_filename);

        var newItem = new ItemDropParamTableItem();
        newItem.Id = 80;
        newItem.Num = 1;
        newItem.Rate = 2;
        newItem.Attr = 0;
        data.instances.Insert(0, newItem);
        data.instanceinfos.Insert(0, InstanceTypeEnum.appItemDropParamTableItem);
        data.IncreaseAllIdx(1);
        foreach (var instance in data.instances)
            if(instance as ItemDropParamTable is not null)
            {
                var table = instance as ItemDropParamTable;
                table!.itemList.Add(1);
            }

        data.Write(filename);
    }
}


//random drop
if(false)
{
    foreach (string _filename in new[] { "enemydefaultitemdropdata.user.2", "enemyitemdropdata.user.2" })
    {
        string original_filename = $"E:\\OtherGame\\DragonDogma2\\REtool\\re_chunk_000\\natives\\stm\\appsystem\\item\\itemdropdata\\{_filename}";
        string filename = $"E:\\OtherGame\\DragonDogma2\\REtool\\CompleteRandomDrop\\natives\\stm\\appsystem\\item\\itemdropdata\\{_filename}";
        var data = new userdata();
        data.Read(original_filename);
        /*
        foreach (var instance in data.instances)
            if (instance as ItemDropParamTableItem is not null)
            {
                var item=instance as ItemDropParamTableItem;
                if(item.Id==0xf5)
                {
                    if(item!.Attr!=1)
                    {
                        ;
                    }
                }
                if (item!.Attr != 0&&item!.Id!=0xfb&&item!.Id!=0xf5)
                    ;
            }*/

        List<int> stdlist=new List<int>();
        foreach(var itemId in itemId2Name.Keys)
           // if(Int32.Parse(itemId)<2000)
        {
            var newItem = new ItemDropParamTableItem();
            newItem.Id = Int32.Parse(itemId);
            newItem.Num = 1;
            newItem.Rate = 1;
            newItem.Attr = 0;
            data.instances.Insert(0, newItem);
            data.instanceinfos.Insert(0, InstanceTypeEnum.appItemDropParamTableItem);
            stdlist.Add(stdlist.Count+1);
        }
        data.IncreaseAllIdx(stdlist.Count);
        foreach (var instance in data.instances)
            if (instance as ItemDropParamTable is not null)
            {
                var table = instance as ItemDropParamTable;
                table!.itemList = stdlist;
            }

        data.Write(filename);
    }
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
